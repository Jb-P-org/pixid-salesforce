@isTest
private class ResetUserPasswordActionTest {

    @isTest
    static void testResetPasswordsSuccess() {
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;

        Test.startTest();
        List<ResetUserPasswordAction.Result> results =
            ResetUserPasswordAction.resetPasswords(new List<Id>{ testUser.Id });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success);
        System.assertNotEquals(null, results[0].message);
        System.assert(results[0].message.contains('e-mail'));
    }

    @isTest
    static void testResetPasswordsMultipleUsers() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        List<User> testUsers = new List<User>();
        for (Integer i = 0; i < 3; i++) {
            testUsers.add(new User(
                FirstName = 'Test' + i,
                LastName = 'User' + i,
                Email = 'testuser' + i + '@example.com',
                Username = 'testuser' + i + System.currentTimeMillis() + '@example.com',
                Alias = 'tuser' + i,
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = p.Id,
                LanguageLocaleKey = 'en_US'
            ));
        }
        insert testUsers;

        List<Id> userIds = new List<Id>();
        for (User u : testUsers) {
            userIds.add(u.Id);
        }

        Test.startTest();
        List<ResetUserPasswordAction.Result> results =
            ResetUserPasswordAction.resetPasswords(userIds);
        Test.stopTest();

        System.assertEquals(3, results.size());
        for (ResetUserPasswordAction.Result r : results) {
            System.assertEquals(true, r.success);
        }
    }

    @isTest
    static void testResetPasswordsError() {
        // Use invalid ID to trigger error
        Id invalidUserId = '005000000000000AAA';

        Test.startTest();
        List<ResetUserPasswordAction.Result> results =
            ResetUserPasswordAction.resetPasswords(new List<Id>{ invalidUserId });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Erreur'));
    }
}