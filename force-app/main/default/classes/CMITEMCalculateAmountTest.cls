@isTest
private class CMITEMCalculateAmountTest {

    @testSetup
    static void setup() {
        ChargeMap__c chargeMap = new ChargeMap__c(
            Name = 'Test Charge Map',
            Status__c = 'Backlog'
        );
        insert chargeMap;
    }

    @isTest
    static void testInsertWithQuantityAndPrice() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Test.startTest();
        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Item 1',
            ChargeMap__c = chargeMap.Id,
            Quantity__c = 10,
            Sales_unit_price__c = 50.00
        );
        insert item;
        Test.stopTest();

        ChargeMapItem__c inserted = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(500.00, inserted.Amount__c, 'Amount should be Quantity * Price');
    }

    @isTest
    static void testInsertWithDiscount() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Test.startTest();
        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Item with Discount',
            ChargeMap__c = chargeMap.Id,
            Quantity__c = 10,
            Sales_unit_price__c = 100.00,
            DiscountNumber__c = 20
        );
        insert item;
        Test.stopTest();

        ChargeMapItem__c inserted = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(800.00, inserted.Amount__c, 'Amount should be (Quantity * Price) * (1 - Discount%)');
    }

    @isTest
    static void testInsertWithoutQuantity() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Test.startTest();
        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Item without Quantity',
            ChargeMap__c = chargeMap.Id,
            Sales_unit_price__c = 100.00
        );
        insert item;
        Test.stopTest();

        ChargeMapItem__c inserted = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(null, inserted.Amount__c, 'Amount should be null when Quantity is null');
    }

    @isTest
    static void testInsertWithoutPrice() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Test.startTest();
        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Item without Price',
            ChargeMap__c = chargeMap.Id,
            Quantity__c = 10
        );
        insert item;
        Test.stopTest();

        ChargeMapItem__c inserted = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(null, inserted.Amount__c, 'Amount should be null when Price is null');
    }

    @isTest
    static void testUpdateQuantity() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Item for Update',
            ChargeMap__c = chargeMap.Id,
            Quantity__c = 5,
            Sales_unit_price__c = 20.00
        );
        insert item;

        Test.startTest();
        item.Quantity__c = 10;
        update item;
        Test.stopTest();

        ChargeMapItem__c updated = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(200.00, updated.Amount__c, 'Amount should be recalculated on quantity update');
    }

    @isTest
    static void testUpdatePrice() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Item for Price Update',
            ChargeMap__c = chargeMap.Id,
            Quantity__c = 10,
            Sales_unit_price__c = 50.00
        );
        insert item;

        Test.startTest();
        item.Sales_unit_price__c = 75.00;
        update item;
        Test.stopTest();

        ChargeMapItem__c updated = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(750.00, updated.Amount__c, 'Amount should be recalculated on price update');
    }

    @isTest
    static void testUpdateDiscount() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Item for Discount Update',
            ChargeMap__c = chargeMap.Id,
            Quantity__c = 10,
            Sales_unit_price__c = 100.00,
            DiscountNumber__c = 10
        );
        insert item;

        Test.startTest();
        item.DiscountNumber__c = 25;
        update item;
        Test.stopTest();

        ChargeMapItem__c updated = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(750.00, updated.Amount__c, 'Amount should be recalculated with new discount');
    }

    @isTest
    static void testNegativeAmountHandling() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Test.startTest();
        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Negative Amount',
            ChargeMap__c = chargeMap.Id,
            Quantity__c = 10,
            Sales_unit_price__c = 100.00,
            DiscountNumber__c = 150
        );
        insert item;
        Test.stopTest();

        ChargeMapItem__c inserted = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(0, inserted.Amount__c, 'Negative amount should be set to 0');
    }

    @isTest
    static void testStartDateRevRecUpdate() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Date startDate = Date.newInstance(2024, 1, 15);
        Date endDate = Date.newInstance(2023, 12, 31);

        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Date Update',
            ChargeMap__c = chargeMap.Id,
            Quantity__c = 1,
            Sales_unit_price__c = 100.00,
            StartDateRevRec__c = startDate,
            End_date__c = endDate
        );
        insert item;

        Test.startTest();
        item.StartDateRevRec__c = Date.newInstance(2025, 6, 1);
        update item;
        Test.stopTest();

        ChargeMapItem__c updated = [SELECT End_date__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(2025, updated.End_date__c.year(), 'End date year should be updated to match start date year');
    }

    @isTest
    static void testUpdateUnrelatedField() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        ChargeMapItem__c item = new ChargeMapItem__c(
            Name = 'Test Unrelated Update',
            ChargeMap__c = chargeMap.Id,
            Quantity__c = 10,
            Sales_unit_price__c = 50.00,
            BillingSchedule__c = 'Monthly'
        );
        insert item;

        Decimal originalAmount = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id].Amount__c;

        Test.startTest();
        item.BillingSchedule__c = 'Quarterly';
        update item;
        Test.stopTest();

        ChargeMapItem__c updated = [SELECT Amount__c FROM ChargeMapItem__c WHERE Id = :item.Id];
        System.assertEquals(originalAmount, updated.Amount__c, 'Amount should not change when unrelated field is updated');
    }

    @isTest
    static void testBulkInsert() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        List<ChargeMapItem__c> items = new List<ChargeMapItem__c>();
        for (Integer i = 1; i <= 200; i++) {
            items.add(new ChargeMapItem__c(
                Name = 'Bulk Item ' + i,
                ChargeMap__c = chargeMap.Id,
                Quantity__c = i,
                Sales_unit_price__c = 10.00
            ));
        }

        Test.startTest();
        insert items;
        Test.stopTest();

        List<ChargeMapItem__c> inserted = [SELECT Amount__c, Quantity__c FROM ChargeMapItem__c WHERE ChargeMap__c = :chargeMap.Id];
        System.assertEquals(200, inserted.size());

        for (ChargeMapItem__c item : inserted) {
            System.assertEquals(item.Quantity__c * 10.00, item.Amount__c, 'All amounts should be calculated correctly');
        }
    }
}