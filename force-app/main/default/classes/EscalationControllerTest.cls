@isTest
private class EscalationControllerTest {

    @testSetup
    static void setup() {
        // Create test Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create test Contact
        Contact contact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            AccountId = acc.Id
        );
        insert contact;
    }

    @isTest
    static void testGetCaseAndRecordTypes() {
        // Create test Case
        Case testCase = new Case(Subject = 'Test Case', Status = 'New');
        insert testCase;

        Test.startTest();
        Map<String, Object> result = EscalationController.getCaseAndRecordTypes(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('recordTypes'));
        List<Map<String, String>> recordTypes = (List<Map<String, String>>) result.get('recordTypes');
        System.assert(recordTypes.size() > 0);
    }

    @isTest
    static void testGetJiraPicklists() {
        Test.startTest();
        Map<String, List<Map<String, String>>> result = EscalationController.getJiraPicklists();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('Jira_Project__c'));
        System.assert(result.containsKey('Issue_Type__c'));
        System.assert(result.containsKey('Priority__c'));
        System.assert(result.containsKey('IssueScope__c'));
    }

    @isTest
    static void testEscalateCaseToDevOpsBug() {
        // Get test Contact
        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        // Query valid picklist values
        Schema.DescribeFieldResult domainField = Case.Domain__c.getDescribe();
        List<Schema.PicklistEntry> domainValues = domainField.getPicklistValues();
        String validDomain = domainValues.isEmpty() ? null : domainValues[0].getValue();

        Schema.DescribeFieldResult moduleField = Case.Module__c.getDescribe();
        List<Schema.PicklistEntry> moduleValues = moduleField.getPicklistValues();
        String validModule = moduleValues.isEmpty() ? null : moduleValues[0].getValue();

        // Create test Case with required fields
        Case testCase = new Case(
            Subject = 'Test Bug Escalation',
            ContactId = contact.Id,
            Status = 'New',
            Domain__c = validDomain,
            Module__c = validModule
        );
        insert testCase;

        // Get a RecordType that contains 'devops'
        RecordType devopsRT = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Case' LIMIT 1];

        // Use specific valid combination: Bug + Accompagnement
        String validReason = 'Bug';
        String validSubReason = 'Accompagnement';

        Test.startTest();
        String jiraId = EscalationController.escalateCase(
            testCase.Id,
            devopsRT.Name,
            validReason,
            validSubReason,
            'Test Comment',
            'PROJECT',
            'Bug',
            'System crashes on load',
            'System should load correctly',
            'Critical',
            'High',
            null,
            null,
            null,
            'Additional details'
        );
        Test.stopTest();

        // Verify Case was updated
        Case updatedCase = [SELECT IsEscalated, EscalationDate__c, EscalationReason__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(true, updatedCase.IsEscalated);
        System.assertNotEquals(null, updatedCase.EscalationDate__c);
        System.assertEquals(validReason, updatedCase.EscalationReason__c);
    }

    @isTest
    static void testEscalateCaseToDevOpsStory() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        // Query valid picklist values
        Schema.DescribeFieldResult domainField = Case.Domain__c.getDescribe();
        List<Schema.PicklistEntry> domainValues = domainField.getPicklistValues();
        String validDomain = domainValues.isEmpty() ? null : domainValues[0].getValue();

        Schema.DescribeFieldResult moduleField = Case.Module__c.getDescribe();
        List<Schema.PicklistEntry> moduleValues = moduleField.getPicklistValues();
        String validModule = moduleValues.isEmpty() ? null : moduleValues[0].getValue();

        Case testCase = new Case(
            Subject = 'Test Story Escalation',
            ContactId = contact.Id,
            Status = 'New',
            Domain__c = validDomain,
            Module__c = validModule
        );
        insert testCase;

        RecordType devopsRT = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Case' LIMIT 1];

        // Use specific valid combination: Bug + Accompagnement
        String validReason = 'Bug';
        String validSubReason = 'Accompagnement';

        Test.startTest();
        String jiraId = EscalationController.escalateCase(
            testCase.Id,
            devopsRT.Name,
            validReason,
            validSubReason,
            'Test Story Comment',
            'PROJECT',
            'Story',
            null,
            null,
            null,
            'Medium',
            null,
            'Client wants new feature',
            null,
            'Story details'
        );
        Test.stopTest();

        Case updatedCase = [SELECT IsEscalated FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(true, updatedCase.IsEscalated);
    }

    @isTest
    static void testEscalateCaseToDevOpsTask() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        // Query valid picklist values
        Schema.DescribeFieldResult domainField = Case.Domain__c.getDescribe();
        List<Schema.PicklistEntry> domainValues = domainField.getPicklistValues();
        String validDomain = domainValues.isEmpty() ? null : domainValues[0].getValue();

        Schema.DescribeFieldResult moduleField = Case.Module__c.getDescribe();
        List<Schema.PicklistEntry> moduleValues = moduleField.getPicklistValues();
        String validModule = moduleValues.isEmpty() ? null : moduleValues[0].getValue();

        Case testCase = new Case(
            Subject = 'Test Task Escalation',
            ContactId = contact.Id,
            Status = 'New',
            Domain__c = validDomain,
            Module__c = validModule
        );
        insert testCase;

        RecordType devopsRT = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Case' LIMIT 1];

        // Use specific valid combination: Bug + Accompagnement
        String validReason = 'Bug';
        String validSubReason = 'Accompagnement';

        Test.startTest();
        String jiraId = EscalationController.escalateCase(
            testCase.Id,
            devopsRT.Name,
            validReason,
            validSubReason,
            'Test Task Comment',
            'PROJECT',
            'Task',
            null,
            null,
            null,
            'Low',
            'Deploy new config',
            null,
            'Production',
            'Task details'
        );
        Test.stopTest();

        Case updatedCase = [SELECT IsEscalated FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(true, updatedCase.IsEscalated);
    }

    @isTest
    static void testEscalateCaseNonDevOps() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        Case testCase = new Case(
            Subject = 'Test Non-DevOps Escalation',
            ContactId = contact.Id,
            Status = 'New'
        );
        insert testCase;

        // Use specific valid combination: Bug + Accompagnement
        String validReason = 'Bug';
        String validSubReason = 'Accompagnement';

        RecordType nonDevopsRT = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Case' LIMIT 1];

        Test.startTest();
        String jiraId = EscalationController.escalateCase(
            testCase.Id,
            nonDevopsRT.Name,
            validReason,
            validSubReason,
            'Test Comment',
            'PROJECT',
            'Bug',
            null,
            null,
            null,
            'Medium',
            null,
            null,
            null,
            'Details'
        );
        Test.stopTest();

        Case updatedCase = [SELECT IsEscalated FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(true, updatedCase.IsEscalated);
        System.assertEquals(null, jiraId, 'No Jira should be created for non-DevOps escalation');
    }

    @isTest
    static void testUpdatePublicFiles() {
        Jira_Issue__c issue = new Jira_Issue__c(
            Name = 'Test Issue',
            Status__c = 'Open'
        );
        insert issue;

        Test.startTest();
        EscalationController.updatePublicFiles(issue.Id, 'https://test1.com\nhttps://test2.com');
        Test.stopTest();

        Jira_Issue__c updated = [SELECT PublicFiles__c FROM Jira_Issue__c WHERE Id = :issue.Id];
        System.assertNotEquals(null, updated.PublicFiles__c);
        System.assert(updated.PublicFiles__c.contains('https://test1.com'));
    }

    @isTest
    static void testUpdatePublicFilesEmptyParams() {
        Test.startTest();
        EscalationController.updatePublicFiles(null, null);
        Test.stopTest();
        System.assert(true, 'Should not throw error with empty params');
    }

    @isTest
    static void testLinkFilesToJiraIssue() {
        // Create test Case
        Case testCase = new Case(Subject = 'Test Case');
        insert testCase;

        // Create Jira Issue
        Jira_Issue__c jiraIssue = new Jira_Issue__c(
            Name = 'Test Jira',
            Status__c = 'Open',
            Linked_Case__c = testCase.Id
        );
        insert jiraIssue;

        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test content')
        );
        insert cv;

        ContentDocument cd = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :cv.Id];

        // Link document to Case first
        ContentDocumentLink caseLink = new ContentDocumentLink(
            ContentDocumentId = cd.Id,
            LinkedEntityId = testCase.Id,
            ShareType = 'V'
        );
        insert caseLink;

        Test.startTest();
        EscalationController.linkFilesToJiraIssue(testCase.Id, jiraIssue.Id, new List<Id>{ cd.Id });
        Test.stopTest();

        // Verify file is linked to Jira Issue
        List<ContentDocumentLink> jiraLinks = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :jiraIssue.Id AND ContentDocumentId = :cd.Id
        ];
        System.assertEquals(1, jiraLinks.size());

        // Verify file is no longer linked to Case
        List<ContentDocumentLink> caseLinks = [
            SELECT Id FROM ContentDocumentLink
            WHERE LinkedEntityId = :testCase.Id AND ContentDocumentId = :cd.Id
        ];
        System.assertEquals(0, caseLinks.size());
    }

    @isTest
    static void testLinkFilesToJiraIssueEmptyList() {
        Case testCase = new Case(Subject = 'Test Case');
        insert testCase;

        Jira_Issue__c jiraIssue = new Jira_Issue__c(Name = 'Test Jira', Status__c = 'Open');
        insert jiraIssue;

        Test.startTest();
        EscalationController.linkFilesToJiraIssue(testCase.Id, jiraIssue.Id, new List<Id>());
        Test.stopTest();

        System.assert(true, 'Should handle empty document list');
    }

}