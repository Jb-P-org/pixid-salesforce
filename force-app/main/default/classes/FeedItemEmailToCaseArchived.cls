public class FeedItemEmailToCaseArchived {
    
    public static void handleAfterInsert(List<FeedItem> newFeedItems) {
        
        // Step 1: Filter FeedItems that are EmailMessageEvent on Cases
        Set<Id> caseIds = new Set<Id>();
        
        for (FeedItem fi : newFeedItems) {
            if (fi.ParentId != null 
                && String.valueOf(fi.ParentId).startsWith('500') 
                && fi.Type == 'EmailMessageEvent') {
                
                caseIds.add(fi.ParentId);
            }
        }
        
        if (caseIds.isEmpty()) {
            return;
        }
        
        // Step 2: Query parent Cases and check conditions
        List<Case> casesToProcess = [
            SELECT Id, CaseNumber, Status, Archived__c, SuppliedEmail
            FROM Case 
            WHERE Id IN :caseIds
            AND Status = 'Closed'
            AND Archived__c = true
            AND SuppliedEmail != null
        ];
        
        if (casesToProcess.isEmpty()) {
            return;
        }
        
        // Step 3: Call Flow for each case to send email
        for (Case c : casesToProcess) {
            try {
                // Call the autolaunched Flow with caseId as input
                Map<String, Object> flowInputs = new Map<String, Object>();
                flowInputs.put('caseId', c.Id);
                
                Flow.Interview.Send_Email_Archived_Case flow = 
                    new Flow.Interview.Send_Email_Archived_Case(flowInputs);
                flow.start();
                
                System.debug('✅ Flow executed for Case: ' + c.CaseNumber);
                
            } catch (Exception e) {
                // Log error but continue processing other cases
                System.debug(LoggingLevel.ERROR, 
                    'Error calling flow for Case ' + c.Id + ': ' + e.getMessage());
            }
        }
    }
}