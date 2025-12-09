// CaseController.cls - Classe Apex pour les opérations liées au formulaire Case LWC

public without sharing class CaseController {

    // Récupère l'AccountId associé au Contact de l'utilisateur connecté
    @AuraEnabled(cacheable=true)
    public static Id getAccountId() {
        User currentUser = [
            SELECT Contact.AccountId 
            FROM User 
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        return currentUser.Contact != null ? currentUser.Contact.AccountId : null;
    }

    // Associe une liste de fichiers (ContentDocument) à un enregistrement (ici un Case)
    // Chaque fichier est lié via ContentDocumentLink avec un accès Viewer pour tous les utilisateurs
    @AuraEnabled
    public static void associateFilesToRecord(Id recordId, List<Id> contentDocumentIds) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();

        for (Id docId : contentDocumentIds) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId = recordId,
                ShareType = 'V', // V = Viewer
                Visibility = 'AllUsers' // visible par tous les utilisateurs
            ));
        }

        insert links;
    }

    // Crée une relation entre un Case et un article Knowledge
    // Utilise l'objet standard CaseArticle (relation many-to-many)
    @AuraEnabled
    public static void linkArticleToCase(Id caseId, Id articleId) {
        if (String.isNotBlank(caseId) && String.isNotBlank(articleId)) {
            insert new CaseArticle(
                CaseId = caseId,
                KnowledgeArticleId = articleId
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static Id getContactIdForCurrentUser() {
    User currentUser = [
        SELECT ContactId 
        FROM User 
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
    ];
    return currentUser.ContactId;
}

@AuraEnabled
public static String getCaseNumber(Id caseId) {
    try {
        Case c = [SELECT CaseNumber FROM Case WHERE Id = :caseId LIMIT 1];
        return c.CaseNumber;
    } catch (Exception e) {
        return null;
    }
}

@AuraEnabled(cacheable=true)
public static String getUserLanguage() {
    User currentUser = [
        SELECT LanguageLocaleKey
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
    ];
    return currentUser.LanguageLocaleKey;
}

}