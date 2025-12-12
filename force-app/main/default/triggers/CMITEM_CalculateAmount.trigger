trigger CMITEM_CalculateAmount on ChargeMapItem__c (before insert, before update) {
    if (Trigger.isInsert) {
        for (ChargeMapItem__c r : Trigger.new) {
            if (r.Quantity__c != null && r.Sales_unit_price__c != null) {
                Decimal subtotal = r.Quantity__c * r.Sales_unit_price__c;
                
                if (r.DiscountNumber__c != null && r.DiscountNumber__c > 0) {
                    r.Amount__c = subtotal * (1 - r.DiscountNumber__c / 100);
                } else {
                    r.Amount__c = subtotal;
                }
                
                // Ensure Amount is never negative
                if (r.Amount__c != null && r.Amount__c < 0) {
                    r.Amount__c = 0;
                }
            } else {
                r.Amount__c = null;
            }
        }
    } else if (Trigger.isUpdate) {
        for (ChargeMapItem__c r : Trigger.new) {
            ChargeMapItem__c oldRec = Trigger.oldMap.get(r.Id);
            if (oldRec == null) continue;

            if (r.Quantity__c != oldRec.Quantity__c || 
                r.Sales_unit_price__c != oldRec.Sales_unit_price__c ||
                r.DiscountNumber__c != oldRec.DiscountNumber__c) {
                
                if (r.Quantity__c != null && r.Sales_unit_price__c != null) {
                    Decimal subtotal = r.Quantity__c * r.Sales_unit_price__c;
                    
                    if (r.DiscountNumber__c != null && r.DiscountNumber__c > 0) {
                        r.Amount__c = subtotal * (1 - r.DiscountNumber__c / 100);
                    } else {
                        r.Amount__c = subtotal;
                    }
                    
                    // Ensure Amount is never negative
                    if (r.Amount__c != null && r.Amount__c < 0) {
                        r.Amount__c = 0;
                    }
                } else {
                    r.Amount__c = null;
                }
            }
            
            if (r.StartDateRevRec__c != oldRec.StartDateRevRec__c) {
                if (r.StartDateRevRec__c != null && r.End_date__c != null) {
                    if (r.StartDateRevRec__c.year() != r.End_date__c.year()) {
                        r.End_date__c = Date.newInstance(
                            r.StartDateRevRec__c.year(),
                            r.End_date__c.month(),
                            r.End_date__c.day()
                        );
                    }
                }
            }
        }
    }
}