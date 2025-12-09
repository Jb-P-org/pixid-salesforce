import { LightningElement, api } from 'lwc';

export default class PicklistColumn extends LightningElement {
    @api value;
    @api typeAttributes;

    handleChange(event) {
        const cellChangeEvent = new CustomEvent('cellchange', {
            detail: {
                value: event.detail.value // attention, c’est event.detail.value, pas event.target.value
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(cellChangeEvent);
    }
}