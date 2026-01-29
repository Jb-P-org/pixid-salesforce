import { LightningElement, track, api, wire } from 'lwc';
import { NavigationMixin }     from 'lightning/navigation';
import getChargeMapMetadata    from '@salesforce/apex/ChargeMapItemController.getChargeMapMetadata';
import updateChargeMapItems    from '@salesforce/apex/ChargeMapItemController.updateChargeMapItems';
import createChargeMapItems    from '@salesforce/apex/ChargeMapItemController.createChargeMapItems';
import deleteChargeMapItems    from '@salesforce/apex/ChargeMapItemController.deleteChargeMapItems';
import { ShowToastEvent }      from 'lightning/platformShowToastEvent';
import { getRecord }           from 'lightning/uiRecordApi';
import STATUS_FIELD            from '@salesforce/schema/ChargeMap__c.Status__c';
import END_DATE_FIELD          from '@salesforce/schema/ChargeMap__c.EndDateRevRec__c';

// Primary columns shown in main table (always visible)
const PRIMARY_COLUMNS = [
    'Name',
    'Amount__c',
    'Quantity__c',
    'Sales_unit_price__c',
    'DiscountNumber__c',
    'BillingSchedule__c',
    'Term__c',
    'StartDateRevRec__c',
    'End_date__c',
    'Status__c',
    'Activated__c',
    'PO_Required__c',
    'PO_Reference__c',
    'PO_Request_Date__c'
];

// Secondary columns shown in expandable details
const SECONDARY_COLUMNS = [
    'LineDescription__c',
    'Spend__c',
    'PercentageOfSpend__c',
    'SalesOrderID__c',
    'NbOfMonthsProrated__c',
    'ProratedAmount__c'
];

// Column icons mapping based on field type
// Green (marketing_actions) = Editable
// Orange (actions_and_buttons) = Mandatory for activation
// Purple (custom_component_task) = Auto-calculated
const COLUMN_ICONS = {
    'Amount__c': 'standard:custom_component_task',
    'Quantity__c': 'standard:marketing_actions',
    'Sales_unit_price__c': 'standard:marketing_actions',
    'DiscountNumber__c': 'standard:marketing_actions',
    'BillingSchedule__c': 'standard:actions_and_buttons',
    'Term__c': 'standard:actions_and_buttons',
    'StartDateRevRec__c': 'standard:actions_and_buttons',
    'End_date__c': 'standard:custom_component_task',
    'Status__c': 'standard:custom_component_task',
    'LineDescription__c': 'standard:marketing_actions',
    'Activated__c': 'standard:actions_and_buttons',
    'Spend__c': 'standard:marketing_actions',
    'PercentageOfSpend__c': 'standard:marketing_actions',
    'PO_Required__c': 'standard:actions_and_buttons',
    'PO_Reference__c': 'standard:actions_and_buttons',
    'PO_Request_Date__c': 'standard:actions_and_buttons',
    'SalesOrderID__c': 'standard:custom_component_task',
    'NbOfMonthsProrated__c': 'standard:custom_component_task',
    'ProratedAmount__c': 'standard:custom_component_task'
};

export default class ChargeMapItemsTable extends NavigationMixin(LightningElement) {
    @api recordId;
    @track columnsMeta = [];
    @track primaryColumnsMeta = [];
    @track secondaryColumnsMeta = [];
    @track rows       = [];
    @track isEditable = false;
    @track isLoading  = true;
    draftValues       = {};

    // Track expanded rows
    @track expandedRowIds = new Set();

    // Selection state
    @track selectedBacklogIds = new Set();
    @track selectedNonBacklogIds = new Set();

    // Add Items modal state
    @track isAddModalOpen = false;
    @track newItemRows = [];
    @track isSaving = false;

    // Delete confirmation state
    @track isDeleteConfirmOpen = false;

    // ChargeMap End Date Rev Rec (read-only, shown in Add modal)
    @track chargeMapEndDate = null;

    // Statut courant pour détecter les changements
    @track status;

