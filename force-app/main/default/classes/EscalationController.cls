public without sharing class EscalationController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCaseAndRecordTypes(Id caseId) {
        Case c = [SELECT Id, RecordTypeId FROM Case WHERE Id = :caseId LIMIT 1];

        // Check if user has the "BU Pixid VMS USA" role
        Boolean isVmsUsaRole = false;
        String userRoleId = UserInfo.getUserRoleId();
        if (String.isNotBlank(userRoleId)) {
            UserRole currentRole = [SELECT Name FROM UserRole WHERE Id = :userRoleId LIMIT 1];
            isVmsUsaRole = currentRole.Name == 'BU Pixid VMS USA';
        }

        List<RecordType> recordTypes;
        if (isVmsUsaRole) {
            // Only return DevOps record type for VMS USA users
            recordTypes = [
                SELECT Id, Name FROM RecordType
                WHERE SObjectType = 'Case' AND Name LIKE '%DevOps%'
            ];
        } else {
            recordTypes = [
                SELECT Id, Name FROM RecordType
                WHERE SObjectType = 'Case'
            ];
        }

        List<Map<String, String>> options = new List<Map<String, String>>();
        for (RecordType rt : recordTypes) {
            options.add(new Map<String, String>{
                'label' => rt.Name,
                'value' => rt.Name,
                'id' => rt.Id
            });
        }
        return new Map<String, Object>{ 'recordTypes' => options };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getJiraPicklists() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();
        for (String field : new List<String>{'Jira_Project__c', 'Issue_Type__c', 'Priority__c', 'IssueScope__c'}) {
            Schema.DescribeFieldResult dfr = Jira_Issue__c.SObjectType.getDescribe().fields.getMap().get(field).getDescribe();
            List<Map<String, String>> values = new List<Map<String, String>>();
            for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
                values.add(new Map<String, String>{ 'label' => e.getLabel(), 'value' => e.getValue() });
            }
            result.put(field, values);
        }
        return result;
    }

    @AuraEnabled
    public static String escalateCase(
        Id caseId,
        String recordTypeName,
        String escalationReason,
        String escalationSubreason,
        String comment,
        String jiraProject,
        String issueType,
        String currentBehavior,
        String expectedBehavior,
        String issueScope,
        String priority,
        String actionsRequested,
        String clientRequest,
        String context,
        String escalationDetail
    ) {
        RecordType rt = [
            SELECT Id FROM RecordType
            WHERE Name = :recordTypeName AND SObjectType = 'Case'
            LIMIT 1
        ];

        Case c = [
            SELECT Id, CaseNumber, Contact.Name, Domain__c, Module__c, Status
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        // Champs d’escalade
        c.RecordTypeId             = rt.Id;
        c.IsEscalated              = true;
        c.EscalationDate__c        = Date.today();
        c.EscalationReason__c      = escalationReason;
        c.Escalation_Subreason__c  = escalationSubreason;
        c.Escalation_Detail__c     = comment;

        // Si escalade vers DevOps, passer le Case en "On Hold"
        if (recordTypeName != null && recordTypeName.toLowerCase().contains('devops')) {
            if (c.Status != 'On Hold') {
                c.Status = 'On Hold';
            }
        }

        // Un seul DML sur Case
        update c;

        // Création de la Jira Issue uniquement pour DevOps
        if (recordTypeName != null && recordTypeName.toLowerCase().contains('devops')) {
            String issueTypeLower = issueType != null ? issueType.toLowerCase() : '';
            String jiraName = issueType;

            if (!String.isBlank(c.CaseNumber)) {
                jiraName += ' - ' + c.CaseNumber;
            }
            if (c.Contact != null && !String.isBlank(c.Contact.Name)) {
                jiraName += ' - ' + c.Contact.Name;
            }

            Jira_Issue__c jira = new Jira_Issue__c(
                Name            = jiraName,
                Linked_Case__c  = c.Id,
                Jira_Project__c = jiraProject,
                Issue_Type__c   = issueType,
                Priority__c     = priority,
                Domain__c       = c.Domain__c,
                Module__c       = c.Module__c,
                Status__c       = 'Open'
            );

            if (issueTypeLower == 'bug') {
                jira.CurrentBehavior__c = currentBehavior;
                jira.ExpectedBehavior__c = expectedBehavior;
                jira.IssueScope__c = issueScope;
            } else if (issueTypeLower == 'story') {
                jira.ClientRequest__c = clientRequest;
                jira.Priority__c = 'Low';
            } else if (issueTypeLower == 'task') {
                jira.Context__c = context;
                jira.ActionsRequested__c = actionsRequested;
            }

            insert jira;
            return jira.Id;
        }
        return null;
    }

    @AuraEnabled
    public static void updatePublicFiles(Id jiraIssueId, String publicUrls) {
        if (String.isBlank(jiraIssueId) || String.isBlank(publicUrls)) return;

        Jira_Issue__c issue = [
            SELECT Id, PublicFiles__c
            FROM Jira_Issue__c
            WHERE Id = :jiraIssueId
            LIMIT 1
        ];

        issue.PublicFiles__c = publicUrls;
        update issue;
    }

    @AuraEnabled
    public static void linkFilesToJiraIssue(Id caseId, Id jiraIssueId, List<Id> documentIds) {
        if (documentIds == null || documentIds.isEmpty()) return;

        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();

        for (Id docId : documentIds) {
            newLinks.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId = jiraIssueId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }

        insert newLinks;

        // Supprimer les liens entre ces fichiers et le Case
        List<ContentDocumentLink> linksToDelete = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :caseId
            AND ContentDocumentId IN :documentIds
        ];
        delete linksToDelete;
    }
    @AuraEnabled
public static String testCaseUpdate(Id caseId) {
    Case c = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
    c.Status = 'On Hold';
    update c;
    return 'Success';
}
}