@RestResource(urlMapping='/jiraWebhookListener/*')
global with sharing class UpdateJiraIssue {

    @HttpPost
    global static void handleIncomingJiraEvent() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();

        // Parser le JSON
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);

        // Exemple d’accès au ticket et champ custom
        Map<String, Object> issue = (Map<String, Object>) payload.get('issue');
        String jiraKey = (String) issue.get('key');
        Map<String, Object> fields = (Map<String, Object>) issue.get('fields');
        String salesforceId = (String) fields.get('customfield_10182');

        // Mettre à jour le record Salesforce s’il existe
        if (salesforceId != null) {
            List<Jira_Issue__c> recordsToUpdate = [
                SELECT Id, Jira_Issue_Key__c FROM Jira_Issue__c WHERE Id = :salesforceId
            ];

            if (!recordsToUpdate.isEmpty()) {
                Jira_Issue__c rec = recordsToUpdate[0];
                rec.Jira_Issue_Key__c = jiraKey; // ou autre champ à mettre à jour

                update rec;
            }
        }
    }
}