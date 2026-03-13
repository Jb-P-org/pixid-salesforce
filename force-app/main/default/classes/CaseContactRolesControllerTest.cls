@isTest
private class CaseContactRolesControllerTest {

    @testSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact contact1 = new Contact(
            FirstName = 'Alice',
            LastName = 'Dupont',
            Email = 'alice@example.com',
            Phone = '0600000001',
            Title = 'Manager',
            AccountId = acc.Id
        );
        Contact contact2 = new Contact(
            FirstName = 'Bob',
            LastName = 'Martin',
            Email = 'bob@example.com',
            Phone = '0600000002',
            Title = 'Developer',
            AccountId = acc.Id
        );
        Contact contact3 = new Contact(
            FirstName = 'Charlie',
            LastName = 'Leroy',
            Email = 'charlie@example.com',
            Phone = '0600000003',
            Title = 'Analyst',
            AccountId = acc.Id
        );
        insert new List<Contact>{ contact1, contact2, contact3 };

        Offer__c offer1 = new Offer__c(Account__c = acc.Id);
        Offer__c offer2 = new Offer__c(Account__c = acc.Id);
        insert new List<Offer__c>{ offer1, offer2 };

        // Contact 1: Administrator on Offer 1 + Certificate owner on Offer 2
        OfferContactRole__c ocr1 = new OfferContactRole__c(
            Contact__c = contact1.Id,
            Offer__c = offer1.Id,
            RoleForPixid__c = 'Administrator'
        );
        OfferContactRole__c ocr2 = new OfferContactRole__c(
            Contact__c = contact1.Id,
            Offer__c = offer2.Id,
            RoleForPixid__c = 'Certificate owner'
        );
        // Contact 2: Administrator on Offer 1 + Administrator on Offer 2 (duplicate role)
        OfferContactRole__c ocr3 = new OfferContactRole__c(
            Contact__c = contact2.Id,
            Offer__c = offer1.Id,
            RoleForPixid__c = 'Administrator'
        );
        OfferContactRole__c ocr4 = new OfferContactRole__c(
            Contact__c = contact2.Id,
            Offer__c = offer2.Id,
            RoleForPixid__c = 'Administrator'
        );
        // Contact 3: no roles
        insert new List<OfferContactRole__c>{ ocr1, ocr2, ocr3, ocr4 };

