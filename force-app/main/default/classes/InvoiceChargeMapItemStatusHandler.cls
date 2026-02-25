public without sharing class InvoiceChargeMapItemStatusHandler {

    private static final Set<String> SETTLED_STATUSES = new Set<String>{
        'Paid', 'Paid In Full', 'Rejected', 'Canceled'
    };

    public static void recalculateStatus(List<Invoice__c> newInvoices, Map<Id, Invoice__c> oldMap) {
        // 1. Collect Invoice IDs where Status changed
        Set<Id> changedInvoiceIds = new Set<Id>();
        for (Invoice__c inv : newInvoices) {
            if (inv.Status__c != oldMap.get(inv.Id).Status__c) {
                changedInvoiceIds.add(inv.Id);
            }
        }
        if (changedInvoiceIds.isEmpty()) {
            return;
        }

        // 2. Find all ChargeMapItem IDs linked to changed invoices
        Set<Id> chargeMapItemIds = new Set<Id>();
        for (InvoiceLineItem__c ili : [
            SELECT Charge_Map_Item__c
            FROM InvoiceLineItem__c
            WHERE Invoice__c IN :changedInvoiceIds
              AND Charge_Map_Item__c != null
        ]) {
            chargeMapItemIds.add(ili.Charge_Map_Item__c);
        }
        if (chargeMapItemIds.isEmpty()) {
            return;
        }

        // 3. For each ChargeMapItem, collect ALL related Invoice IDs
        Map<Id, Set<Id>> cmItemToInvoiceIds = new Map<Id, Set<Id>>();
        for (InvoiceLineItem__c ili : [
            SELECT Charge_Map_Item__c, Invoice__c
            FROM InvoiceLineItem__c
            WHERE Charge_Map_Item__c IN :chargeMapItemIds
              AND Invoice__c != null
        ]) {
            if (!cmItemToInvoiceIds.containsKey(ili.Charge_Map_Item__c)) {
                cmItemToInvoiceIds.put(ili.Charge_Map_Item__c, new Set<Id>());
            }
            cmItemToInvoiceIds.get(ili.Charge_Map_Item__c).add(ili.Invoice__c);
        }

        // 4. Query all referenced Invoices in one go
        Set<Id> allInvoiceIds = new Set<Id>();
        for (Set<Id> ids : cmItemToInvoiceIds.values()) {
            allInvoiceIds.addAll(ids);
        }
        Map<Id, Invoice__c> invoiceMap = new Map<Id, Invoice__c>([
            SELECT Id, Status__c
            FROM Invoice__c
            WHERE Id IN :allInvoiceIds
        ]);

        // 5. Determine new status for each ChargeMapItem
        List<ChargeMapItem__c> toUpdate = new List<ChargeMapItem__c>();
        for (Id cmItemId : cmItemToInvoiceIds.keySet()) {
            Boolean allSettled = true;
            for (Id invId : cmItemToInvoiceIds.get(cmItemId)) {
                Invoice__c inv = invoiceMap.get(invId);
                if (inv != null && !SETTLED_STATUSES.contains(inv.Status__c)) {
                    allSettled = false;
                    break;
                }
            }
            toUpdate.add(new ChargeMapItem__c(
                Id = cmItemId,
                Status__c = allSettled ? 'Paid' : 'Billed'
            ));
        }

        // 6. Single bulk DML
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}
