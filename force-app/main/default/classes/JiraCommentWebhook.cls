@RestResource(urlMapping='/jira/comment')
global without sharing class JiraCommentWebhook {

    @HttpPost
    global static void receiveWebhook() {
        RestRequest req = RestContext.request;
        String body = req.requestBody.toString();
        System.debug('📩 Webhook Jira reçu (brut) : ' + body);

        try {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);
            Map<String, Object> comment = (Map<String, Object>) payload.get('comment');
            Map<String, Object> issue = (Map<String, Object>) payload.get('issue');

            String commentBody = (String) comment.get('body');
            String issueKey = (String) issue.get('key');

            if (String.isBlank(issueKey)) {
                System.debug('❌ Clé d’issue Jira introuvable');
                return;
            }
            if (String.isBlank(commentBody)) {
                System.debug('❌ Commentaire vide');
                return;
            }

            // Le commentaire est déjà en HTML, on ne le nettoie pas
            String htmlContent = 'JIRA : ' + commentBody;

            // Recherche du Jira_Issue__c
            List<Jira_Issue__c> matches = [
                SELECT Id FROM Jira_Issue__c WHERE Jira_Issue_Key__c = :issueKey LIMIT 1
            ];

            if (!matches.isEmpty()) {
                Jira_Comment__e event = new Jira_Comment__e(
                    Comment__c     = htmlContent,
                    RecordId__c    = matches[0].Id,
                    IsRichText__c  = true
                );
                EventBus.publish(event);
                System.debug('✅ Platform Event publié avec IsRichText = true');
            } else {
                System.debug('❌ Aucun Jira_Issue__c trouvé pour la clé : ' + issueKey);
            }

        } catch (Exception e) {
            System.debug('❌ Erreur traitement webhook Jira : ' + e.getMessage());
        }
    }
}