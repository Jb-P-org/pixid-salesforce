trigger FeedCommentToCase on FeedComment (after insert) {
    Set<Id> feedItemIds = new Set<Id>();
    Set<Id> userIds = new Set<Id>();

    for (FeedComment fc : Trigger.new) {
        if (fc.FeedItemId != null) {
            feedItemIds.add(fc.FeedItemId);
        }
        if (fc.CreatedById != null) {
            userIds.add(fc.CreatedById);
        }
    }

    Map<Id, FeedItem> feedItems = new Map<Id, FeedItem>(
        [SELECT Id, ParentId FROM FeedItem WHERE Id IN :feedItemIds]
    );

    Map<Id, User> users = new Map<Id, User>(
        [SELECT Id, Profile.Name FROM User WHERE Id IN :userIds]
    );

    Map<Id, FeedComment> latestComments = new Map<Id, FeedComment>();

    for (FeedComment fc : Trigger.new) {
        User u = users.get(fc.CreatedById);
        if (u == null || !u.Profile.Name.toLowerCase().contains('community')) {
            continue; // ignorer si pas Community user
        }

        FeedItem parentItem = feedItems.get(fc.FeedItemId);
        if (parentItem != null && parentItem.ParentId != null && String.valueOf(parentItem.ParentId).startsWith('500')) {
            latestComments.put(parentItem.ParentId, fc);
        }
    }

    List<Case> casesToUpdate = new List<Case>();
    for (Id caseId : latestComments.keySet()) {
        FeedComment fc = latestComments.get(caseId);
        casesToUpdate.add(new Case(
            Id = caseId,
            Customer_Last_Comment__c = fc.CommentBody,
            Customer_Last_Comment_Date_Time__c = System.now()
        ));
    }

    if (!casesToUpdate.isEmpty()) {
        update casesToUpdate;
    }
}