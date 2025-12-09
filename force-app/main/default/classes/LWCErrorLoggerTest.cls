@isTest
private class LWCErrorLoggerTest {
    
    @isTest
    static void testLogError() {
        // Création d'un utilisateur de test
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        User u = new User(
            Alias = 'extusr',
            Email = 'externaluser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Europe/Paris',
            UserName = 'externaluser_test_lwc_logger@example.com'
        );
        insert u;

        System.runAs(u) {
            // Appel de la méthode à tester
            Test.startTest();
            LWCErrorLogger.logError(
                'Test error message',
                'Error at line 42',
                'CaseFormLWC',
                'https://experience.example.com/case',
                'handleSubmit',
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
                '{"reason":"Test"}',
                'CustomerPortal',
                'Standard User',
                'Technical details test'
            );
            Test.stopTest();
        }

        // 🔍 Requête corrigée : filtrer sur ComponentName__c (filtrable)
        List<LWC_Error_Log__c> logs = [
            SELECT Message__c, StackTrace__c, ComponentName__c, PageURL__c, LWC_Method__c,
                   BrowserInfos__c, ExtraContext__c, User__c, UserType__c, ProfileName__c
            FROM LWC_Error_Log__c
            WHERE ComponentName__c = 'CaseFormLWC'
        ];

        System.assertEquals(1, logs.size());
        LWC_Error_Log__c log = logs[0];

        // Vérifications
        System.assertEquals('Test error message', log.Message__c);
        System.assertEquals('handleSubmit', log.LWC_Method__c);
        System.assertEquals('CustomerPortal', log.UserType__c);
        System.assertEquals('Standard User', log.ProfileName__c);
        System.assertEquals(u.Id, log.User__c);
    }
}