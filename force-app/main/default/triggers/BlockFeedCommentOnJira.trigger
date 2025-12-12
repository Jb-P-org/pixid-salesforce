trigger BlockFeedCommentOnJira on FeedComment (before insert) {
    for (FeedComment fc : Trigger.new) {
        if (fc.ParentId != null && String.valueOf(fc.ParentId).startsWith('a0X')) { // Exemple : Jira_Issue__c
            fc.addError('Les commentaires sont désactivés sur ce type d’enregistrement.');
        }
    }
}