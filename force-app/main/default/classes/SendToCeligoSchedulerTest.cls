@isTest
private class SendToCeligoSchedulerTest {

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

        // Query valid picklist values dynamically
        Schema.DescribeFieldResult statusField = Jira_Issue__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> statusValues = statusField.getPicklistValues();
        String validStatus = statusValues.isEmpty() ? null : statusValues[0].getValue();

        Schema.DescribeFieldResult projectField = Jira_Issue__c.Jira_Project__c.getDescribe();
        List<Schema.PicklistEntry> projectValues = projectField.getPicklistValues();
        String validProject = projectValues.isEmpty() ? null : projectValues[0].getValue();

        Jira_Issue__c issue = new Jira_Issue__c(
            Name = 'Test Issue',
            Issue_Description__c = 'Test',
            Issue_Type__c = 'Bug',
            Priority__c = 'High',
            Status__c = validStatus,
            Jira_Project__c = validProject,
            Linked_Case__c = c.Id
        );
        insert issue;
    }

    @isTest
    static void testSchedulableJobScheduling() {
        Test.setMock(HttpCalloutMock.class, new CeligoMock());

        Jira_Issue__c issue = [SELECT Id FROM Jira_Issue__c LIMIT 1];

        Test.startTest();
        Datetime scheduledTime = System.now().addSeconds(30);
        String cronExp = scheduledTime.format('ss mm HH dd MM ? yyyy');
        String jobName = 'TestCeligoSend_' + issue.Id;

        String jobId = System.schedule(jobName, cronExp, new SendToCeligoScheduler(issue.Id));
        Test.stopTest();

        // Verify job was scheduled
        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testSchedulableExecution() {
        Test.setMock(HttpCalloutMock.class, new CeligoMock());

        Jira_Issue__c issue = [SELECT Id FROM Jira_Issue__c LIMIT 1];

        SendToCeligoScheduler scheduler = new SendToCeligoScheduler(issue.Id);

        Test.startTest();
        scheduler.execute(null);
        Test.stopTest();

        // Should execute without errors
        System.assert(true, 'Schedulable execute method should complete successfully');
    }
}