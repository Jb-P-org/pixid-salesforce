trigger Invoice on Invoice__c (after update) {
    InvoiceChargeMapItemStatusHandler.recalculateStatus(Trigger.new, Trigger.oldMap);
}