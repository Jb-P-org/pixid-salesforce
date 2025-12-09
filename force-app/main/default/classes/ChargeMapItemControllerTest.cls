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
}