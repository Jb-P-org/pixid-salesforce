import { LightningElement, api, wire, track } from 'lwc';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { createRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import getCaseNumber from '@salesforce/apex/CaseController.getCaseNumber';

import CASE_OBJECT from '@salesforce/schema/Case';
import ORIGIN_FIELD from '@salesforce/schema/Case.Origin';
import CHANNEL_FIELD from '@salesforce/schema/Case.Channel__c';

import getAccountId from '@salesforce/apex/CaseController.getAccountId';
import associateFilesToRecord from '@salesforce/apex/CaseController.associateFilesToRecord';
import linkArticleToCase from '@salesforce/apex/CaseController.linkArticleToCase';

import CaseReasonLabel from '@salesforce/label/c.Case_reason';
import CaseSubreason from '@salesforce/label/c.Case_subreason';
import CreateTicket from '@salesforce/label/c.Create_ticket';
import Domain from '@salesforce/label/c.Domain';
import RequestDesc from '@salesforce/label/c.Request_description';
import RequestSummary from '@salesforce/label/c.Request_summary';
import TicketCreated from '@salesforce/label/c.Ticket_created';
import CaseFormRestrict from '@salesforce/label/c.Case_form_restricted';

import logError from '@salesforce/apex/LWCErrorLogger.logError';

import getContactIdForCurrentUser from '@salesforce/apex/CaseController.getContactIdForCurrentUser';
import getUserLanguage from '@salesforce/apex/CaseController.getUserLanguage';

export default class CaseFormLWC extends LightningElement {


    label = {
        caseReason: CaseReasonLabel,
        CaseSubreason: CaseSubreason,
        CreateTicket: CreateTicket,
        Domain: Domain,
        RequestDesc: RequestDesc,
        RequestSummary: RequestSummary,
        TicketCreated: TicketCreated,
        CaseFormRestrict: CaseFormRestrict
    }

    @api recordId;
    @track isGuest = false;

    @track subject;
    @track description;
    @track caseNumber;
    @track caseId;
    @track showConfirmation = false;

    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx', '.xls', '.csv', '.xlsx', '.xml', '.dash', '.msg', '.json'];
    @track uploadedFileIds = [];
    @track uploadedFiles = [];
    @track contactId;
    @track isSubmitting = false;
    @track userLanguage;


    selectedReason;
    selectedSubreason;
    selectedDomain;
    selectedModule;

    reasonOptions = [];
    subreasonOptions = [];
    domainOptions = [];
    moduleOptions = [];

    fullSubreasonMap = {};
    subreasonDependencyMap = [];

    fullModuleMap = {};
    moduleDependencyMap = [];

    accountId;

    visibilityRules = {
        "General Inquiry": {
            "Feature Request": { domain: true, module: true },
            "Information on Platform Features": { domain: true, module: true },
            "Other": { domain: true, module: false }
        },
        "Technical Issues": {
            "Contract Signing Issue": { domain: true, module: true },
            "Platform Slowness": { domain: true, module: true },
            "Platform Anomaly": { domain: true, module: true },
            "Integration Issues": { domain: true, module: false },
            "Platform Unavailability": { domain: true, module: false }
        },
        "Document and Contract Management": {
            "Document Management": { domain: true, module: true },
            "Report a missing document": { domain: true, module: true },
            "Management of Signature Certificates": { domain: false, module: false }
        },
        "Account Issues": {
            "Repository management / List of values": { domain: true, module: true },
            "Entity Management": { domain: true, module: false },
            "Partnership Management / Agencies Network": { domain: true, module: false },
            "User account access": { domain: true, module: false },
            "User Management": { domain: true, module: false },
            "PPE partner administration": { domain: false, module: false },
            "Reconciliation resource sheets": { domain: false, module: false },
            "Retail / VSE customers": { domain: false, module: false }
        },
        "Compliance & Security": {
            "SFTP connection management": { domain: false, module: false },
            "Retention period": { domain: false, module: false },
            "User rights": { domain: false, module: false }
        }
    };

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    objectInfo;

    get recordTypeId() {
        return this.objectInfo?.data?.defaultRecordTypeId;
    }

    @wire(getPicklistValuesByRecordType, {
        objectApiName: CASE_OBJECT,
        recordTypeId: '$recordTypeId'
    })
    wiredPicklists({ data, error }) {
        if (data) {
            try {
                this.reasonOptions = data.picklistFieldValues.Reason.values;
                this.fullSubreasonMap = data.picklistFieldValues.Subreason__c.controllerValues;
                this.subreasonDependencyMap = data.picklistFieldValues.Subreason__c.values;
                // If Language is French, filter out 'Pixid VMS' from Domain options
                this.domainOptions = this.userLanguage === 'fr' ? data.picklistFieldValues.Domain__c.values.filter(option => option.value !== 'Pixid VMS') : data.picklistFieldValues.Domain__c.values;
                this.moduleOptions = data.picklistFieldValues.Module__c.values;
                this.fullModuleMap = data.picklistFieldValues.Module__c.controllerValues;
                this.moduleDependencyMap = data.picklistFieldValues.Module__c.values;
            } catch (e) {
                console.error('[Picklist Wire] Erreur parsing picklists :', e);
                this.logClientError(e, 'wiredPicklists.parsing');
            }
            
        } else if (error) {
            console.error('[Picklist Wire] Erreur chargement picklists:', error);
        }
        
    }

    connectedCallback() {
        this.isGuest = !USER_ID;
    
        if (this.isGuest) {
            return; // Ne charge rien pour les utilisateurs invités
        }
    
        getAccountId()
            .then(result => {
                this.accountId = result;
            })
            .catch(error => {
                console.error('[Account] Erreur récupération AccountId:', error);
                this.logClientError(error, 'connectedCallback.getAccountId');
            });
    
        getContactIdForCurrentUser()
            .then(contactId => {
                if (contactId) {
                    this.contactId = contactId;
                }
            })
            .catch(error => {
                console.warn('[Contact] ContactId non récupéré ou absent :', error);
            });

        getUserLanguage()
            .then(language => {
                this.userLanguage = language;
            })
            .catch(error => {
                console.error('[Language] Erreur récupération langue utilisateur:', error);
                this.logClientError(error, 'connectedCallback.getUserLanguage');
            });
    }
    

    get showDomain() {
        // Si l'utilisateur n'est pas français, ne pas afficher le champ Domain
        if (this.userLanguage && this.userLanguage !== 'fr') {
            return false;
        }
        return this.getVisibilityRule('domain');
    }
    get showModule() {
        return this.getVisibilityRule('module');
    }
    getVisibilityRule(field) {
        const rule = this.visibilityRules[this.selectedReason]?.[this.selectedSubreason];
        return rule ? rule[field] : false;
    }

    handleReasonChange(event) {
        this.selectedReason = event.detail.value;
        this.selectedSubreason = null;
        const controllerKey = this.fullSubreasonMap[this.selectedReason];
        this.subreasonOptions = this.subreasonDependencyMap
            .filter(opt => opt.validFor.includes(controllerKey))
            .map(opt => ({ label: opt.label, value: opt.value }));
    }

    handleSubreasonChange(event) {
        this.selectedSubreason = event.detail.value;
    }

    handleDomainChange(event) {
        this.selectedDomain = event.detail.value;
        const controllerKey = this.fullModuleMap[this.selectedDomain];
        this.moduleOptions = this.moduleDependencyMap
            .filter(opt => opt.validFor.includes(controllerKey))
            .map(opt => ({ label: opt.label, value: opt.value }));
        this.selectedModule = null;
    }

    handleModuleChange(event) {
        this.selectedModule = event.detail.value;
    }

    handleSubjectChange(event) {
        this.subject = event.detail.value;
    }

    handleDescriptionChange(event) {
        this.description = event.detail.value;
    }

    handleFileUpload(event) {
        const uploadedFiles = event.detail.files;
        uploadedFiles.forEach(file => {
            this.uploadedFileIds.push(file.documentId);
            this.uploadedFiles.push({ name: file.name, documentId: file.documentId });
        });
        this.showToast('Fichier ajouté', `${uploadedFiles.length} fichier(s) uploadé(s).`, 'success');
        console.log('✅ handleFileUpload called');
        console.log(JSON.stringify(event.detail.files));
        console.log(JSON.stringify(this.uploadedFiles));

    }

    handleRemoveFile(event) {
        const index = event.target.dataset.index;
        this.uploadedFiles.splice(index, 1);
        this.uploadedFileIds.splice(index, 1);
    }

    get uploadedFileCount() {
        return this.uploadedFiles.length;
    }

    get hasUploadedFiles() {
        return this.uploadedFiles.length > 0;
    }

    handleSubmit() {

        if (this.isSubmitting) return; // éviter double clic
        this.isSubmitting = true;
    
        const missingFields = [];
    
        if (!this.selectedReason) missingFields.push('la raison');
        if (!this.selectedSubreason) missingFields.push('la sous-raison');
        if (!this.subject) missingFields.push("l'objet de la demande");
        if (!this.description) missingFields.push('la description');
        if (this.showDomain && !this.selectedDomain) missingFields.push('le domaine');
        if (this.showModule && !this.selectedModule) missingFields.push('le module');
    
        if (missingFields.length > 0) {
            this.showToast('Champs requis', 'Merci de renseigner ' + missingFields.join(', ') + '.', 'error');
            this.isSubmitting = false;
            return;
        }
    
        const fields = {
            Subject: this.subject,
            Reason: this.selectedReason,
            Subreason__c: this.selectedSubreason,
            AccountId: this.accountId,
            Description: this.description,
            [ORIGIN_FIELD.fieldApiName]: 'Request_from_portal',
            [CHANNEL_FIELD.fieldApiName]: 'SELF',
            OwnerId:'00GIV00000A8Vx62AF'
        };
    
        // Si l'utilisateur n'est pas français, forcer Domain__c = "Pixid VMS"
        if (this.userLanguage && this.userLanguage !== 'fr') {
            fields.Domain__c = 'Pixid VMS';
        } else if (this.showDomain && this.selectedDomain) {
            fields.Domain__c = this.selectedDomain;
        }

        if (this.showModule && this.selectedModule) {
            fields.Module__c = this.selectedModule;
        }
    
        if (this.contactId) {
            fields.ContactId = this.contactId;
        }
        fields.Langue__c = this.userLanguage || 'fr';
    
        const recordInput = { apiName: 'Case', fields };
    
        createRecord(recordInput)
            .then(result => {
                this.caseId = result.id;
                
                // Récupérer le vrai CaseNumber
                return getCaseNumber({ caseId: result.id });
            })
            .then(caseNumber => {
                this.caseNumber = caseNumber || this.caseId; // fallback sur l'ID si problème
                this.showToast('Succès', `Case ${this.caseNumber} créé.`, 'success');
                this.showConfirmation = true;
    
                const postCreationTasks = [];
                if (this.recordId) {
                    postCreationTasks.push(
                        linkArticleToCase({ caseId: this.caseId, articleId: this.recordId })
                    );
                }
                if (this.uploadedFileIds.length > 0) {
                    postCreationTasks.push(
                        associateFilesToRecord({
                            recordId: this.caseId,
                            contentDocumentIds: this.uploadedFileIds
                        })
                    );
                }
                return Promise.all(postCreationTasks);
            })
            .catch(async error => {
                console.error('[Create Case] Erreur :', error);
                const technicalDetails = JSON.stringify(error, Object.getOwnPropertyNames(error));
                const message = this.extractErrorMessage(error);
    
                await logLWCError(message, window.location.href, {
                    userId: USER_ID,
                    subject: this.subject || null,
                    reason: this.reason || null,
                    subreason: this.subreason || null,
                    domain: this.domain || null,
                    module: this.module || null,
                    technicalDetails
                });
    
                this.showToast('Erreur', message, 'error');
            })
            .finally(() => {
                this.resetForm();
                this.isSubmitting = false;
            });
    }
    

    resetForm() {
        this.subject = null;
        this.description = null;
        this.selectedReason = null;
        this.selectedSubreason = null;
        this.selectedDomain = null;
        this.selectedModule = null;
        this.subreasonOptions = [];
        this.uploadedFileIds = [];
        this.uploadedFiles = [];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    renderedCallback() {
        console.log('uploadedFiles :', JSON.stringify(this.uploadedFiles));
    }
   
    logClientError(error, method) {
        try {
            logError({
                message: error?.message || 'Unknown error',
                stack: error?.stack || '',
                component: 'CaseFormLWC',
                pageUrl: window.location.href,
                method: method,
                browserInfo: navigator.userAgent,
                extraContext: JSON.stringify({
                    subject: this.subject,
                    reason: this.selectedReason,
                    subreason: this.selectedSubreason,
                    domain: this.selectedDomain,
                    module: this.selectedModule,
                    description: this.description,
email: this.email,
accountId: this.accountId,
contactId: this.contactId,
uploadedFileCount: this.uploadedFileIds?.length || 0,
    uploadedFileIds: this.uploadedFileIds || []
              }),
                
                userType: this.userType,
            profileName: this.profileName,
            technicalDetails: JSON.stringify(error)
            });
        } catch (loggingError) {
            // Ne surtout pas bloquer le composant si le log échoue
            console.warn('[LogError] Échec de log (silencieux) :', loggingError);
        }
    }
    
    extractErrorMessage(error) {
        if (!error) return 'Unknown error';
    
        // Si c'est une chaîne brute
        if (typeof error === 'string') return error;
    
        if (error.body?.message && error.body?.errorCode) {
            return `[${error.body.errorCode}] ${error.body.message}`;
        }
    
        if (Array.isArray(error.body)) {
            return error.body.map(e => {
                if (e.message && e.errorCode) {
                    return `[${e.errorCode}] ${e.message}`;
                }
                return JSON.stringify(e);
            }).join(' | ');
        }
    
        if (error.message) return error.message;
    
        if (error.body?.message) return error.body.message;
    
        // Fallback
        try {
            return JSON.stringify(error);
        } catch (e) {
            return 'Unserializable error object';
        }
    }
    
    get isDomainRequired() {
        return this.isFieldRequired('Domain__c');
    }
    
    get isModuleRequired() {
        return this.isFieldRequired('Module__c');
    }
    
    isFieldRequired(fieldApiName) {
        if (fieldApiName === 'Domain__c') return this.showDomain;
        if (fieldApiName === 'Module__c') return this.showModule;
        return false;
    }
    
    

}