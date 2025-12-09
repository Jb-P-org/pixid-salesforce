import { LightningElement, api } from 'lwc';

export default class MissingFieldsScreenChargeMap extends LightningElement {
    @api accountRegistrationNumber;
    @api accountVATNumber;

    @api chargeMapBillingContact;
    @api chargeMapCashCollectionContact;
    @api chargeMapPaymentMethod;
    @api chargeMapBillingConditions;
    @api chargeMapInvoiceSendingMethod;
    @api chargeMapBillingInstructions;
    @api chargeMapContractDurationInYears;
    @api chargeMapSendInvoiceTo;
    @api chargeMapPlatformLink;

    @api chargeMapPORequired;
    @api chargeMapPOReference;
    @api chargeMapPORequestDate;
    @api chargeMapPOFrequency;

    @api chargeMapItemsJson;

    @api pbOnItemsPO; // <= nouvelle propriété pour Pb_On_Items_PO__c

    missingAccountFields = [];
    missingChargeMapFields = [];

    connectedCallback() {
        this.missingAccountFields = [];
        this.missingChargeMapFields = [];

        // Champs Account
        if (!this.accountRegistrationNumber) {
            this.missingAccountFields.push('Registration Number');
        }
        if (!this.accountVATNumber) {
            this.missingAccountFields.push('VAT Number');
        }

        // Champs Charge Map
        if (!this.chargeMapBillingContact) {
            this.missingChargeMapFields.push('Billing Contact');
        }
        if (!this.chargeMapCashCollectionContact) {
            this.missingChargeMapFields.push('Cash Collection Contact');
        }
        if (!this.chargeMapPaymentMethod) {
            this.missingChargeMapFields.push('Payment Method');
        }
        if (!this.chargeMapBillingConditions) {
            this.missingChargeMapFields.push('Billing Conditions');
        }
        if (!this.chargeMapInvoiceSendingMethod) {
            this.missingChargeMapFields.push('Invoice Sending Method');
        }
        if (!this.chargeMapBillingInstructions) {
            this.missingChargeMapFields.push('Billing Instructions');
        }
        if (!this.chargeMapContractDurationInYears) {
            this.missingChargeMapFields.push('Contract Duration (Years)');
        }

        if (this.chargeMapInvoiceSendingMethod === 'Email' && !this.chargeMapSendInvoiceTo) {
            this.missingChargeMapFields.push('Send Invoice To');
        }
        if (this.chargeMapInvoiceSendingMethod === 'Platform' && !this.chargeMapPlatformLink) {
            this.missingChargeMapFields.push('Platform Link');
        }

        if (this.chargeMapPORequired === 'Yes') {
            if (!this.chargeMapPOReference || !this.chargeMapPORequestDate || !this.chargeMapPOFrequency) {
                this.missingChargeMapFields.push('PO Reference / Request Date / Frequency');
            }
        }

        // 💥 Nouveau test sur la variable boolean
        //if (this.pbOnItemsPO === true) {
        //    this.missingChargeMapFields.push('At least one PO is missing on a Charge Map Item');
       // }
    }
}