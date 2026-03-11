@isTest
private class ChargeMapItemControllerTest {

    @testSetup
    static void setup() {
        // Create Charge Map
        ChargeMap__c chargeMap = new ChargeMap__c(
            Name = 'Test Charge Map',
            Status__c = 'Backlog'
        );
        insert chargeMap;

        // Create Charge Map Items
        List<ChargeMapItem__c> items = new List<ChargeMapItem__c>();
        for (Integer i = 0; i < 3; i++) {
            items.add(new ChargeMapItem__c(
                Name = 'Test Item ' + i,
                ChargeMap__c = chargeMap.Id,
                Quantity__c = i + 1,
                Sales_unit_price__c = 100.00,
                StartDateRevRec__c = Date.today()
            ));
        }
        insert items;
    }

    @isTest
    static void testGetChargeMapMetadata() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = ChargeMapItemController.getChargeMapMetadata(chargeMap.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.get('isEditable'), 'Should be editable when status is Backlog');

        List<ChargeMapItem__c> items = (List<ChargeMapItem__c>) result.get('items');
        System.assertEquals(3, items.size(), 'Should return 3 items');

        Map<String, Object> metadata = (Map<String, Object>) result.get('metadata');
        System.assertNotEquals(null, metadata);

        List<Map<String, Object>> fields = (List<Map<String, Object>>) metadata.get('fields');
        System.assert(fields.size() > 0, 'Should return field metadata');
    }

    @isTest
    static void testGetChargeMapMetadataNotEditable() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        // Query valid non-Backlog status from picklist
        Schema.DescribeFieldResult statusField = ChargeMap__c.Status__c.getDescribe();
        List<Schema.PicklistEntry> statusValues = statusField.getPicklistValues();
        String validStatus = 'Backlog';
        for (Schema.PicklistEntry entry : statusValues) {
            if (entry.getValue() != 'Backlog') {
                validStatus = entry.getValue();
                break;
            }
        }

        chargeMap.Status__c = validStatus;
        update chargeMap;

        Test.startTest();
        Map<String, Object> result = ChargeMapItemController.getChargeMapMetadata(chargeMap.Id);
        Test.stopTest();

        System.assertEquals(false, result.get('isEditable'), 'Should not be editable when status is not Backlog');
    }

    @isTest
    static void testGetChargeMapMetadataNullId() {
        Test.startTest();
        try {
            ChargeMapItemController.getChargeMapMetadata(null);
            System.assert(false, 'Should throw exception for null Id');
        } catch (Exception e) {
            // Accept any exception for null ID - may be AuraHandledException or other
            System.assert(true, 'Exception thrown for null Id as expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateChargeMapItems() {
        List<ChargeMapItem__c> items = [SELECT Id, Quantity__c, Sales_unit_price__c FROM ChargeMapItem__c];

        for (ChargeMapItem__c item : items) {
            item.Quantity__c = 20;
        }

        Test.startTest();
        ChargeMapItemController.updateChargeMapItems(items);
        Test.stopTest();

        List<ChargeMapItem__c> updatedItems = [SELECT Id, Quantity__c FROM ChargeMapItem__c];
        for (ChargeMapItem__c item : updatedItems) {
            System.assertEquals(20, item.Quantity__c, 'Quantity should be updated');
        }
    }

    @isTest
    static void testUpdateChargeMapItemsEmpty() {
        Test.startTest();
        ChargeMapItemController.updateChargeMapItems(new List<ChargeMapItem__c>());
        Test.stopTest();

        // Should handle empty list without errors
        System.assert(true, 'Should handle empty list gracefully');
    }

    @isTest
    static void testUpdateChargeMapItemsNull() {
        Test.startTest();
        ChargeMapItemController.updateChargeMapItems(null);
        Test.stopTest();

        // Should handle null without errors
        System.assert(true, 'Should handle null gracefully');
    }

    @isTest
    static void testFieldMetadataIncludesPicklists() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = ChargeMapItemController.getChargeMapMetadata(chargeMap.Id);
        Test.stopTest();

        Map<String, Object> metadata = (Map<String, Object>) result.get('metadata');
        List<Map<String, Object>> fields = (List<Map<String, Object>>) metadata.get('fields');

        Boolean hasPicklist = false;
        for (Map<String, Object> field : fields) {
            if (field.get('type') == 'picklist' && field.containsKey('picklistValues')) {
                hasPicklist = true;
                break;
            }
        }

        System.assert(hasPicklist, 'Should include picklist metadata');
    }

    // ===== createChargeMapItems tests =====

    @isTest
    static void testCreateChargeMapItems() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        List<ChargeMapItem__c> newItems = new List<ChargeMapItem__c>{
            new ChargeMapItem__c(
                Quantity__c = 5,
                Sales_unit_price__c = 200.00,
                StartDateRevRec__c = Date.today()
            ),
            new ChargeMapItem__c(
                Quantity__c = 10,
                Sales_unit_price__c = 50.00,
                DiscountNumber__c = 10,
                StartDateRevRec__c = Date.today().addMonths(1)
            )
        };

        Test.startTest();
        List<ChargeMapItem__c> created = ChargeMapItemController.createChargeMapItems(
            chargeMap.Id, newItems
        );
        Test.stopTest();

        System.assertEquals(2, created.size(), 'Should create 2 items');
        List<ChargeMapItem__c> items = [
            SELECT Id, ChargeMap__c, Amount__c
            FROM ChargeMapItem__c
            WHERE Id IN :created
        ];
        for (ChargeMapItem__c item : items) {
            System.assertEquals(chargeMap.Id, item.ChargeMap__c,
                'Items should belong to the specified ChargeMap');
        }
    }

    @isTest
    static void testCreateChargeMapItemsNotBacklog() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Schema.DescribeFieldResult statusField = ChargeMap__c.Status__c.getDescribe();
        String nonBacklogStatus = 'Backlog';
        for (Schema.PicklistEntry entry : statusField.getPicklistValues()) {
            if (entry.getValue() != 'Backlog') {
                nonBacklogStatus = entry.getValue();
                break;
            }
        }
        chargeMap.Status__c = nonBacklogStatus;
        update chargeMap;

        List<ChargeMapItem__c> newItems = new List<ChargeMapItem__c>{
            new ChargeMapItem__c(Quantity__c = 1, Sales_unit_price__c = 100.00)
        };

        Test.startTest();
        try {
            ChargeMapItemController.createChargeMapItems(chargeMap.Id, newItems);
            System.assert(false, 'Should throw exception when not in Backlog status');
        } catch (Exception e) {
            System.assert(true, 'Exception thrown as expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateChargeMapItemsNullId() {
        Test.startTest();
        try {
            ChargeMapItemController.createChargeMapItems(null, new List<ChargeMapItem__c>());
            System.assert(false, 'Should throw exception for null Id');
        } catch (Exception e) {
            System.assert(true, 'Exception thrown as expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateChargeMapItemsEmptyList() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Test.startTest();
        try {
            ChargeMapItemController.createChargeMapItems(chargeMap.Id, new List<ChargeMapItem__c>());
            System.assert(false, 'Should throw exception for empty list');
        } catch (Exception e) {
            System.assert(true, 'Exception thrown as expected');
        }
        Test.stopTest();
    }

    // ===== deleteChargeMapItems tests =====

    @isTest
    static void testDeleteChargeMapItems() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];
        List<ChargeMapItem__c> items = [SELECT Id FROM ChargeMapItem__c];
        List<Id> itemIds = new List<Id>();
        for (ChargeMapItem__c item : items) {
            itemIds.add(item.Id);
        }

        Test.startTest();
        ChargeMapItemController.deleteChargeMapItems(chargeMap.Id, itemIds);
        Test.stopTest();

        Integer countAfter = [SELECT COUNT() FROM ChargeMapItem__c];
        System.assertEquals(0, countAfter, 'All items should be deleted');
    }

    @isTest
    static void testDeleteChargeMapItemsNotBacklog() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Schema.DescribeFieldResult statusField = ChargeMap__c.Status__c.getDescribe();
        String nonBacklogStatus = 'Backlog';
        for (Schema.PicklistEntry entry : statusField.getPicklistValues()) {
            if (entry.getValue() != 'Backlog') {
                nonBacklogStatus = entry.getValue();
                break;
            }
        }
        chargeMap.Status__c = nonBacklogStatus;
        update chargeMap;

        List<ChargeMapItem__c> items = [SELECT Id FROM ChargeMapItem__c];
        List<Id> itemIds = new List<Id>();
        for (ChargeMapItem__c item : items) {
            itemIds.add(item.Id);
        }

        Test.startTest();
        try {
            ChargeMapItemController.deleteChargeMapItems(chargeMap.Id, itemIds);
            System.assert(false, 'Should throw exception when not in Backlog status');
        } catch (Exception e) {
            System.assert(true, 'Exception thrown as expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteChargeMapItemsNullId() {
        Test.startTest();
        try {
            ChargeMapItemController.deleteChargeMapItems(null, new List<Id>());
            System.assert(false, 'Should throw exception for null Id');
        } catch (Exception e) {
            System.assert(true, 'Exception thrown as expected');
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteChargeMapItemsEmptyList() {
        ChargeMap__c chargeMap = [SELECT Id FROM ChargeMap__c LIMIT 1];

        Test.startTest();
        try {
            ChargeMapItemController.deleteChargeMapItems(chargeMap.Id, new List<Id>());
            System.assert(false, 'Should throw exception for empty list');
        } catch (Exception e) {
            System.assert(true, 'Exception thrown as expected');
        }
        Test.stopTest();
    }
}