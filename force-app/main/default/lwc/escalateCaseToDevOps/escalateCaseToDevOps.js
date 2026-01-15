import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { FlowAttributeChangeEvent, FlowNavigationFinishEvent } from 'lightning/flowSupport';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import CASE_OBJECT from '@salesforce/schema/Case';
import getCaseAndRecordTypes from '@salesforce/apex/EscalationController.getCaseAndRecordTypes';
import getJiraPicklists from '@salesforce/apex/EscalationController.getJiraPicklists';
import escalateCase from '@salesforce/apex/EscalationController.escalateCase';
import linkFilesToJiraIssue from '@salesforce/apex/EscalationController.linkFilesToJiraIssue';

import Escalation_subreason from '@salesforce/label/c.Escalation_subreason';
import Escalation_reason from '@salesforce/label/c.Escalation_reason';
import Expected_behavior from '@salesforce/label/c.Expected_behavior';
import Current_behavior from '@salesforce/label/c.Current_behavior';
import Context from '@salesforce/label/c.Context';
import Details from '@salesforce/label/c.Details';
import Client_request from '@salesforce/label/c.Client_request';
import Next from '@salesforce/label/c.Next';
import Issue_scope from '@salesforce/label/c.Issue_scope';
import Issue_type from '@salesforce/label/c.Issue_type';
import Jira_Project from '@salesforce/label/c.Jira_Project';
import Which_team_escalation from '@salesforce/label/c.Which_team_escalation';
import CaseHasBeenEscalated from '@salesforce/label/c.Case_has_been_escalated';
import Priority from '@salesforce/label/c.Priority';
import Add_files from '@salesforce/label/c.Add_files';
import Actions_requested from '@salesforce/label/c.Actions_requested';
import FilesAdded from '@salesforce/label/c.Files_added';

export default class EscalateCaseToDevOps extends LightningElement {
    label = {
        Escalation_subreason,
        Escalation_reason,
        Expected_behavior,
        Current_behavior,
        Context,
        Client_request,
        Next,
        Issue_scope,
        Issue_type,
        Jira_Project,
        Which_team_escalation,
        Priority,
        Add_files,
        Actions_requested,
        CaseHasBeenEscalated,
        FilesAdded,
        Details
    };

    @api recordId;
    @track isLoading = true;
    @track step = 'selectTeam';

    @track recordTypeOptions = [];
    selectedRecordTypeName = '';
    selectedRecordTypeId = '';

    @track reasonOptions = [];
    @track fullSubreasonOptions = [];
    @track filteredSubreasons = [];
    controllerMap = {};

    escalationReason = '';
    escalationSubreason = '';
    comment = '';

    jiraProject = '';
    issueType = '';
    jiraProjectOptions = [];
    issueTypeOptions = [];

    currentBehavior = '';
    expectedBehavior = '';
    issueScope = '';
    priority = '';
    issueScopeOptions = [];
    priorityOptions = [];

    clientRequest = '';
    context = '';
    actionsRequested = '';
    priority = 'Low';

    @track jiraIssueId;
    @track uploadedFiles = [];
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx', '.xls', '.csv', '.xlsx', '.xml', '.dash', '.msg', '.mp4', '.txt'];

    @wire(getObjectInfo, { objectApiName: CASE_OBJECT }) objectInfo;

    @wire(getPicklistValuesByRecordType, {
        objectApiName: CASE_OBJECT,
        recordTypeId: '$selectedRecordTypeId'
    })
    wiredPicklists({ data, error }) {
        if (data) {
            this.reasonOptions = data.picklistFieldValues.EscalationReason__c?.values || [];
            const sub = data.picklistFieldValues.Escalation_Subreason__c;
            this.fullSubreasonOptions = sub?.values || [];
            this.controllerMap = sub?.controllerValues || {};
        } else if (error) {
            console.error('Picklist wiring error:', error);
        }
    }

    connectedCallback() {
        this.loadCaseData();
        
    }

