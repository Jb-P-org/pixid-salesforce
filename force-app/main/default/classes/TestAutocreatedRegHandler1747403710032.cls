@isTest
private class TestAutocreatedRegHandler1747403710032 {
    @isTest
    static void testHandlerMinimal() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueUsername = 'unique' + DateTime.now().getTime() + '@example.com';

        User u = new User(
            FirstName = 'Initial',
            LastName = 'User',
            Email = 'init@example.com',
            Username = uniqueUsername,
            Alias = 'initusr2',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'fr'
        );
        insert u;

        AutocreatedRegHandler1747403710032 handler = new AutocreatedRegHandler1747403710032();
        //System.assertEquals(false, handler.canCreateUser(null));
        handler.updateUser(u.Id, null, null);
    }
}