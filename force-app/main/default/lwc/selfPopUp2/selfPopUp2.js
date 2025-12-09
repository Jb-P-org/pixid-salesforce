import { LightningElement, track } from 'lwc';

export default class SelfPopUp2 extends LightningElement {
    @track isVisible = true;

    handleClose() {
        this.isVisible = false;
    }
}