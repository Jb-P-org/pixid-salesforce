public class ContactWithRoles {
    @AuraEnabled public String contactId { get; set; }
    @AuraEnabled public String contactName { get; set; }
    @AuraEnabled public String contactUrl { get; set; }
    @AuraEnabled public String email { get; set; }
    @AuraEnabled public String phone { get; set; }
    @AuraEnabled public Boolean isSelfUserActive { get; set; }
    @AuraEnabled public String concatenatedRoles { get; set; }
}
