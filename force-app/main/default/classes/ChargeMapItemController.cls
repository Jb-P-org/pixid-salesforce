public without sharing class ChargeMapItemController {
    /** 
     * Récupère les items liés à la Charge Map, le statut de la Charge Map 
     * et la métadonnée des champs fournie au LWC.
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getChargeMapMetadata(Id chargeMapId) {
        if (chargeMapId == null) {
            throw new AuraHandledException('Charge Map Id manquant');
        }
        Map<String, Object> result = new Map<String, Object>();

        // 1. Statut et End Date de la Charge Map
        ChargeMap__c cm = [
            SELECT Status__c, EndDateRevRec__c
            FROM ChargeMap__c
            WHERE Id = :chargeMapId
            LIMIT 1
        ];
        Boolean isEditable = (cm.Status__c == 'Backlog');
        result.put('isEditable', isEditable);
        result.put('endDateRevRec', cm.EndDateRevRec__c != null ? String.valueOf(cm.EndDateRevRec__c) : null);

        // 2. Items liés
        List<ChargeMapItem__c> items = [
            SELECT Id, Name, Amount__c, BillingSchedule__c, Term__c,
                   StartDateRevRec__c, EndDateRevRec__c, End_date__c,
                   ProductNature__c, Sales_unit_price__c, DiscountNumber__c,
                   Quantity__c, CurrencyIsoCode, Status__c, Activated__c,
                   PO_Required__c, Spend__c, PercentageOfSpend__c,
                   ProratedAmount__c, NbOfMonthsProrated__c,
                   ProratedAmountPerMonth__c, PO_Reference__c, PO_Request_Date__c,
                   LineDescription__c, SalesOrderID__c
            FROM ChargeMapItem__c
            WHERE ChargeMap__c = :chargeMapId
        ];
        result.put('items', items);

        // 3. Métadonnée des champs
        Schema.DescribeSObjectResult dr = ChargeMapItem__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = dr.fields.getMap();
        // Liste des API names de champs à afficher
        List<String> fieldNames = new List<String>{
            'Name','Amount__c','BillingSchedule__c','Term__c','StartDateRevRec__c','EndDateRevRec__c','End_date__c',
            'ProductNature__c','Sales_unit_price__c','DiscountNumber__c','Quantity__c','CurrencyIsoCode',
            'Status__c','Activated__c','PO_Required__c',
            'Spend__c','PercentageOfSpend__c',
            'ProratedAmount__c','NbOfMonthsProrated__c','ProratedAmountPerMonth__c','PO_Reference__c','PO_Request_Date__c',
            'LineDescription__c','SalesOrderID__c'
        };
        List<Map<String,Object>> fieldsMeta = new List<Map<String,Object>>();
        for (String fn : fieldNames) {
            Schema.DescribeFieldResult fd = fieldMap.get(fn).getDescribe();
            Map<String,Object> fm = new Map<String,Object>{
                'apiName'    => fn,
                'label'      => fd.getLabel(),
                'type'       => String.valueOf(fd.getType()).toLowerCase(),
                'updateable' => fd.isUpdateable(),
                'calculated' => fd.isCalculated()
            };
            if (fd.getType() == Schema.DisplayType.Picklist) {
                List<Map<String,String>> opts = new List<Map<String,String>>();
                for (Schema.PicklistEntry pe : fd.getPicklistValues()) {
                    if (pe.isActive()) {
                        opts.add(new Map<String,String>{
                            'label' => pe.getLabel(),
                            'value' => pe.getValue()
                        });
                    }
                }
                fm.put('picklistValues', opts);
            }
            fieldsMeta.add(fm);
        }
        result.put('metadata', new Map<String,Object>{ 'fields' => fieldsMeta });

        return result;
    }

    /**
     * Met à jour les items modifiés
     */
    @AuraEnabled
    public static void updateChargeMapItems(List<ChargeMapItem__c> updatedItems) {
        if (updatedItems != null && !updatedItems.isEmpty()) {
            update updatedItems;
        }
    }

    /**
     * Crée de nouveaux ChargeMapItem__c.
     * Vérifie que la Charge Map est en statut Backlog avant la création.
     */
    @AuraEnabled
    public static List<ChargeMapItem__c> createChargeMapItems(Id chargeMapId, List<ChargeMapItem__c> newItems) {
        if (chargeMapId == null) {
            throw new AuraHandledException('Charge Map Id manquant');
        }
        if (newItems == null || newItems.isEmpty()) {
            throw new AuraHandledException('Aucun item à créer');
        }

        ChargeMap__c chargeMap = [
            SELECT Status__c FROM ChargeMap__c WHERE Id = :chargeMapId LIMIT 1
        ];
        if (chargeMap.Status__c != 'Backlog') {
            throw new AuraHandledException(
                'Impossible de créer des items : la Charge Map n\'est pas en statut Backlog'
            );
        }

        // Collect Product Ids to query their Names
        Set<Id> productIds = new Set<Id>();
        for (ChargeMapItem__c item : newItems) {
            if (item.Product__c != null) {
                productIds.add(item.Product__c);
            }
        }

        Map<Id, Product2> productMap = new Map<Id, Product2>();
        if (!productIds.isEmpty()) {
            productMap = new Map<Id, Product2>([
                SELECT Id, Name FROM Product2 WHERE Id IN :productIds
            ]);
        }

        for (ChargeMapItem__c item : newItems) {
            item.ChargeMap__c = chargeMapId;
            // Set the item Name to the Product Name
            if (item.Product__c != null && productMap.containsKey(item.Product__c)) {
                item.Name = productMap.get(item.Product__c).Name;
            }
        }

        insert newItems;
        return newItems;
    }

    /**
     * Supprime des ChargeMapItem__c par leurs Ids.
     * Vérifie que la Charge Map est en statut Backlog avant la suppression.
     */
    @AuraEnabled
    public static void deleteChargeMapItems(Id chargeMapId, List<Id> itemIds) {
        if (chargeMapId == null) {
            throw new AuraHandledException('Charge Map Id manquant');
        }
        if (itemIds == null || itemIds.isEmpty()) {
            throw new AuraHandledException('Aucun item à supprimer');
        }

        ChargeMap__c chargeMap = [
            SELECT Status__c FROM ChargeMap__c WHERE Id = :chargeMapId LIMIT 1
        ];
        if (chargeMap.Status__c != 'Backlog') {
            throw new AuraHandledException(
                'Impossible de supprimer des items : la Charge Map n\'est pas en statut Backlog'
            );
        }

        List<ChargeMapItem__c> toDelete = [
            SELECT Id FROM ChargeMapItem__c
            WHERE Id IN :itemIds AND ChargeMap__c = :chargeMapId
        ];

        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
    }
}