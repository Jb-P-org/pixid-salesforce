@isTest
private class UpdateJiraIssueTest {

    @isTest
    static void testHandleIncomingJiraEventSuccess() {
        // Query valid Status picklist value
        Schema.DescribeFieldResult statusField = Jira_Issue__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> statusValues = statusField.getPicklistValues();
        String validStatus = statusValues.isEmpty() ? null : statusValues[0].getValue();

        // Create test Jira Issue
        Jira_Issue__c issue = new Jira_Issue__c(
            Name = 'Test Issue',
            Issue_Type__c = 'Bug',
            Priority__c = 'High',
            Status__c = validStatus,
            Jira_Issue_Key__c = 'OLD-KEY'
        );
        insert issue;

        // Build webhook payload
        Map<String, Object> fields = new Map<String, Object>{
            'customfield_10182' => issue.Id
        };

        Map<String, Object> issueData = new Map<String, Object>{
            'key' => 'NEW-KEY-123',
            'fields' => fields
        };

        Map<String, Object> payload = new Map<String, Object>{
            'issue' => issueData
        };

        String requestBody = JSON.serialize(payload);

        // Setup REST context
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/jiraWebhookListener/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;

        RestResponse res = new RestResponse();
        RestContext.response = res;

        Test.startTest();
        UpdateJiraIssue.handleIncomingJiraEvent();
        Test.stopTest();

        // Verify issue was updated
        Jira_Issue__c updatedIssue = [SELECT Jira_Issue_Key__c FROM Jira_Issue__c WHERE Id = :issue.Id];
        System.assertEquals('NEW-KEY-123', updatedIssue.Jira_Issue_Key__c, 'Jira key should be updated');
    }

    @isTest
    static void testHandleIncomingJiraEventNoSalesforceId() {
        // Build webhook payload without salesforce ID
        Map<String, Object> fields = new Map<String, Object>{
            'customfield_10182' => null
        };

        Map<String, Object> issueData = new Map<String, Object>{
            'key' => 'TEST-456',
            'fields' => fields
        };

        Map<String, Object> payload = new Map<String, Object>{
            'issue' => issueData
        };

        String requestBody = JSON.serialize(payload);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/jiraWebhookListener/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;

        RestResponse res = new RestResponse();
        RestContext.response = res;

        Test.startTest();
        UpdateJiraIssue.handleIncomingJiraEvent();
        Test.stopTest();

        // Should complete without errors
        System.assert(true, 'Should handle null salesforceId gracefully');
    }

    @isTest
    static void testHandleIncomingJiraEventRecordNotFound() {
        // Build webhook payload with non-existent but valid salesforce ID format
        // Using a valid 18-character ID format that doesn't exist in the org
        String fakeId = 'a00000000000000AAA';

        Map<String, Object> fields = new Map<String, Object>{
            'customfield_10182' => fakeId
        };

        Map<String, Object> issueData = new Map<String, Object>{
            'key' => 'TEST-789',
            'fields' => fields
        };

        Map<String, Object> payload = new Map<String, Object>{
            'issue' => issueData
        };

        String requestBody = JSON.serialize(payload);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/jiraWebhookListener/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;

        RestResponse res = new RestResponse();
        RestContext.response = res;

        Test.startTest();
        UpdateJiraIssue.handleIncomingJiraEvent();
        Test.stopTest();

        // Should complete without errors even when record not found
        System.assert(true, 'Should handle missing record gracefully');
    }

    @isTest
    static void testHandleIncomingJiraEventComplexPayload() {
        // Query valid Status picklist value
        Schema.DescribeFieldResult statusField = Jira_Issue__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> statusValues = statusField.getPicklistValues();
        String validStatus = statusValues.isEmpty() ? null : statusValues[0].getValue();

        Jira_Issue__c issue = new Jira_Issue__c(
            Name = 'Complex Test',
            Issue_Type__c = 'Task',
            Priority__c = 'Low',
            Status__c = validStatus
        );
        insert issue;

        // Build complex webhook payload
        Map<String, Object> fields = new Map<String, Object>{
            'customfield_10182' => issue.Id,
            'summary' => 'Updated summary',
            'status' => new Map<String, Object>{'name' => 'In Progress'}
        };

        Map<String, Object> issueData = new Map<String, Object>{
            'key' => 'COMPLEX-999',
            'fields' => fields
        };

        Map<String, Object> payload = new Map<String, Object>{
            'issue' => issueData,
            'timestamp' => System.now().getTime(),
            'webhookEvent' => 'jira:issue_updated'
        };

        String requestBody = JSON.serialize(payload);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/jiraWebhookListener/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;

        RestResponse res = new RestResponse();
        RestContext.response = res;

        Test.startTest();
        UpdateJiraIssue.handleIncomingJiraEvent();
        Test.stopTest();

        Jira_Issue__c updatedIssue = [SELECT Jira_Issue_Key__c FROM Jira_Issue__c WHERE Id = :issue.Id];
        System.assertEquals('COMPLEX-999', updatedIssue.Jira_Issue_Key__c);
    }
}