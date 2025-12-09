@isTest
private class TestAutocreatedRegHandler1746855348197 {
    @isTest
    static void testHandlerLogic() {
        String uniqueUsername = 'testuser' + Datetime.now().getTime() + '@example.com';

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = uniqueUsername,
            Alias = 'tuser1',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            LanguageLocaleKey = 'fr'
        );
        insert u;

        AutocreatedRegHandler1746855348197 handler = new AutocreatedRegHandler1746855348197();
        System.assertEquals(false, handler.canCreateUser(null));
        handler.updateUser(u.Id, null, null);
    }
}