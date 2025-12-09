@isTest
private class CaseControllerTest {

    @testSetup
    static void setup() {
        // Create test Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create test Contact
        Contact contact = new Contact(
            FirstName = 'Portal',
            LastName = 'User',
            Email = 'portaluser@example.com',
            AccountId = acc.Id
        );
        insert contact;

        // Create Portal User
        Profile portalProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community User' OR Name = 'Customer Portal Manager' OR Name LIKE '%Portal%' OR Name LIKE '%Community%' LIMIT 1];

        User portalUser = new User(
            Username = 'portaluser' + System.currentTimeMillis() + '@test.com',
            Email = 'portaluser@example.com',
            FirstName = 'Portal',
            LastName = 'User',
            Alias = 'puser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = portalProfile.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = contact.Id
        );
        insert portalUser;
    }

    @isTest
    static void testGetAccountId() {
        User portalUser = [SELECT Id, ContactId FROM User WHERE Email = 'portaluser@example.com' LIMIT 1];
        Account expectedAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        Id accountId;
        System.runAs(portalUser) {
            accountId = CaseController.getAccountId();
        }
        Test.stopTest();

        System.assertEquals(expectedAccount.Id, accountId, 'Should return the correct Account Id');
    }

    @isTest
    static void testGetAccountIdNoContact() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User standardUser = new User(
            Username = 'standarduser' + System.currentTimeMillis() + '@test.com',
            Email = 'standarduser@example.com',
            FirstName = 'Standard',
            LastName = 'User',
            Alias = 'suser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = standardProfile.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert standardUser;

        Test.startTest();
        Id accountId;
        System.runAs(standardUser) {
            accountId = CaseController.getAccountId();
        }
        Test.stopTest();

        System.assertEquals(null, accountId, 'Should return null when user has no contact');
    }

    @isTest
    static void testGetContactIdForCurrentUser() {
        User portalUser = [SELECT Id, ContactId FROM User WHERE Email = 'portaluser@example.com' LIMIT 1];

        Test.startTest();
        Id contactId;
        System.runAs(portalUser) {
            contactId = CaseController.getContactIdForCurrentUser();
        }
        Test.stopTest();

        System.assertEquals(portalUser.ContactId, contactId, 'Should return the correct Contact Id');
    }

    @isTest
    static void testAssociateFilesToRecord() {
        Case c = new Case(Subject = 'Test Case');
        insert c;

        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Contenu de test')
        );
        insert cv;

        ContentDocument cd = [
            SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :cv.Id
        ];

        Test.startTest();
        CaseController.associateFilesToRecord(c.Id, new List<Id>{ cd.Id });
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :c.Id
        ];

        System.assertEquals(1, links.size(), 'Le fichier doit être correctement lié au Case');
    }

    @isTest
    static void testLinkArticleToCase() {
        Case testCase = new Case(Subject = 'Test Case for Article Link');
        insert testCase;

        // Create a Knowledge Article
        Knowledge__kav article = new Knowledge__kav(
            Title = 'Test Article',
            UrlName = 'test-article-' + System.currentTimeMillis()
        );
        insert article;

        // Publish the article
        article = [SELECT Id, KnowledgeArticleId FROM Knowledge__kav WHERE Id = :article.Id LIMIT 1];

        Test.startTest();
        CaseController.linkArticleToCase(testCase.Id, article.KnowledgeArticleId);
        Test.stopTest();

        List<CaseArticle> caseArticles = [
            SELECT Id, CaseId, KnowledgeArticleId
            FROM CaseArticle
            WHERE CaseId = :testCase.Id
        ];

        System.assertEquals(1, caseArticles.size(), 'Should create one CaseArticle link');
        System.assertEquals(article.KnowledgeArticleId, caseArticles[0].KnowledgeArticleId);
    }

    @isTest
    static void testLinkArticleToCaseWithNullParams() {
        Test.startTest();
        CaseController.linkArticleToCase(null, null);
        Test.stopTest();

        List<CaseArticle> caseArticles = [SELECT Id FROM CaseArticle];
        System.assertEquals(0, caseArticles.size(), 'Should not create any links with null parameters');
    }

    @isTest
    static void testGetCaseNumber() {
        Case c = new Case(Subject = 'Test Case for CaseNumber');
        insert c;

        Case insertedCase = [SELECT Id, CaseNumber FROM Case WHERE Id = :c.Id];

        Test.startTest();
        String result = CaseController.getCaseNumber(c.Id);
        Test.stopTest();

        System.assertEquals(insertedCase.CaseNumber, result, 'Le CaseNumber retourné doit correspondre au Case créé');
        System.assertNotEquals(null, result, 'Le CaseNumber ne doit pas être null');
    }

    @isTest
    static void testGetCaseNumberWithInvalidId() {
        Id fakeId = '500000000000000AAA';

        Test.startTest();
        String result = CaseController.getCaseNumber(fakeId);
        Test.stopTest();

        System.assertEquals(null, result, 'La méthode doit retourner null pour un ID invalide');
    }
}