    /** Wire sur la Charge Map pour récupérer son Status__c et EndDateRevRec__c */
    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD, END_DATE_FIELD] })
    wiredChargeMap({ data, error }) {
        if (data) {
            const newStatus = data.fields.Status__c.value;
            const endDate = data.fields.EndDateRevRec__c.value;
            console.log('🔄 Wired status:', newStatus, '(ancien:', this.status, '), endDate:', endDate);
            this.chargeMapEndDate = endDate || null;
            if (newStatus !== this.status) {
                this.status = newStatus;
                console.log('▶️ Statut changé, reload loadData()');
                this.loadData();
            }
        } else if (error) {
            console.error('❌ Erreur wire getRecord:', error);
            const errorMessage = this.parseErrorMessage(error);
            this.showToast(
                'Erreur de lecture du statut',
                errorMessage,
                'error'
            );
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get hasSecondaryColumns() {
        return this.secondaryColumnsMeta.length > 0;
    }

    // Computed property: Backlog items sorted by StartDateRevRec__c
    get backlogRows() {
        return this.rows
            .filter(row => row.data.Status__c === 'Backlog')
            .sort((a, b) => {
                const dateA = a.data.StartDateRevRec__c ? new Date(a.data.StartDateRevRec__c) : new Date(0);
                const dateB = b.data.StartDateRevRec__c ? new Date(b.data.StartDateRevRec__c) : new Date(0);
                return dateA - dateB;
            })
            .map((row, idx) => ({
                ...row,
                rowNumber: idx + 1,
                isSelected: this.selectedBacklogIds.has(row.id)
            }));
    }

    get hasBacklogRows() {
        return this.backlogRows.length > 0;
    }

    // Computed property: Non-backlog items sorted by StartDateRevRec__c
    get nonBacklogRows() {
        return this.rows
            .filter(row => row.data.Status__c !== 'Backlog')
            .sort((a, b) => {
                const dateA = a.data.StartDateRevRec__c ? new Date(a.data.StartDateRevRec__c) : new Date(0);
                const dateB = b.data.StartDateRevRec__c ? new Date(b.data.StartDateRevRec__c) : new Date(0);
                return dateA - dateB;
            })
            .map((row, idx) => ({
                ...row,
                rowNumber: idx + 1,
                isSelected: this.selectedNonBacklogIds.has(row.id)
            }));
    }

    get hasNonBacklogRows() {
        return this.nonBacklogRows.length > 0;
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
                this.chargeMapEndDate = res.endDateRevRec || null;

                // Clear selections on data reload
                this.selectedBacklogIds = new Set();
                this.selectedNonBacklogIds = new Set();

                // Prépare les métadonnées de colonnes
                const fields = res.metadata.fields || [];
                this.columnsMeta = fields.map(f => ({
                    ...f,
                    isPicklist : f.type === 'picklist',
                    isCheckbox : f.type === 'boolean',
                    inputType  : this.mapFieldInputType(f),
                    icon       : COLUMN_ICONS[f.apiName] || null,
                    hasIcon    : !!COLUMN_ICONS[f.apiName],
                    canEdit    : this.isEditable
                                 && f.updateable
                                 && !f.calculated
                                 && ![
                                     'Name',
                                     'CurrencyIsoCode',
                                     'Status__c',
                                     'Spend__c',
                                     'PercentageOfSpend__c',
                                     'ProratedAmount__c',
                                     'NbOfMonthsProrated__c',
                                     'ProratedAmountPerMonth__c'
                                   ].includes(f.apiName)
                }));

                // Split columns into primary and secondary
                this.primaryColumnsMeta = this.columnsMeta.filter(
                    col => PRIMARY_COLUMNS.includes(col.apiName)
                );
                this.secondaryColumnsMeta = this.columnsMeta.filter(
                    col => SECONDARY_COLUMNS.includes(col.apiName)
                );

                // Sort primary columns by the order defined in PRIMARY_COLUMNS
                this.primaryColumnsMeta.sort((a, b) =>
                    PRIMARY_COLUMNS.indexOf(a.apiName) - PRIMARY_COLUMNS.indexOf(b.apiName)
                );

                console.log('   ▶️ primaryColumnsMeta:', this.primaryColumnsMeta.map(c => c.apiName));
                console.log('   ▶️ secondaryColumnsMeta:', this.secondaryColumnsMeta.map(c => c.apiName));

                // Prépare les lignes avec displayValue
                const items = res.items || [];
                this.rows = items.map((rec, idx) => {
                    const currencyCode = rec.CurrencyIsoCode || 'EUR';
                    const allCells = this.columnsMeta.map(col => {
                        const raw = rec[col.apiName];
                        let displayValue;
                        if (raw === null || raw === undefined || raw === '') {
                            displayValue = '—';
                        } else if (col.type === 'currency') {
                            displayValue = this.formatCurrency(raw, currencyCode);
                        } else {
                            displayValue = raw;
                        }
                        return {
                            apiName      : col.apiName,
                            value        : raw,
                            displayValue,
                            meta         : col,
                            isEditing    : false,
                            // Flag for Name field to render as link
                            isNameField  : col.apiName === 'Name',
                            // Computed properties for checkbox display
                            checkboxIconName : raw ? 'utility:check' : 'utility:close',
                            checkboxClass    : raw ? 'checkbox-checked' : 'checkbox-unchecked'
                        };
                    });

                    return {
                        rowNumber: idx + 1,
                        id       : rec.Id,
                        data     : rec,
                        cells    : allCells,
                        primaryCells: allCells.filter(c => PRIMARY_COLUMNS.includes(c.apiName))
                            .sort((a, b) => PRIMARY_COLUMNS.indexOf(a.apiName) - PRIMARY_COLUMNS.indexOf(b.apiName)),
                        secondaryCells: allCells.filter(c => SECONDARY_COLUMNS.includes(c.apiName)),
                        isExpanded: this.expandedRowIds.has(rec.Id)
                    };
                });
                console.log('   ▶️ rows computed (premiers):', this.rows.slice(0, 3));
            })
            .catch(err => {
                console.error('❌ Erreur getChargeMapMetadata:', err);
                const errorMessage = this.parseErrorMessage(err);
                this.showToast(
                    'Erreur de chargement',
                    errorMessage,
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
                console.log('🔚 loadData() terminé, isLoading =', this.isLoading);
            });
    }

    handleToggleExpand(evt) {
        const rowId = evt.currentTarget.dataset.id;
        const row = this.rows.find(r => r.id === rowId);
        if (row) {
            row.isExpanded = !row.isExpanded;
            if (row.isExpanded) {
                this.expandedRowIds.add(rowId);
            } else {
                this.expandedRowIds.delete(rowId);
            }
            // Force reactivity
            this.rows = [...this.rows];
        }
    }

    handleNavigateToRecord(evt) {
        evt.preventDefault();
        const recordId = evt.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    handleExpandAll() {
        this.rows = this.rows.map(row => {
            this.expandedRowIds.add(row.id);
            return { ...row, isExpanded: true };
        });
    }

    handleCollapseAll() {
        this.expandedRowIds.clear();
        this.rows = this.rows.map(row => ({ ...row, isExpanded: false }));
    }

    get hasExpandedRows() {
        return this.rows.some(r => r.isExpanded);
    }

    get hasCollapsedRows() {
        return this.rows.some(r => !r.isExpanded);
    }

    // --- Selection computed properties ---

    get isAllBacklogSelected() {
        const rows = this.backlogRows;
        return rows.length > 0 && rows.every(r => this.selectedBacklogIds.has(r.id));
    }

    get isAllNonBacklogSelected() {
        const rows = this.nonBacklogRows;
        return rows.length > 0 && rows.every(r => this.selectedNonBacklogIds.has(r.id));
    }

    get hasSelectedItems() {
        return this.selectedBacklogIds.size > 0 || this.selectedNonBacklogIds.size > 0;
    }

    get selectedCount() {
        return this.selectedBacklogIds.size + this.selectedNonBacklogIds.size;
    }

    get deleteButtonLabel() {
        return `Delete (${this.selectedCount})`;
    }

    get showActionButtons() {
        return this.isEditable;
    }

    get showDeleteButton() {
        return this.isEditable && this.hasSelectedItems;
    }

    handleEditIconClick(evt) {
        const rowId     = evt.currentTarget.dataset.id;
        const fieldName = evt.currentTarget.dataset.field;
        console.log(`✏️ EditIconClick on row ${rowId}, field ${fieldName}`);
        this.rows.forEach(r => {
            r.cells.forEach(c => {
                c.isEditing = (r.id === rowId && c.apiName === fieldName);
            });
            // Also update primary and secondary cells
            r.primaryCells.forEach(c => {
                c.isEditing = (r.id === rowId && c.apiName === fieldName);
            });
            r.secondaryCells.forEach(c => {
                c.isEditing = (r.id === rowId && c.apiName === fieldName);
            });
        });
        // Force reactivity
        this.rows = [...this.rows];
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
            const currencyCode = row.data.CurrencyIsoCode || 'EUR';
            // recalcule displayValue immédiatement in all cell arrays
            const updateCell = (cell) => {
                if (cell.apiName === fld) {
                    cell.value = val;
                    if (val === null || val === '') {
                        cell.displayValue = '—';
                    } else if (cell.meta.type === 'currency') {
                        cell.displayValue = this.formatCurrency(val, currencyCode);
                    } else {
                        cell.displayValue = val;
                    }
                    // Update checkbox computed properties
                    cell.checkboxIconName = val ? 'utility:check' : 'utility:close';
                    cell.checkboxClass = val ? 'checkbox-checked' : 'checkbox-unchecked';
                }
            };
            row.cells.forEach(updateCell);
            row.primaryCells.forEach(updateCell);
            row.secondaryCells.forEach(updateCell);
        }
        this.draftValues[rowId] = {
            ...this.draftValues[rowId],
            [fld]: val
        };
        console.log('   ▶️ draftValues now:', this.draftValues);

        // Auto-save immediately for checkbox fields
        if (evt.target.type === 'checkbox') {
            this.handleSave();
        }
    }

    handleInputBlur() {
        console.log('🔒 InputBlur, sortie mode édition');
        this.rows.forEach(r => {
            r.cells.forEach(c => c.isEditing = false);
            r.primaryCells.forEach(c => c.isEditing = false);
            r.secondaryCells.forEach(c => c.isEditing = false);
        });
        this.rows = [...this.rows];

        // Auto-save on blur if there are pending changes
        if (Object.keys(this.draftValues).length > 0) {
            this.handleSave();
        }
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
                const errorMessage = this.parseErrorMessage(err);
                this.showToast(
                    'Erreur de mise à jour',
                    errorMessage,
                    'error'
                );
                this.isLoading = false;
            });
    }

    // --- Selection handlers ---

    handleSelectAllBacklog(evt) {
        if (evt.target.checked) {
            this.selectedBacklogIds = new Set(this.backlogRows.map(r => r.id));
        } else {
            this.selectedBacklogIds = new Set();
        }
    }

    handleSelectAllNonBacklog(evt) {
        if (evt.target.checked) {
            this.selectedNonBacklogIds = new Set(this.nonBacklogRows.map(r => r.id));
        } else {
            this.selectedNonBacklogIds = new Set();
        }
    }

    handleRowSelect(evt) {
        const rowId = evt.target.dataset.id;
        const tableType = evt.target.dataset.table;
        const isChecked = evt.target.checked;

        if (tableType === 'backlog') {
            const updated = new Set(this.selectedBacklogIds);
            if (isChecked) {
                updated.add(rowId);
            } else {
                updated.delete(rowId);
            }
            this.selectedBacklogIds = updated;
        } else {
            const updated = new Set(this.selectedNonBacklogIds);
            if (isChecked) {
                updated.add(rowId);
            } else {
                updated.delete(rowId);
            }
            this.selectedNonBacklogIds = updated;
        }
    }

    // --- Add Items Modal ---

    handleOpenAddModal() {
        this.newItemRows = [this.createEmptyItemRow()];
        this.isAddModalOpen = true;
    }

    handleCloseAddModal() {
        this.isAddModalOpen = false;
        this.newItemRows = [];
    }

    createEmptyItemRow() {
        return {
            key: Date.now() + '_' + Math.random().toString(36).substring(2, 11),
            Product__c: null,
            Sales_unit_price__c: null,
            Quantity__c: null,
            DiscountNumber__c: null,
            StartDateRevRec__c: null
        };
    }

    handleAddAnotherRow() {
        this.newItemRows = [...this.newItemRows, this.createEmptyItemRow()];
    }

    handleRemoveRow(evt) {
        const key = evt.currentTarget.dataset.key;
        this.newItemRows = this.newItemRows.filter(r => r.key !== key);
        if (this.newItemRows.length === 0) {
            this.newItemRows = [this.createEmptyItemRow()];
        }
    }

    handleNewItemFieldChange(evt) {
        const key = evt.target.dataset.key;
        const field = evt.target.dataset.field;
        let value;

        if (field === 'Product__c') {
            value = evt.detail.recordId;
        } else {
            value = evt.detail?.value ?? evt.target.value;
        }

        this.newItemRows = this.newItemRows.map(row => {
            if (row.key === key) {
                return { ...row, [field]: value };
            }
            return row;
        });
    }

    handleSaveNewItems() {
        // Validate all required fields using reportValidity
        const allInputs = this.template.querySelectorAll(
            '[id="add-modal-content"] lightning-input, [id="add-modal-content"] lightning-record-picker'
        );
        let allValid = true;
        allInputs.forEach(input => {
            if (!input.reportValidity()) {
                allValid = false;
            }
        });
        if (!allValid) {
            return;
        }

        const validItems = this.newItemRows.filter(r => r.Product__c);
        if (validItems.length === 0) {
            this.showToast('Erreur de validation', 'Veuillez sélectionner au moins un produit.', 'error');
            return;
        }

        const itemsToCreate = validItems.map(r => ({
            Product__c: r.Product__c,
            Sales_unit_price__c: r.Sales_unit_price__c,
            Quantity__c: r.Quantity__c,
            DiscountNumber__c: r.DiscountNumber__c,
            StartDateRevRec__c: r.StartDateRevRec__c
        }));

        this.isSaving = true;
        createChargeMapItems({ chargeMapId: this.recordId, newItems: itemsToCreate })
            .then(() => {
                this.showToast('Succès', `${itemsToCreate.length} item(s) créé(s) avec succès.`, 'success');
                this.handleCloseAddModal();
                this.loadData();
            })
            .catch(err => {
                const errorMessage = this.parseErrorMessage(err);
                this.showToast('Erreur de création', errorMessage, 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    // --- Delete Items ---

    handleDeleteSelected() {
        this.isDeleteConfirmOpen = true;
    }

    handleCloseDeleteConfirm() {
        this.isDeleteConfirmOpen = false;
    }

    handleConfirmDelete() {
        const allSelectedIds = [
            ...this.selectedBacklogIds,
            ...this.selectedNonBacklogIds
        ];

        if (allSelectedIds.length === 0) {
            this.isDeleteConfirmOpen = false;
            return;
        }

        this.isLoading = true;
        this.isDeleteConfirmOpen = false;

        deleteChargeMapItems({ chargeMapId: this.recordId, itemIds: allSelectedIds })
            .then(() => {
                this.showToast(
                    'Succès',
                    `${allSelectedIds.length} item(s) supprimé(s) avec succès.`,
                    'success'
                );
                this.loadData();
            })
            .catch(err => {
                const errorMessage = this.parseErrorMessage(err);
                this.showToast('Erreur de suppression', errorMessage, 'error');
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

    formatCurrency(value, currencyCode = 'EUR') {
        if (value === null || value === undefined || value === '') {
            return '—';
        }
        // Map currency codes to symbols
        const currencySymbols = {
            'EUR': '€',
            'USD': '$',
            'GBP': '£',
            'JPY': '¥',
            'CHF': 'CHF',
            'CAD': 'CA$',
            'AUD': 'A$',
            'CNY': '¥',
            'INR': '₹',
            'BRL': 'R$',
            'MXN': 'MX$',
            'PLN': 'zł',
            'SEK': 'kr',
            'NOK': 'kr',
            'DKK': 'kr'
        };
        const symbol = currencySymbols[currencyCode] || currencyCode;
        try {
            // Format number without currency symbol, then append symbol at end
            const formattedNumber = new Intl.NumberFormat(undefined, {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            }).format(value);
            return `${formattedNumber} ${symbol}`;
        } catch (e) {
            // Fallback if formatting fails
            return `${value} ${symbol}`;
        }
    }

    parseErrorMessage(err) {
        // Handle different error formats from Apex
        if (err.body) {
            // Check for field-level errors
            if (err.body.fieldErrors) {
                const fieldMessages = [];
                for (const field in err.body.fieldErrors) {
                    const errors = err.body.fieldErrors[field];
                    errors.forEach(e => fieldMessages.push(`${field}: ${e.message}`));
                }
                if (fieldMessages.length > 0) {
                    return fieldMessages.join('\n');
                }
            }
            // Check for page-level errors
            if (err.body.pageErrors && err.body.pageErrors.length > 0) {
                return err.body.pageErrors.map(e => e.message).join('\n');
            }
            // Check for DML errors in output
            if (err.body.output && err.body.output.errors) {
                return err.body.output.errors.map(e => e.message).join('\n');
            }
            // Standard message
            if (err.body.message) {
                return err.body.message;
            }
        }
        // Fallback to generic message
        if (err.message) {
            return err.message;
        }
        return 'Une erreur inattendue s\'est produite. Veuillez réessayer.';
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}