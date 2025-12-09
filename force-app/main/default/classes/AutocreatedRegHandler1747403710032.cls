global class AutocreatedRegHandler1747403710032 implements Auth.RegistrationHandler {
    
    global boolean canCreateUser(Auth.UserData data) {
        return false;
    }

    global User createUser(Id portalId, Auth.UserData data){
        if(!canCreateUser(data)) {
            return null;
        }

        if(data.attributeMap.containsKey('sfdc_networkid')) {
            Account a = [SELECT Id FROM account WHERE name='Acme'];
            Contact c = new Contact();
            c.accountId = a.Id;
            c.email = data.email;
            c.firstName = data.firstName;
            c.lastName = data.lastName;
            insert(c);

            Profile p = [SELECT Id FROM profile WHERE name='Customer Portal User'];
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
            u.contactId = c.Id;
            return u;
        } else {
            Profile p = [SELECT Id FROM profile WHERE name='Standard User'];
            User u = new User();
            u.username = data.username + '@myorg.com';
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
            return u;
        }
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