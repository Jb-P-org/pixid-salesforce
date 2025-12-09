import { LightningElement, track, api, wire } from 'lwc';
import getChargeMapMetadata    from '@salesforce/apex/ChargeMapItemController.getChargeMapMetadata';
import updateChargeMapItems    from '@salesforce/apex/ChargeMapItemController.updateChargeMapItems';
import { ShowToastEvent }      from 'lightning/platformShowToastEvent';
import { getRecord }           from 'lightning/uiRecordApi';
import STATUS_FIELD            from '@salesforce/schema/ChargeMap__c.Status__c';

export default class ChargeMapItemsTable extends LightningElement {
    @api recordId;
    @track columnsMeta = [];
    @track rows       = [];
    @track isEditable = false;
    @track isLoading  = true;
    draftValues       = {};

    // Statut courant pour détecter les changements
    @track status;

    /** Wire sur la Charge Map pour récupérer son Status__c et recharger si ça change */
    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD] })
    wiredChargeMap({ data, error }) {
        if (data) {
            const newStatus = data.fields.Status__c.value;
            console.log('🔄 Wired status:', newStatus, '(ancien:', this.status, ')');
            if (newStatus !== this.status) {
                this.status = newStatus;
                console.log('▶️ Statut changé, reload loadData()');
                this.loadData();
            }
        } else if (error) {
            console.error('❌ Erreur wire getRecord:', error);
            this.showToast(
                'Erreur lecture du statut',
                error.body?.message || error.message,
                'error'
            );
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    /** Initial load (avant wire) */
    connectedCallback() {
        console.log('⚙️ connectedCallback, appel initial loadData()');
        this.loadData();
    }

    /** Charge métadonnées & items via Apex */
    loadData() {
        if (!this.recordId) {
            console.warn('⚠️ Pas de recordId, on quitte loadData()');
            return;
        }
        this.isLoading = true;
        console.log('🔄 loadData() Apex call, recordId =', this.recordId);

        getChargeMapMetadata({ chargeMapId: this.recordId })
            .then(res => {
                console.log('✅ getChargeMapMetadata result:', res);
                console.log('   ▶️ isEditable (Apex) =', res.isEditable);

                this.isEditable = res.isEditable;

                // Prépare les métadonnées de colonnes
                const fields = res.metadata.fields || [];
                this.columnsMeta = fields.map(f => ({
                    ...f,
                    isPicklist : f.type === 'picklist',
                    isCheckbox : f.type === 'boolean',
                    inputType  : this.mapFieldInputType(f),
                    canEdit    : this.isEditable
                                 && f.updateable
                                 && !f.calculated
                                 && ![
                                     'Name',
                                     'Amount__c',
                                     'Quantity__c',
                                     'CurrencyIsoCode',
                                     'Status__c',
                                     'Spend__c',
                                     'PercentageOfSpend__c',
                                     'ProratedAmount__c',
                                     'NbOfMonthsProrated__c',
                                     'ProratedAmountPerMonth__c'
                                   ].includes(f.apiName)
                }));
                console.log('   ▶️ columnsMeta computed:', this.columnsMeta);

                // Prépare les lignes avec displayValue
                const items = res.items || [];
                this.rows = items.map((rec, idx) => ({
                    rowNumber: idx + 1,
                    id       : rec.Id,
                    data     : rec,
                    cells    : this.columnsMeta.map(col => {
                        const raw = rec[col.apiName];
                        const displayValue =
                            raw === null || raw === undefined || raw === ''
                            ? '—'
                            : raw;
                        return {
                            apiName      : col.apiName,
                            value        : raw,
                            displayValue,
                            meta         : col,
                            isEditing    : false
                        };
                    })
                }));
                console.log('   ▶️ rows computed (premiers):', this.rows.slice(0, 3));
            })
            .catch(err => {
                console.error('❌ Erreur getChargeMapMetadata:', err);
                this.showToast(
                    'Erreur chargement',
                    err.body?.message || err.message,
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
                console.log('🔚 loadData() terminé, isLoading =', this.isLoading);
            });
    }

    handleEditIconClick(evt) {
        const rowId     = evt.currentTarget.dataset.id;
        const fieldName = evt.currentTarget.dataset.field;
        console.log(`✏️ EditIconClick on row ${rowId}, field ${fieldName}`);
        this.rows.forEach(r => {
            r.cells.forEach(c => {
                c.isEditing = (r.id === rowId && c.apiName === fieldName);
            });
        });
    }

    handleFieldChange(evt) {
        const rowId = evt.target.dataset.id;
        const fld   = evt.target.dataset.field;
        const val   = evt.detail?.value ?? evt.target.checked;
        console.log(`🖊️ FieldChange row ${rowId}, field ${fld} =`, val);

        // Met à jour la data et le draft
        const row = this.rows.find(r => r.id === rowId);
        if (row) {
            row.data[fld] = val;
            // recalcule displayValue immédiatement
            const cell = row.cells.find(c => c.apiName === fld);
            if (cell) {
                cell.value        = val;
                cell.displayValue = (val === null || val === '' ? '—' : val);
            }
        }
        this.draftValues[rowId] = {
            ...this.draftValues[rowId],
            [fld]: val
        };
        console.log('   ▶️ draftValues now:', this.draftValues);
    }

    handleInputBlur() {
        console.log('🔒 InputBlur, sortie mode édition');
        this.rows.forEach(r => r.cells.forEach(c => c.isEditing = false));
    }

    handleSave() {
        const updates = Object.entries(this.draftValues).map(
            ([id, changes]) => ({ Id: id, ...changes })
        );
        console.log('💾 handleSave, updates =', updates);
        if (!updates.length) {
            console.log('   ⚠️ Pas de modifications à sauvegarder');
            return;
        }

        this.isLoading = true;
        updateChargeMapItems({ updatedItems: updates })
            .then(() => {
                console.log('✅ saveData succeeded');
                this.showToast('Succès', 'Mise à jour réussie', 'success');
                this.draftValues = {};
                this.handleInputBlur();
                this.loadData();
            })
            .catch(err => {
                console.error('❌ saveData error:', err);
                this.showToast(
                    'Erreur maj',
                    err.body?.message || err.message,
                    'error'
                );
                this.isLoading = false;
            });
    }

    mapFieldInputType(field) {
        switch (field.type) {
            case 'currency':
            case 'percent':
            case 'double':
            case 'int':
                return 'number';
            case 'date':
                return 'date';
            case 'datetime':
                return 'datetime';
            case 'boolean':
                return 'checkbox';
            default:
                return 'text';
        }
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}