public without sharing class LWCErrorLogger {
    @AuraEnabled
    public static void logError(
        String message,
        String stack,
        String component,
        String pageUrl,
        String method,
        String browserInfo,
        String extraContext,
        String userType,
        String profileName,
        String technicalDetails // 🆕 nouveau paramètre
    ) {
        LWC_Error_Log__c log = new LWC_Error_Log__c();
        log.Message__c = message;
        log.StackTrace__c = stack;
        log.ComponentName__c = component;
        log.PageURL__c = pageUrl;
        log.Date__c = System.now();
        log.LWC_Method__c = method;
        log.BrowserInfos__c = browserInfo;
        log.ExtraContext__c = extraContext;
        log.UserType__c = userType;
        log.ProfileName__c = profileName;
        log.User__c = UserInfo.getUserId(); // null if guest user

        // 🆕 Ajout du champ technique si renseigné
        if (String.isNotBlank(technicalDetails)) {
            log.TechnicalDetails__c = technicalDetails;
        }

        insert log;
    }
}