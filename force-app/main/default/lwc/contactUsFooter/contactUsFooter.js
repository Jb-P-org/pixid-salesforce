import { LightningElement } from 'lwc';
import getUserLanguage from '@salesforce/apex/CaseController.getUserLanguage';

// Import custom labels
import LegalNotice from '@salesforce/label/c.Legal_Notice';
import PrivacyPolicy from '@salesforce/label/c.Privacy_Policy';

export default class ContactUsFooter extends LightningElement {
    label = {
        LegalNotice,
        PrivacyPolicy
    };

    userLanguage = 'fr'; // Default to French

    connectedCallback() {
        getUserLanguage()
            .then(language => {
                this.userLanguage = language || 'fr';
            })
            .catch(error => {
                console.error('[ContactUsFooter] Error getting user language:', error);
                this.userLanguage = 'fr'; // Fallback to French
            });
    }

    get legalNoticeUrl() {
        return `/Self/s/legal-notice/?language=${this.userLanguage}`;
    }

    get privacyPolicyUrl() {
        return `/Self/s/privacy-policy/?language=${this.userLanguage}`;
    }
}
