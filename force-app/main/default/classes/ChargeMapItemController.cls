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

        // 1. Statut de la Charge Map
        String status = [
            SELECT Status__c 
            FROM ChargeMap__c 
            WHERE Id = :chargeMapId 
            LIMIT 1
        ].Status__c;
        Boolean isEditable = (status == 'Backlog');
        result.put('isEditable', isEditable);

        // 2. Items liés
        List<ChargeMapItem__c> items = [
            SELECT Id, Name, Amount__c, BillingSchedule__c, Term__c,
                   StartDateRevRec__c, EndDateRevRec__c, ProductNature__c,
                   Quantity__c, CurrencyIsoCode, Status__c, Spend__c,
                   PercentageOfSpend__c, ProratedAmount__c, NbOfMonthsProrated__c,
                   ProratedAmountPerMonth__c, PO_Reference__c, PO_Request_Date__c
            FROM ChargeMapItem__c
            WHERE ChargeMap__c = :chargeMapId
        ];
        result.put('items', items);

        // 3. Métadonnée des champs
        Schema.DescribeSObjectResult dr = ChargeMapItem__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = dr.fields.getMap();
        // Liste des API names de champs à afficher
        List<String> fieldNames = new List<String>{
            'Name','Amount__c','BillingSchedule__c','Term__c','StartDateRevRec__c','EndDateRevRec__c',
            'ProductNature__c','Quantity__c','CurrencyIsoCode','Status__c','Spend__c','PercentageOfSpend__c',
            'ProratedAmount__c','NbOfMonthsProrated__c','ProratedAmountPerMonth__c','PO_Reference__c','PO_Request_Date__c'
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
}