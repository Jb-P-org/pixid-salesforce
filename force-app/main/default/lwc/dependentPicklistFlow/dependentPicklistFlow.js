import { LightningElement, api, wire, track } from 'lwc';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';

export default class DependentPicklistFlow extends LightningElement {
    @api objectApiName;
    @api controllerField;
    @api dependentField;
    @api recordTypeId;

    @api labelController;
    @api labelDependent;

    @api controllerValue;
    @api dependentValue;

    @track controllerOptions = [];
    @track allDependentOptions = [];
    @track filteredDependentOptions = [];

    @wire(getPicklistValuesByRecordType, { objectApiName: '$objectApiName', recordTypeId: '$recordTypeId' })
    wiredPicklistData({ data, error }) {
        if (data) {
            // Options du champ contrôleur
            const controllerData = data.picklistFieldValues[this.controllerField];
            this.controllerOptions = controllerData.values.map(opt => ({
                label: opt.label,
                value: opt.value
            }));

            // Options du champ dépendant (non filtrées)
            const dependentData = data.picklistFieldValues[this.dependentField];
            this.allDependentOptions = dependentData.values.map(opt => ({
                label: opt.label,
                value: opt.value,
                validFor: opt.validFor
            }));

            if (this.controllerValue) {
                this.filterDependentOptions(this.controllerValue);
            }
        } else if (error) {
            console.error('Erreur lors du chargement des picklists :', error);
        }
    }

    handleControllerChange(event) {
        this.controllerValue = event.detail.value;
        this.dispatchEvent(new CustomEvent('controllerchange', { detail: this.controllerValue }));
        this.filterDependentOptions(this.controllerValue);

        this.dependentValue = null;
        this.dispatchEvent(new CustomEvent('dependentchange', { detail: null }));
    }

    handleDependentChange(event) {
        this.dependentValue = event.detail.value;
        this.dispatchEvent(new CustomEvent('dependentchange', { detail: this.dependentValue }));
    }

    filterDependentOptions(controllerValue) {
        const index = this.controllerOptions.findIndex(opt => opt.value === controllerValue);
        if (index < 0) {
            this.filteredDependentOptions = [];
            return;
        }

        this.filteredDependentOptions = this.allDependentOptions.filter(opt =>
            opt.validFor.includes(index.toString())
        );
    }

    // ✅ Getter propre pour l’attribut disabled
    get isDependentDisabled() {
        return this.filteredDependentOptions.length === 0;
    }
}