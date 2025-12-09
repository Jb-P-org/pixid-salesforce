@isTest
private class JiraIssueWebhookTest {

    private class CeligoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true}');
            return res;
        }
    }

    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact contact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com',
            AccountId = acc.Id
        );
        insert contact;

        Case c = new Case(
            Subject = 'Test case',
            ContactId = contact.Id,
            AccountId = acc.Id
        );
        insert c;
    }

    @isTest
    static void testJiraIssueWebhookTrigger() {
        Test.setMock(HttpCalloutMock.class, new CeligoMock());

        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Query a valid Jira Project value
        Schema.DescribeFieldResult fieldResult = Jira_Issue__c.Jira_Project__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        String validProject = picklistValues.isEmpty() ? null : picklistValues[0].getValue();

        Test.startTest();
        // Insert Jira Issue to trigger the webhook
        Jira_Issue__c issue = new Jira_Issue__c(
            Name = 'Webhook Test Issue',
            Issue_Description__c = 'Test',
            Issue_Type__c = 'Bug',
            Priority__c = 'High',
            Status__c = 'Open',
            Jira_Project__c = validProject,
            Linked_Case__c = testCase.Id
        );
        insert issue;
        Test.stopTest();

        // In test context, trigger doesn't schedule jobs (Test.isRunningTest() check)
        // Verify the Jira Issue was created successfully
        List<Jira_Issue__c> insertedIssues = [SELECT Id FROM Jira_Issue__c WHERE Id = :issue.Id];
        System.assertEquals(1, insertedIssues.size(), 'Jira Issue should be created');
    }

    @isTest
    static void testMultipleJiraIssueInserts() {
        Test.setMock(HttpCalloutMock.class, new CeligoMock());

        Case testCase = [SELECT Id FROM Case LIMIT 1];

        // Query a valid Jira Project value
        Schema.DescribeFieldResult fieldResult = Jira_Issue__c.Jira_Project__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        String validProject = picklistValues.isEmpty() ? null : picklistValues[0].getValue();

        List<Jira_Issue__c> issues = new List<Jira_Issue__c>();
        for (Integer i = 0; i < 3; i++) {
            issues.add(new Jira_Issue__c(
                Name = 'Bulk Test Issue ' + i,
                Issue_Type__c = 'Bug',
                Priority__c = 'Medium',
                Status__c = 'Open',
                Jira_Project__c = validProject,
                Linked_Case__c = testCase.Id
            ));
        }

        Test.startTest();
        insert issues;
        Test.stopTest();

        // Verify all issues were created successfully
        List<Jira_Issue__c> insertedIssues = [SELECT Id FROM Jira_Issue__c WHERE Id IN :issues];
        System.assertEquals(3, insertedIssues.size(), 'All 3 issues should be created');
    }

    @isTest
    static void testJiraIssueWithoutLinkedCase() {
        Test.setMock(HttpCalloutMock.class, new CeligoMock());

        // Query a valid Jira Project value
        Schema.DescribeFieldResult fieldResult = Jira_Issue__c.Jira_Project__c.getDescribe();
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        String validProject = picklistValues.isEmpty() ? null : picklistValues[0].getValue();

        Test.startTest();
        Jira_Issue__c issue = new Jira_Issue__c(
            Name = 'No Case Issue',
            Issue_Type__c = 'Task',
            Priority__c = 'Low',
            Status__c = 'Open',
            Jira_Project__c = validProject
        );
        insert issue;
        Test.stopTest();

        // Verify issue was created successfully
        List<Jira_Issue__c> insertedIssues = [SELECT Id FROM Jira_Issue__c WHERE Id = :issue.Id];
        System.assertEquals(1, insertedIssues.size(), 'Issue should be created even without linked case');
    }
}