        Case testCase = new Case(
            Subject = 'Test Case',
            AccountId = acc.Id
        );
        insert testCase;
    }

    private static CaseContactRolesController.FlowInputs buildInput(Id caseId) {
        CaseContactRolesController.FlowInputs fi = new CaseContactRolesController.FlowInputs();
        fi.caseId = caseId;
        return fi;
    }

    @isTest
    static void testHappyPath() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Test Case' LIMIT 1];

        Test.startTest();
        List<CaseContactRolesController.FlowOutputs> results =
            CaseContactRolesController.getContactsWithRoles(new List<CaseContactRolesController.FlowInputs>{ buildInput(testCase.Id) });
        Test.stopTest();

        List<ContactWithRoles> contacts = results[0].contacts;
        System.assertEquals(3, contacts.size(), 'Should return 3 contacts');

        // Contacts with roles should come first
        Set<String> firstTwoIds = new Set<String>{ contacts[0].contactId, contacts[1].contactId };
        Contact contact1 = [SELECT Id FROM Contact WHERE LastName = 'Dupont' LIMIT 1];
        Contact contact2 = [SELECT Id FROM Contact WHERE LastName = 'Martin' LIMIT 1];
        Contact contact3 = [SELECT Id FROM Contact WHERE LastName = 'Leroy' LIMIT 1];

        System.assert(firstTwoIds.contains(contact1.Id), 'Contact with roles should be in first group');
        System.assert(firstTwoIds.contains(contact2.Id), 'Contact with roles should be in first group');
        System.assertEquals(contact3.Id, contacts[2].contactId, 'Contact without roles should be last');

        // Contact 3 should have null roles
        System.assertEquals(null, contacts[2].concatenatedRoles, 'Contact without roles should have null concatenatedRoles');

        // Verify contactUrl format
        System.assert(contacts[0].contactUrl.contains('/lightning/r/Contact/'), 'contactUrl should be a Lightning URL');
        System.assert(contacts[0].contactUrl.endsWith('/view'), 'contactUrl should end with /view');
    }

    @isTest
    static void testDeduplicatedRoles() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Test Case' LIMIT 1];
        Contact contact2 = [SELECT Id FROM Contact WHERE LastName = 'Martin' LIMIT 1];

        Test.startTest();
        List<CaseContactRolesController.FlowOutputs> results =
            CaseContactRolesController.getContactsWithRoles(new List<CaseContactRolesController.FlowInputs>{ buildInput(testCase.Id) });
        Test.stopTest();

        // Find Contact 2 (Bob Martin) in results
        ContactWithRoles bobResult;
        for (ContactWithRoles cwr : results[0].contacts) {
            if (cwr.contactId == contact2.Id) {
                bobResult = cwr;
                break;
            }
        }

        System.assertNotEquals(null, bobResult, 'Bob Martin should be in results');
        System.assertEquals('Administrator', bobResult.concatenatedRoles,
            'Duplicate Administrator role across Offers should appear only once');
    }

    @isTest
    static void testNullInput() {
        Test.startTest();
        List<CaseContactRolesController.FlowOutputs> results =
            CaseContactRolesController.getContactsWithRoles(null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(0, results[0].contacts.size(), 'Should return empty list for null input');
    }

    @isTest
    static void testNullCaseId() {
        Test.startTest();
        List<CaseContactRolesController.FlowOutputs> results =
            CaseContactRolesController.getContactsWithRoles(new List<CaseContactRolesController.FlowInputs>{ buildInput(null) });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(0, results[0].contacts.size(), 'Should return empty list for null caseId');
    }

    @isTest
    static void testCaseWithoutAccount() {
        Case orphanCase = new Case(Subject = 'Orphan Case');
        insert orphanCase;

        Test.startTest();
        List<CaseContactRolesController.FlowOutputs> results =
            CaseContactRolesController.getContactsWithRoles(new List<CaseContactRolesController.FlowInputs>{ buildInput(orphanCase.Id) });
        Test.stopTest();

        System.assertEquals(0, results[0].contacts.size(), 'Should return empty list for Case without Account');
    }

    @isTest
    static void testAccountWithNoContacts() {
        Account emptyAcc = new Account(Name = 'Empty Account');
        insert emptyAcc;

        Case testCase = new Case(Subject = 'No Contacts Case', AccountId = emptyAcc.Id);
        insert testCase;

        Test.startTest();
        List<CaseContactRolesController.FlowOutputs> results =
            CaseContactRolesController.getContactsWithRoles(new List<CaseContactRolesController.FlowInputs>{ buildInput(testCase.Id) });
        Test.stopTest();

        System.assertEquals(0, results[0].contacts.size(), 'Should return empty list for Account with no contacts');
    }

    @isTest
    static void testAccountWithNoOffers() {
        Account noOfferAcc = new Account(Name = 'No Offer Account');
        insert noOfferAcc;

        Contact c = new Contact(FirstName = 'Test', LastName = 'NoOffer', AccountId = noOfferAcc.Id);
        insert c;

        Case testCase = new Case(Subject = 'No Offers Case', AccountId = noOfferAcc.Id);
        insert testCase;

        Test.startTest();
        List<CaseContactRolesController.FlowOutputs> results =
            CaseContactRolesController.getContactsWithRoles(new List<CaseContactRolesController.FlowInputs>{ buildInput(testCase.Id) });
        Test.stopTest();

        System.assertEquals(1, results[0].contacts.size(), 'Should return 1 contact');
        System.assertEquals(null, results[0].contacts[0].concatenatedRoles,
            'Contact should have null concatenatedRoles when no Offers exist');
    }
}
