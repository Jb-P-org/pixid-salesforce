import { LightningElement, track } from 'lwc';

export default class selfPopUp1 extends LightningElement {
    @track isVisible = true;

    handleClose() {
        this.isVisible = false;
    }
}