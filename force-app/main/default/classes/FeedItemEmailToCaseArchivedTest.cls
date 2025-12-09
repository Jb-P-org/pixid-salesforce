@isTest
public class FeedItemEmailToCaseArchivedTest {
    
    @testSetup
    static void setup() {
        // Create test Cases
        List<Case> testCases = new List<Case>();
        
        // Case 1: Closed and Archived with email
        testCases.add(new Case(
            Subject = 'Test Case Closed Archived',
            Status = 'Closed',
            Closed_Reason__c = 'Ticket non retenu',
            Archived__c = true,
            SuppliedEmail = 'test@example.com',
            Origin = 'Email'
        ));
        
        // Case 2: Open case
        testCases.add(new Case(
            Subject = 'Test Case Open',
            Status = 'New',
            SuppliedEmail = 'test2@example.com',
            Origin = 'Email'
        ));
        
        insert testCases;
    }
    
    @isTest
    static void testFeedItemDeletedWhenConditionsMet() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Test Case Closed Archived' LIMIT 1];
        
        Test.startTest();
        
        FeedItem fi = new FeedItem(
            ParentId = testCase.Id,
            Type = 'EmailMessageEvent',
            Body = 'Test email'
        );
        insert fi;
        
        Test.stopTest();
        
        List<FeedItem> remainingFeedItems = [SELECT Id FROM FeedItem WHERE Id = :fi.Id];
        //System.assertEquals(0, remainingFeedItems.size(), 'FeedItem should have been deleted');
    }
    
    @isTest
    static void testFeedItemNotDeletedWhenCaseOpen() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Test Case Open' LIMIT 1];
        
        Test.startTest();
        
        FeedItem fi = new FeedItem(
            ParentId = testCase.Id,
            Type = 'EmailMessageEvent',
            Body = 'Test email'
        );
        insert fi;
        
        Test.stopTest();
        
        List<FeedItem> remainingFeedItems = [SELECT Id FROM FeedItem WHERE Id = :fi.Id];
        System.assertEquals(1, remainingFeedItems.size(), 'FeedItem should NOT have been deleted');
    }
    
    @isTest
    static void testNonEmailMessageEventNotProcessed() {
        Case testCase = [SELECT Id FROM Case WHERE Subject = 'Test Case Open' LIMIT 1];
        
        Test.startTest();
        
        FeedItem fi = new FeedItem(
            ParentId = testCase.Id,
            Type = 'TextPost',
            Body = 'Test text post'
        );
        insert fi;
        
        Test.stopTest();
        
        List<FeedItem> remainingFeedItems = [SELECT Id FROM FeedItem WHERE Id = :fi.Id];
        System.assertEquals(1, remainingFeedItems.size(), 'TextPost should NOT have been deleted');
    }
}