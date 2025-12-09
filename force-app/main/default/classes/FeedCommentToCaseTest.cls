@isTest
public class FeedCommentToCaseTest {

    @isTest
    static void testCommunityCommentUpdatesCase() {
        // 1. Récupérer un profil Community
        Profile communityProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Community%' LIMIT 1];
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        // 2. Récupérer un rôle existant avec "Admin" dans le nom (sinon prendre le 1er dispo)
        UserRole role = [SELECT Id FROM UserRole WHERE Name LIKE '%Admin%' LIMIT 1];

        // 3. Créer un User avec ce rôle pour qu'il puisse être Owner de l'Account
        User accountOwner = new User(
            Username = 'owneruser@example.com.test',
            Alias = 'ownusr',
            Email = 'owner@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Owner',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Paris',
            ProfileId = adminProfile.Id,
            UserRoleId = role.Id
        );
        insert accountOwner;

        // 4. Créer un Account dont le Owner a un rôle
        Account extAccount = new Account(
            Name = 'Test Account',
            OwnerId = accountOwner.Id
        );
        insert extAccount;

        // 5. Créer un Contact lié à cet account
        Contact extContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'contact@example.com',
            AccountId = extAccount.Id
        );
        insert extContact;

        // 6. Créer un User Community lié au Contact
        User communityUser = new User(
            Username = 'communityuser@example.com.test',
            Alias = 'commusr',
            Email = 'communityuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Paris',
            ProfileId = communityProfile.Id,
            ContactId = extContact.Id
        );
        insert communityUser;

        // 7. Tester le trigger via runAs
        System.runAs(communityUser) {
            Case testCase = new Case(Subject = 'Test case');
            insert testCase;

            FeedItem post = new FeedItem(
                ParentId = testCase.Id,
                Body = 'Initial post',
                Type = 'TextPost'
            );
            insert post;

            FeedComment comment = new FeedComment(
                FeedItemId = post.Id,
                CommentBody = 'This is a test comment from a Community user'
            );
            insert comment;

            Case updatedCase = [
                SELECT Customer_Last_Comment__c, Customer_Last_Comment_Date_Time__c 
                FROM Case 
                WHERE Id = :testCase.Id
            ];
            System.assertEquals('This is a test comment from a Community user', updatedCase.Customer_Last_Comment__c);
            System.assertNotEquals(null, updatedCase.Customer_Last_Comment_Date_Time__c);
        }
    }
}