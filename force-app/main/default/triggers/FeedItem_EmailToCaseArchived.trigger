trigger FeedItem_EmailToCaseArchived on FeedItem (after insert) {
    FeedItemEmailToCaseArchived.handleAfterInsert(Trigger.new);
}