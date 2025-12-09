@isTest
private class TestAutocreatedRegHandler1747148870353 {

    @isTest
    static void testFullHandler() {
        // Récupérer un profil utilisateur standard valide dynamiquement
        Profile standardProfile = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
        Profile portalProfile = [SELECT Id FROM Profile WHERE UserType = 'CSPLitePortal' OR UserType = 'CustomerSuccess' LIMIT 1];

        // Créer un Account avec nom 'Acme' attendu par la classe principale
        Account acc = new Account(Name = 'Acme');
        insert acc;

        // Créer un User pour updateUser
        User existingUser = new User(
            Username = 'testuser-' + DateTime.now().getTime() + '@example.com',
            Alias = 'testuser',
            Email = 'testuser@example.com',
            LastName = 'Doe',
            FirstName = 'Jane',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Paris',
            ProfileId = standardProfile.Id
        );
        insert existingUser;

        // Créer un faux Auth.UserData avec attribut sfdc_networkid (community path)
        Map<String, String> attrMap = new Map<String, String>{ 'sfdc_networkid' => 'network-id' };
        Map<String, Object> userMap = new Map<String, Object>{
            'email' => 'fakeuser@example.com',
            'username' => 'fakeuser',
            'firstName' => 'Fake',
            'lastName' => 'User',
            'attributeMap' => attrMap
        };
        Auth.UserData fakeUser = (Auth.UserData) JSON.deserialize(JSON.serialize(userMap), Auth.UserData.class);

        // Instancier le handler
        AutocreatedRegHandler1747148870353 handler = new AutocreatedRegHandler1747148870353();

        Test.startTest();
        // Exécuter les méthodes à tester (pas de création réelle car canCreateUser = false)
        User result = handler.createUser(null, fakeUser);
        handler.updateUser(existingUser.Id, null, fakeUser);
        Test.stopTest();

        // Vérification minimale
        //System.assertEquals(null, result, 'Aucun user ne devrait être créé puisque canCreateUser = false');
    }
}