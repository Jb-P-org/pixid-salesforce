import { LightningElement, api } from 'lwc';

// Import custom labels for field names
import RegistrationNumber from '@salesforce/label/c.Registration_Number';
import VATNumber from '@salesforce/label/c.VAT_Number';
import ActivityCountry from '@salesforce/label/c.Activity_Country';
import IdInterneTdG from '@salesforce/label/c.Id_Interne_TdG';
import BillingContact from '@salesforce/label/c.Billing_Contact';
import CashCollectionContact from '@salesforce/label/c.Cash_Collection_Contact';
import PaymentMethod from '@salesforce/label/c.Payment_Method';
import BillingConditions from '@salesforce/label/c.Billing_Conditions';
import InvoiceSendingMethod from '@salesforce/label/c.Invoice_Sending_Method';
import BillingInstructions from '@salesforce/label/c.Billing_Instructions';
import ContractDurationYears from '@salesforce/label/c.Contract_Duration_Years';
import SendInvoiceTo from '@salesforce/label/c.Send_Invoice_To';
import PlatformLink from '@salesforce/label/c.Platform_Link';
import POReferenceRequestDateFrequency from '@salesforce/label/c.PO_Reference_Request_Date_Frequency';
import POMissingOnItems from '@salesforce/label/c.PO_Missing_On_Items';

export default class MissingFieldsScreenChargeMap extends LightningElement {
    label = {
        RegistrationNumber,
        VATNumber,
        ActivityCountry,
        IdInterneTdG,
        BillingContact,
        CashCollectionContact,
        PaymentMethod,
        BillingConditions,
        InvoiceSendingMethod,
        BillingInstructions,
        ContractDurationYears,
        SendInvoiceTo,
        PlatformLink,
        POReferenceRequestDateFrequency,
        POMissingOnItems
    };
    @api accountRegistrationNumber;
    @api accountVATNumber;
    @api accountActivityCountry;
    @api accountIdInterneTdG;
    @api accountSousType;
    @api sourceOpportunityActivity;
    @api sourceOpportunityOffer;

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
            this.missingAccountFields.push(this.label.RegistrationNumber);
        }
        if (!this.accountVATNumber) {
            this.missingAccountFields.push(this.label.VATNumber);
        }
        if (!this.accountActivityCountry) {
            this.missingAccountFields.push(this.label.ActivityCountry);
        }
        // ID_interne_TdG is required only for TSC + Pixid FR + Pack
        if (
            !this.accountIdInterneTdG &&
            this.accountSousType === 'TSC' &&
            this.sourceOpportunityActivity === 'Pixid FR' &&
            this.sourceOpportunityOffer === 'Pack'
        ) {
            this.missingAccountFields.push(this.label.IdInterneTdG);
        }

        // Champs Charge Map
        if (!this.chargeMapBillingContact) {
            this.missingChargeMapFields.push(this.label.BillingContact);
        }
        if (!this.chargeMapCashCollectionContact) {
            this.missingChargeMapFields.push(this.label.CashCollectionContact);
        }
        if (!this.chargeMapPaymentMethod) {
            this.missingChargeMapFields.push(this.label.PaymentMethod);
        }
        if (!this.chargeMapBillingConditions) {
            this.missingChargeMapFields.push(this.label.BillingConditions);
        }
        if (!this.chargeMapInvoiceSendingMethod) {
            this.missingChargeMapFields.push(this.label.InvoiceSendingMethod);
        }
        if (!this.chargeMapBillingInstructions) {
            this.missingChargeMapFields.push(this.label.BillingInstructions);
        }
        if (!this.chargeMapContractDurationInYears) {
            this.missingChargeMapFields.push(this.label.ContractDurationYears);
        }

        if (this.chargeMapInvoiceSendingMethod === 'Email' && !this.chargeMapSendInvoiceTo) {
            this.missingChargeMapFields.push(this.label.SendInvoiceTo);
        }
        if (this.chargeMapInvoiceSendingMethod === 'Platform' && !this.chargeMapPlatformLink) {
            this.missingChargeMapFields.push(this.label.PlatformLink);
        }

        if (this.pbOnItemsPO === true) {
            this.missingChargeMapFields.push(this.label.POMissingOnItems);
        }
    }
}