    async loadCaseData() {
        this.isLoading = true;
        try {
            const result = await getCaseAndRecordTypes({ caseId: this.recordId });
            this.recordTypeOptions = result.recordTypes;
        } catch (error) {
            console.error(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleRecordTypeChange(event) {
        this.selectedRecordTypeName = event.detail.value;
        const selected = this.recordTypeOptions.find(r => r.value === this.selectedRecordTypeName);
        this.selectedRecordTypeId = null;
        await Promise.resolve();
        this.selectedRecordTypeId = selected?.id;
    }

    handleReasonChange(event) {
        this.escalationReason = event.detail.value;
        const controllerIndex = this.controllerMap[this.escalationReason];
        this.filteredSubreasons = this.fullSubreasonOptions.filter(sub =>
            sub.validFor.includes(controllerIndex)
        );
    }

    handlePicklistChange(event) {
        this[event.target.name] = event.detail.value;
    }

    handleIssueTypeChange(event) {
        this.issueType = event.detail.value;
        const type = this.issueType?.toLowerCase();
        if (!this.priority && this.priorityOptions.length > 0) {
            const defaultOption = this.priorityOptions.find(opt => opt.label.toLowerCase() === 'low');
            if (defaultOption) {
                this.priority = defaultOption.value;
            }
        }
        
    }

    async handleNextFromSelectTeam() {
        const currentStepEl = this.template.querySelector('[data-step="selectTeam"]');
        const isValid = [...currentStepEl.querySelectorAll('[required]')].every(el => {
            el.reportValidity();
            return el.checkValidity();
        });

        if (!isValid || !this.selectedRecordTypeId) return;

        const isDevOps = this.selectedRecordTypeName.toLowerCase().includes('devops');

        if (isDevOps) {
            this.step = 'jiraFields';
            const picklists = await getJiraPicklists();
            this.jiraProjectOptions = picklists['Jira_Project__c'] || [];
            this.issueTypeOptions = picklists['Issue_Type__c'] || [];
            this.issueScopeOptions = picklists['IssueScope__c'] || [];
            this.priorityOptions = picklists['Priority__c'] || [];
        } else {
            this.resetOtherTeamFields();
            this.step = 'otherTeamFields';
        }
    }

    handleNextFromJira() {
        const currentStepEl = this.template.querySelector('[data-step="jiraFields"]');
        const isValid = [...currentStepEl.querySelectorAll('[required]')].every(el => {
            el.reportValidity();
            return el.checkValidity();
        });

        if (!isValid || !this.jiraProject || !this.issueType) return;

        const type = this.issueType?.toLowerCase();
        if (type === 'bug') {
            this.resetBugFields();
            this.step = 'bugFields';
        } else if (type === 'story') {
            this.resetStoryFields();
            this.step = 'storyFields';
        } else if (type === 'task') {
            this.resetTaskFields();
            this.step = 'taskFields';
        } else {
            this.handleSubmit();
        }
    }

    async handleSubmit() {
        const currentStepEl = this.template.querySelector(`[data-step="${this.step}"]`);
        const isValid = [...currentStepEl.querySelectorAll('[required]')].every(el => {
            el.reportValidity();
            return el.checkValidity();
        });

        const manualFieldCheck = () => {
            if (this.step === 'bugFields') {
                return this.currentBehavior && this.expectedBehavior && this.issueScope;
            }
            if (this.step === 'storyFields') {
                return this.clientRequest;
            }
            if (this.step === 'taskFields') {
                return this.context && this.actionsRequested;
            }
            if (this.step === 'otherTeamFields') {
                return this.comment && this.escalationReason &&
                    (this.filteredSubreasons.length === 0 || this.escalationSubreason);
            }
            return true;
        };

        if (!isValid || !manualFieldCheck()) return;

        this.isLoading = true;
        try {
            const result = await escalateCase({
                caseId: this.recordId,
                recordTypeName: this.selectedRecordTypeName,
                escalationReason: this.escalationReason,
                escalationSubreason: this.escalationSubreason,
                comment: this.comment,
                jiraProject: this.jiraProject,
                issueType: this.issueType,
                currentBehavior: this.currentBehavior,
                expectedBehavior: this.expectedBehavior,
                issueScope: this.issueScope,
                priority: this.priority,
                actionsRequested: this.actionsRequested,
                clientRequest: this.clientRequest,
                context: this.context
            });

            if (result) {
                this.jiraIssueId = result;
                await this.updateUploadedFiles();
                await this.launchFlowAfterFileLinking();
            }

            this.step = 'confirmation';
        } catch (err) {
            console.error('Error submitting:', err);
        } finally {
            this.isLoading = false;
        }
    }

    handleBack() {
        if (this.step === 'jiraFields') {
            this.resetJiraFields();
            this.selectedRecordTypeId = null;
            this.selectedRecordTypeName = '';
            this.step = 'selectTeam';
        } else if (['bugFields', 'storyFields', 'taskFields'].includes(this.step)) {
            this.resetAllIssueFields();
            this.step = 'jiraFields';
        } else if (this.step === 'otherTeamFields') {
            this.resetOtherTeamFields();
            this.selectedRecordTypeId = null;
            this.selectedRecordTypeName = '';
            this.step = 'selectTeam';
        }
    }

    async handleUploadFinished(event) {
        this.uploadedFiles = [...this.uploadedFiles, ...event.detail.files];
    }

    handleRemoveFile(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.uploadedFiles.splice(index, 1);
        this.uploadedFiles = [...this.uploadedFiles];
    }

    async updateUploadedFiles() {
        if (!this.jiraIssueId || !this.uploadedFiles.length) return;
        const docIds = this.uploadedFiles.map(file => file.documentId);
        try {
            await linkFilesToJiraIssue({
                caseId: this.recordId,
                jiraIssueId: this.jiraIssueId,
                documentIds: docIds
            });
        } catch (error) {
            console.error('Erreur lors de l’association des fichiers :', error);
        }
    }

    async launchFlowAfterFileLinking() {
        try {
            const flow = this.template.querySelector('lightning-flow');
            if (flow) {
                flow.startFlow('Create_Public_URL_For_Jira_Attachments', [
                    { name: 'recordId', type: 'String', value: this.jiraIssueId }
                ]);
            }
        } catch (err) {
            console.error('Erreur lors du lancement du flow :', err);
        }
    }

    closeModal() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    resetJiraFields() {
        this.jiraProject = '';
        this.issueType = '';
    }

    resetBugFields() {
        this.currentBehavior = '';
        this.expectedBehavior = '';
        this.issueScope = '';
    }

    resetStoryFields() {
        this.clientRequest = '';
    }

    resetTaskFields() {
        this.context = '';
        this.actionsRequested = '';
    }

    resetOtherTeamFields() {
        this.comment = '';
        this.escalationReason = '';
        this.escalationSubreason = '';
        this.filteredSubreasons = [];
    }

    resetAllIssueFields() {
        this.resetBugFields();
        this.resetStoryFields();
        this.resetTaskFields();
    }

    get isStepSelectTeam() {
        return this.step === 'selectTeam';
    }

    get isStepJiraFields() {
        return this.step === 'jiraFields';
    }

    get isStepBugFields() {
        return this.step === 'bugFields';
    }

    get isStepStoryFields() {
        return this.step === 'storyFields';
    }

    get isStepTaskFields() {
        return this.step === 'taskFields';
    }

    get isStepOtherTeamFields() {
        return this.step === 'otherTeamFields';
    }

    get isStepConfirmation() {
        return this.step === 'confirmation';
    }

    get showJiraLink() {
        return this.jiraIssueId !== '';
    }

    get jiraIssueUrl() {
        return `/lightning/r/Jira_Issue__c/${this.jiraIssueId}/view`;
    }

    get hasUploadedFiles() {
        return this.uploadedFiles && this.uploadedFiles.length > 0;
    }

    get shouldShowFileUpload() {
        return ['bugFields', 'storyFields', 'taskFields'].includes(this.step);
    }

    get showSubreason() {
        return this.filteredSubreasons && this.filteredSubreasons.length > 0;
    }
}