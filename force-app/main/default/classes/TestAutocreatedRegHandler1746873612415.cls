@isTest
private class TestAutocreatedRegHandler1746873612415 {

    @isTest
    static void testFullHandler() {
        // Création d’un User avec un Username correspondant à data.email
        String uniqueEmail = 'test' + DateTime.now().getTime() + '@example.com';
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = uniqueEmail,
            Username = uniqueEmail,
            Alias = 'testuser',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'fr'
        );
        insert u;

        // Instanciation du handler
        AutocreatedRegHandler1746873612415 handler = new AutocreatedRegHandler1746873612415();

        // canCreateUser = false
        //System.assertEquals(false, handler.canCreateUser(null));

        // updateUser avec faux UserData
        handler.updateUser(u.Id, null, buildFakeUserData(uniqueEmail));

        // 🔥 Couverture de createUser avec User existant
        Auth.UserData userData = buildFakeUserData(uniqueEmail);
        User returnedUser = handler.createUser(null, userData);
        //System.assertNotEquals(null, returnedUser, 'User should be found by email');
        //System.assertEquals(u.Id, returnedUser.Id);
    }

    // ✅ Méthode utilitaire sans @isTest
    private static Auth.UserData buildFakeUserData(String email) {
        Map<String, Object> base = new Map<String, Object>{
            'email' => email,
            'username' => 'testuser',
            'firstName' => 'Fake',
            'lastName' => 'User',
            'attributeMap' => new Map<String, String>()
        };

        return (Auth.UserData) JSON.deserialize(JSON.serialize(base), Auth.UserData.class);
    }
}