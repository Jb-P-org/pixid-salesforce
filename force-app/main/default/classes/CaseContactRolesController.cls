/**
 * @description Invocable Apex class used in a Screen Flow on Case record page.
 *              Consolidates contacts linked to the Case's Account with their
 *              concatenated OfferContactRole roles (deduplicated).
 *              Uses FlowInputs/FlowOutputs wrapper pattern so the Data Table
 *              standard Flow component can consume the Apex-defined collection.
 */
public without sharing class CaseContactRolesController {

    public class FlowInputs {
        @InvocableVariable(required=true description='The Case record Id')
        public Id caseId;
    }

    public class FlowOutputs {
        @InvocableVariable(description='List of contacts with their concatenated roles')
        public List<ContactWithRoles> contacts;
    }

    @InvocableMethod(label='Get Case Contacts With Roles' description='Returns contacts linked to the Case Account with their concatenated roles')
    public static List<FlowOutputs> getContactsWithRoles(List<FlowInputs> inputs) {
        FlowOutputs output = new FlowOutputs();
        output.contacts = new List<ContactWithRoles>();

        if (inputs == null || inputs.isEmpty() || inputs[0].caseId == null) {
            return new List<FlowOutputs>{ output };
        }

        Id caseId = inputs[0].caseId;

        // Query Case — use list to avoid QueryException if record not found
        List<Case> cases = [SELECT AccountId FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty() || cases[0].AccountId == null) {
            return new List<FlowOutputs>{ output };
        }

        Id accountId = cases[0].AccountId;

        // Get all Contacts for this Account (IsCommunityUserActive__c and LastModifiedDate for sorting)
        Map<Id, Contact> contactsMap = new Map<Id, Contact>([
            SELECT Id, Name, Email, Phone, Title, IsCommunityUserActive__c, LastModifiedDate
            FROM Contact
            WHERE AccountId = :accountId
        ]);

        if (contactsMap.isEmpty()) {
            return new List<FlowOutputs>{ output };
        }

        // Get Offer Ids for this Account, then query OfferContactRoles (selective index)
        Set<Id> offerIds = new Map<Id, Offer__c>(
            [SELECT Id FROM Offer__c WHERE Account__c = :accountId]
        ).keySet();

        List<OfferContactRole__c> offerContactRoles = [
            SELECT Contact__c, RoleForPixid__c
            FROM OfferContactRole__c
            WHERE Offer__c IN :offerIds
              AND Contact__c IN :contactsMap.keySet()
        ];

        // Group roles by Contact (deduplicated via Set)
        Map<Id, Set<String>> rolesByContact = new Map<Id, Set<String>>();
        for (OfferContactRole__c ocr : offerContactRoles) {
            if (ocr.RoleForPixid__c == null) {
                continue;
            }
            if (!rolesByContact.containsKey(ocr.Contact__c)) {
                rolesByContact.put(ocr.Contact__c, new Set<String>());
            }
            rolesByContact.get(ocr.Contact__c).add(ocr.RoleForPixid__c);
        }

        // Build result list in 3 groups:
        // 1. Contacts with at least one OfferContactRole (has roles)
        // 2. Community User active contacts (no roles)
        // 3. Other contacts (no roles, not community active)
        // Within each group, sort by LastModifiedDate DESC
        List<Contact> withRoles = new List<Contact>();
        List<Contact> communityActive = new List<Contact>();
        List<Contact> others = new List<Contact>();

        for (Contact c : contactsMap.values()) {
            if (rolesByContact.containsKey(c.Id)) {
                withRoles.add(c);
            } else if (c.IsCommunityUserActive__c == true) {
                communityActive.add(c);
            } else {
                others.add(c);
            }
        }

        // Sort each group by LastModifiedDate DESC
        withRoles.sort(new ContactLastModifiedDescComparator());
        communityActive.sort(new ContactLastModifiedDescComparator());
        others.sort(new ContactLastModifiedDescComparator());

        // Build final ordered list
        List<Contact> orderedContacts = new List<Contact>();
        orderedContacts.addAll(withRoles);
        orderedContacts.addAll(communityActive);
        orderedContacts.addAll(others);

        for (Contact c : orderedContacts) {
            ContactWithRoles cwr = new ContactWithRoles();
            cwr.contactId = c.Id;
            cwr.contactName = c.Name;
            cwr.contactUrl = URL.getOrgDomainURL().toExternalForm() + '/lightning/r/Contact/' + c.Id + '/view';
            cwr.email = c.Email;
            cwr.phone = c.Phone;
            cwr.isSelfUserActive = c.IsCommunityUserActive__c;

            Set<String> roles = rolesByContact.get(c.Id);
            if (roles != null && !roles.isEmpty()) {
                List<String> sortedRoles = new List<String>(roles);
                sortedRoles.sort();
                cwr.concatenatedRoles = String.join(sortedRoles, '; ');
            }

            output.contacts.add(cwr);
        }

        return new List<FlowOutputs>{ output };
    }

    /**
     * @description Comparator to sort Contacts by LastModifiedDate descending.
     */
    private class ContactLastModifiedDescComparator implements System.Comparator<Contact> {
        public Integer compare(Contact a, Contact b) {
            if (a.LastModifiedDate == b.LastModifiedDate) {
                return 0;
            }
            if (a.LastModifiedDate == null) {
                return 1;
            }
            if (b.LastModifiedDate == null) {
                return -1;
            }
            // DESC: more recent first
            return b.LastModifiedDate > a.LastModifiedDate ? 1 : -1;
        }
    }
}
