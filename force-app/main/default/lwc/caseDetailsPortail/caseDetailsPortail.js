import { LightningElement, api } from 'lwc';

export default class caseDetailsPortail extends LightningElement {
    @api recordId;

    connectedCallback() {
        alert('Composant chargé – recordId = ' + this.recordId);
    }
}