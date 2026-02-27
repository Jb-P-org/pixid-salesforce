@IsTest
private class InvoiceChargeMapItemStatusHandlerTest {

    @TestSetup
    static void setup() {
        ChargeMap__c cm = new ChargeMap__c();
        insert cm;

        ChargeMapItem__c cmItem1 = new ChargeMapItem__c(
            ChargeMap__c = cm.Id,
            Status__c = 'Billable'
        );
        ChargeMapItem__c cmItem2 = new ChargeMapItem__c(
            ChargeMap__c = cm.Id,
            Status__c = 'Billable'
        );
        insert new List<ChargeMapItem__c>{ cmItem1, cmItem2 };

        Invoice__c inv1 = new Invoice__c(Status__c = 'Open');
        Invoice__c inv2 = new Invoice__c(Status__c = 'Open');
        insert new List<Invoice__c>{ inv1, inv2 };

        insert new List<InvoiceLineItem__c>{
            new InvoiceLineItem__c(Invoice__c = inv1.Id, Charge_Map_Item__c = cmItem1.Id),
            new InvoiceLineItem__c(Invoice__c = inv2.Id, Charge_Map_Item__c = cmItem1.Id),
            new InvoiceLineItem__c(Invoice__c = inv1.Id, Charge_Map_Item__c = cmItem2.Id)
        };
    }

    @IsTest
    static void testAllInvoicesPaid_SetsChargeMapItemToPaid() {
        List<Invoice__c> invoices = [SELECT Id, Status__c FROM Invoice__c];
        for (Invoice__c inv : invoices) {
            inv.Status__c = 'Paid';
        }

        Test.startTest();
        update invoices;
        Test.stopTest();

        List<ChargeMapItem__c> cmItems = [SELECT Id, Status__c FROM ChargeMapItem__c];
        for (ChargeMapItem__c item : cmItems) {
            System.assertEquals('Paid', item.Status__c,
                'ChargeMapItem should be Paid when all invoices are Paid');
        }
    }

    @IsTest
    static void testPartialPaid_SetsChargeMapItemToBilled() {
        List<Invoice__c> invoices = [SELECT Id, Status__c FROM Invoice__c ORDER BY CreatedDate];
        // Only pay the first invoice
        invoices[0].Status__c = 'Paid';

        Test.startTest();
        update new List<Invoice__c>{ invoices[0] };
        Test.stopTest();

        // cmItem1 is linked to both invoices -> one still Open -> Billed
        ChargeMapItem__c cmItem1 = [
            SELECT Status__c FROM ChargeMapItem__c
            WHERE Id IN (SELECT Charge_Map_Item__c FROM InvoiceLineItem__c WHERE Invoice__c = :invoices[1].Id)
            LIMIT 1
        ];
        System.assertEquals('Billed', cmItem1.Status__c,
            'ChargeMapItem should be Billed when not all invoices are paid');
    }

    @IsTest
    static void testRejectedAndCanceled_CountAsSettled() {
        List<Invoice__c> invoices = [SELECT Id, Status__c FROM Invoice__c ORDER BY CreatedDate];
        invoices[0].Status__c = 'Paid In Full';
        invoices[1].Status__c = 'Canceled';

        Test.startTest();
        update invoices;
        Test.stopTest();

        List<ChargeMapItem__c> cmItems = [SELECT Id, Status__c FROM ChargeMapItem__c];
        for (ChargeMapItem__c item : cmItems) {
            System.assertEquals('Paid', item.Status__c,
                'ChargeMapItem should be Paid when all invoices are Paid In Full/Canceled');
        }
    }

    @IsTest
    static void testNoStatusChange_NoUpdate() {
        List<Invoice__c> invoices = [SELECT Id, Status__c FROM Invoice__c];
        // Update a different field (no Status change)
        Test.startTest();
        update invoices;
        Test.stopTest();

        List<ChargeMapItem__c> cmItems = [SELECT Id, Status__c FROM ChargeMapItem__c];
        for (ChargeMapItem__c item : cmItems) {
            System.assertEquals('Billable', item.Status__c,
                'ChargeMapItem should remain unchanged when Invoice Status did not change');
        }
    }
}