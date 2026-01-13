public class CeligoWebhookSender {

    @future(callout=true)
    public static void sendToCeligoAsync(Id jiraIssueId) {
        sendJiraIssueToCeligo(jiraIssueId);
    }

    public static void sendJiraIssueToCeligo(Id jiraIssueId) {
        Jira_Issue__c issue = [
            SELECT Id, Name, Issue_Description__c, PublicFiles__c,
                   Issue_Type__c, Priority__c, Status__c, Jira_Project__c,
                   Created_Date__c, Resolved_Date__c, Reporter__c, Assignee__c,
                   OwnerId, Module__c, Domain__c, IssueScope__c, ClientRequest__c,
                   ActionsRequested__c, CurrentBehavior__c, ExpectedBehavior__c,
                   Context__c, Resolution_Summary__c, Comments__c, LastModifiedById,
                   Linked_Case__r.Id, Linked_Case__r.Subject, Linked_Case__r.CaseNumber,
                   Linked_Case__r.Contact.Email, Linked_Case__r.Contact.Name,
                   Linked_Case__r.Account.Name, Linked_Case__r.Owner.Name,
                   Linked_Case__r.CreatedDate
            FROM Jira_Issue__c
            WHERE Id = :jiraIssueId
            LIMIT 1
        ];

        Map<String, Object> attributes = new Map<String, Object>{
            'type' => 'Jira_Issue__c',
            'url' => '/services/data/v61.0/sobjects/Jira_Issue__c/' + issue.Id
        };

        Map<String, Object> record = new Map<String, Object>{
            'attributes' => attributes,
            'Id' => issue.Id,
            'Name' => issue.Name,
            'Issue_Description__c' => issue.Issue_Description__c,
            'PublicFiles__c' => issue.PublicFiles__c,
            'Issue_Type__c' => issue.Issue_Type__c,
            'Priority__c' => issue.Priority__c,
            'Status__c' => issue.Status__c,
            'Jira_Project__c' => issue.Jira_Project__c,
            'Created_Date__c' => issue.Created_Date__c,
            'Resolved_Date__c' => issue.Resolved_Date__c,
            'Reporter__c' => issue.Reporter__c,
            'Assignee__c' => issue.Assignee__c,
            'OwnerId' => issue.OwnerId,
            'Module__c' => issue.Module__c,
            'Domain__c' => issue.Domain__c,
            'IssueScope__c' => issue.IssueScope__c,
            'ClientRequest__c' => issue.ClientRequest__c,
            'ActionsRequested__c' => issue.ActionsRequested__c,
            'CurrentBehavior__c' => issue.CurrentBehavior__c,
            'ExpectedBehavior__c' => issue.ExpectedBehavior__c,
            'Context__c' => issue.Context__c,
            'Resolution_Summary__c' => issue.Resolution_Summary__c,
            'Comments__c' => issue.Comments__c,
            'LastModifiedById' => issue.LastModifiedById,
            'Linked_Case__r' => issue.Linked_Case__r != null ? new Map<String, Object>{
                'attributes' => new Map<String, Object>{
                    'type' => 'Case',
                    'url' => '/services/data/v61.0/sobjects/Case/' + issue.Linked_Case__r.Id
                },
                'Id' => issue.Linked_Case__r.Id,
                'CaseNumber' => issue.Linked_Case__r.CaseNumber,
                'Subject' => issue.Linked_Case__r.Subject,
                'CreatedDate' => issue.Linked_Case__r.CreatedDate,
                'Contact' => issue.Linked_Case__r.Contact != null ? new Map<String, Object>{
                    'Email' => issue.Linked_Case__r.Contact.Email,
                    'Name' => issue.Linked_Case__r.Contact.Name
                } : null,
                'Account' => issue.Linked_Case__r.Account != null ? new Map<String, Object>{
                    'Name' => issue.Linked_Case__r.Account.Name
                } : null,
                'Owner' => issue.Linked_Case__r.Owner != null ? new Map<String, Object>{
                    'attributes' => new Map<String, Object>{
                        'type' => 'Name',
                        'url' => '/services/data/v61.0/sobjects/' + issue.Linked_Case__r.OwnerId
                    },
                    'Name' => issue.Linked_Case__r.Owner.Name
                } : null
            } : null
        };

        // 💬 LOG EXPLICITE DE LA VALEUR DU CHAMP PROJET
        System.debug('🎯 Jira_Project__c envoyé à Celigo : ' + issue.Jira_Project__c);

        Map<String, Object> payload = new Map<String, Object>{'record' => record};

        // Retrieve credentials from Custom Metadata Type
        Celigo_Settings__mdt settings = Celigo_Settings__mdt.getInstance('Default');
        if (settings == null) {
            System.debug('Error: Celigo_Settings__mdt.Default record not found');
            return;
        }

        String basicAuth = 'Basic ' + EncodingUtil.base64Encode(
            Blob.valueOf(settings.Username__c + ':' + settings.Password__c)
        );

        // Sérialisation puis décodage des entités HTML
        String jsonBody = JSON.serialize(record);
        jsonBody = decodeHtmlEntities(jsonBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.Endpoint_URL__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', basicAuth);
        req.setBody(jsonBody);

        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('Webhook status: ' + res.getStatus());
            System.debug('Response body: ' + res.getBody());
        } catch (Exception e) {
            System.debug('Callout failed: ' + e.getMessage());
        }
    }

    /**
     * Décode les entités HTML courantes pour un affichage correct dans Jira
     */
    private static String decodeHtmlEntities(String input) {
        if (String.isBlank(input)) {
            return input;
        }
        
        return input
            .replace('\\u0027', '\'');   // Apostrophe encodée par JSON.serialize()
    }
}