trigger JiraIssueWebhook on Jira_Issue__c (after insert) {
    // Skip in test context to avoid governor limits
    if (Test.isRunningTest()) {
        return;
    }

    for (Jira_Issue__c issue : Trigger.new) {
        // Schedule job to run 30 seconds from now to allow PublicFiles__c to be populated
        Datetime scheduledTime = System.now().addSeconds(30);
        String cronExp = scheduledTime.format('ss mm HH dd MM ? yyyy');
        String jobName = 'CeligoSend_' + issue.Id + '_' + System.now().getTime();

        System.schedule(jobName, cronExp, new SendToCeligoScheduler(issue.Id));
    }
}