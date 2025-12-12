trigger FeedItem_PreventOnClosedCase on FeedItem (before insert) {
    Set<Id> caseIds = new Set<Id>();

    for (FeedItem fi : Trigger.new) {
        if (fi.ParentId != null && fi.ParentId.getSObjectType() == Case.SObjectType) {
            caseIds.add(fi.ParentId);
        }
    }

    if (caseIds.isEmpty()) return;

    Map<Id, Case> caseMap = new Map<Id, Case>(
        [SELECT Id, Status, Archived__c FROM Case WHERE Id IN :caseIds]
    );

    for (FeedItem fi : Trigger.new) {
        if (caseMap.containsKey(fi.ParentId) 
            && caseMap.get(fi.ParentId).Status == 'Closed'
            && caseMap.get(fi.ParentId).Archived__c == true) {
            
            // Exception : Les EmailMessageEvent doivent passer pour être traités par le trigger after insert
            // qui enverra un email au client et supprimera le FeedItem
            if (fi.Type == 'EmailMessageEvent') {
                continue; // Laisse passer
            }
            
            // Bloque tous les autres types (TextPost, ContentPost, etc.) = commentaires manuels
            fi.addError('Ce ticket est clos, vous ne pouvez plus le commenter. Merci de réouvrir un nouveau ticket auprès du support.');
        }
    }
}