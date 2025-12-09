global class AutocreatedRegHandler1747148870353 implements Auth.RegistrationHandler {

    global boolean canCreateUser(Auth.UserData data) {
        return false;
    }

    global User createUser(Id portalId, Auth.UserData data){
        if(!canCreateUser(data)) {
            return null;
        }

        Account a;
        List<Account> accs = [SELECT Id FROM Account WHERE Name LIKE '%Acme%' LIMIT 1];
        if (accs.isEmpty()) {
            a = new Account(Name = 'Acme Placeholder');
            insert a;
        } else {
            a = accs[0];
        }

        Contact c = new Contact();
        c.accountId = a.Id;
        c.email = data.email;
        c.firstName = data.firstName;
        c.lastName = data.lastName;
        insert(c);

        Profile p;
        if (data.attributeMap != null && data.attributeMap.containsKey('sfdc_networkid')) {
            p = [SELECT Id FROM Profile WHERE Name = 'Customer Portal User' LIMIT 1];
        } else {
            p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }

        User u = new User();
        u.username = data.username + '@acmecorp.com';
        u.email = data.email;
        u.lastName = data.lastName;
        u.firstName = data.firstName;
        String alias = data.username;
        if(alias.length() > 8) {
            alias = alias.substring(0, 8);
        }
        u.alias = alias;
        u.languagelocalekey = UserInfo.getLocale();
        u.localesidkey = UserInfo.getLocale();
        u.emailEncodingKey = 'UTF-8';
        u.timeZoneSidKey = 'America/Los_Angeles';
        u.profileId = p.Id;
        u.contactId = (p.Name == 'Customer Portal User') ? c.Id : null;

        return u;
    }

    global void updateUser(Id userId, Id portalId, Auth.UserData data){
        if (data == null) return;
        User u = new User(id = userId);
        u.email = data.email;
        u.lastName = data.lastName;
        u.firstName = data.firstName;
        update(u);
    }
}