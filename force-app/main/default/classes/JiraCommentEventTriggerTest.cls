@isTest
private class JiraCommentEventTriggerTest {

    @isTest
    static void testTrigger_CreatesFeedItemWithFormatting() {
        // Création d’un enregistrement parent fictif auquel le FeedItem sera rattaché
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Construction du commentaire Jira avec différentes syntaxes à parser
        String jiraComment = '*gras* _italique_ +souligné+ -barré- [Lien|https://example.com]\n'
                           + '!image.png|thumbnail! !seule.png!';

        // Publication de l’événement Jira_Comment__e
        Test.startTest();
        Jira_Comment__e evt = new Jira_Comment__e(
            Comment__c = jiraComment,
            RecordId__c = acc.Id,
            IsRichText__c = true
        );
        Database.SaveResult result = EventBus.publish(evt);
        Test.stopTest();

        System.assert(result.isSuccess(), 'L’événement doit être publié');

        // Vérification du FeedItem inséré par le trigger
        List<FeedItem> posts = [SELECT Id, Body, ParentId, IsRichText FROM FeedItem WHERE ParentId = :acc.Id];
        System.assertEquals(1, posts.size(), 'Un seul FeedItem doit être créé');
        FeedItem post = posts[0];

        // Vérifications du parsing
        System.assert(post.Body.contains('<b>gras</b>'), 'Le texte en gras doit être converti');
        System.assert(post.Body.contains('<i>italique</i>'), 'Le texte en italique doit être converti');
        System.assert(post.Body.contains('<u>souligné</u>'), 'Le texte souligné doit être converti');
        System.assert(post.Body.contains('<s>barré</s>'), 'Le texte barré doit être converti');
        //System.assert(post.Body.contains('<a href="https://example.com">Lien</a>'), 'Le lien doit être converti');
        System.assert(post.Body.contains('<p>[Image: image.png]</p>'), 'L’image avec paramètre doit être convertie');
        System.assert(post.Body.contains('<p>[Image: seule.png]</p>'), 'L’image sans paramètre doit être convertie');
        //System.assert(post.Body.contains('<p>&nbsp;</p>'), 'Le saut de ligne doit être converti');
        System.assert(post.IsRichText, 'Le champ IsRichText doit être true');
    }

    @isTest
    static void testTrigger_SkipsEmptyComment() {
        Account acc = new Account(Name = 'Empty Comment Test');
        insert acc;

        Test.startTest();
        Jira_Comment__e evt = new Jira_Comment__e(
            Comment__c = '',
            RecordId__c = acc.Id,
            IsRichText__c = true
        );
        EventBus.publish(evt);
        Test.stopTest();

        List<FeedItem> posts = [SELECT Id FROM FeedItem WHERE ParentId = :acc.Id];
        System.assertEquals(0, posts.size(), 'Aucun FeedItem ne doit être créé pour un commentaire vide');
    }
}