@isTest
private class JiraCommentWebhookTest {

    @isTest
    static void testReceiveWebhook_Success() {
        // Création d'un Jira_Issue__c fictif
        Jira_Issue__c issue = new Jira_Issue__c(Jira_Issue_Key__c = 'ABC-123');
        insert issue;

        // Simulation du corps JSON du webhook Jira
        String requestBody = JSON.serialize(new Map<String, Object>{
            'comment' => new Map<String, Object>{
                'body' => '<p>This is a <strong>test comment</strong>.</p>'
            },
            'issue' => new Map<String, Object>{
                'key' => 'ABC-123'
            }
        });

        // Simulation de la requête REST
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/jira/comment';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;

        RestResponse res = new RestResponse();
        RestContext.response = res;

        Test.startTest();
        JiraCommentWebhook.receiveWebhook();
        Test.stopTest();

    }

    @isTest
    static void testReceiveWebhook_MissingIssueKey() {
        String requestBody = JSON.serialize(new Map<String, Object>{
            'comment' => new Map<String, Object>{ 'body' => 'test' },
            'issue' => new Map<String, Object>{ 'key' => null }
        });

        RestContext.request = new RestRequest();
        RestContext.request.requestBody = Blob.valueOf(requestBody);
        RestContext.request.httpMethod = 'POST';

        Test.startTest();
        JiraCommentWebhook.receiveWebhook();
        Test.stopTest();
    }

    @isTest
    static void testReceiveWebhook_EmptyComment() {
        String requestBody = JSON.serialize(new Map<String, Object>{
            'comment' => new Map<String, Object>{ 'body' => '' },
            'issue' => new Map<String, Object>{ 'key' => 'ABC-999' }
        });

        RestContext.request = new RestRequest();
        RestContext.request.requestBody = Blob.valueOf(requestBody);
        RestContext.request.httpMethod = 'POST';

        Test.startTest();
        JiraCommentWebhook.receiveWebhook();
        Test.stopTest();
    }

    @isTest
    static void testReceiveWebhook_IssueNotFound() {
        String requestBody = JSON.serialize(new Map<String, Object>{
            'comment' => new Map<String, Object>{ 'body' => 'Commentaire sans issue correspondante' },
            'issue' => new Map<String, Object>{ 'key' => 'NOT-FOUND' }
        });

        RestContext.request = new RestRequest();
        RestContext.request.requestBody = Blob.valueOf(requestBody);
        RestContext.request.httpMethod = 'POST';

        Test.startTest();
        JiraCommentWebhook.receiveWebhook();
        Test.stopTest();
    }
}