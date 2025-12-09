public class SendToCeligoScheduler implements Schedulable {

    private Id recordId;

    public SendToCeligoScheduler(Id recordId) {
        this.recordId = recordId;
    }

    // Schedulable execute - sends to Celigo after 30-second delay
    public void execute(SchedulableContext context) {
        // Toujours envoyer, même si PublicFiles__c est vide
        CeligoWebhookSender.sendToCeligoAsync(recordId);
    }
}