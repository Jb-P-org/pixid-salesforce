import { LightningElement, api, wire, track } from 'lwc';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';

export default class PicklistByRecordTypeFlow extends LightningElement {
    @api objectApiName;
    @api fieldApiName;
    @api recordTypeId;
    @api label;
    @api required = false;
    @api value;

    @track options = [];

    @wire(getPicklistValuesByRecordType, {
        objectApiName: '$objectApiName',
        recordTypeId: '$recordTypeId'
    })
    wiredPicklistValues({ error, data }) {
        if (data && data.picklistFieldValues[this.fieldApiName]) {
            this.options = data.picklistFieldValues[this.fieldApiName].values.map(option => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            console.error('Error loading picklist values:', error);
        }
    }

    handleChange(event) {
        this.value = event.detail.value;
        this.dispatchEvent(new CustomEvent('valuechange', {
            detail: this.value
        }));
    }
}