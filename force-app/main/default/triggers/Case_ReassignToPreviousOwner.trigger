trigger Case_ReassignToPreviousOwner on Case (before update) {
    if (Trigger.isBefore && Trigger.isUpdate) {

        // Récupérer la queue "Support FR"
        Group supportFrGroup = [
            SELECT Id FROM Group WHERE Name = 'Support FR' AND Type = 'Queue' LIMIT 1
        ];

        // Résoudre tous les UserId associés à cette queue (User, Role, Group inclus)
        Set<Id> supportFrUserIds = new Set<Id>();

        List<GroupMember> members = [
            SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :supportFrGroup.Id
        ];

        for (GroupMember gm : members) {
            Id memberId = gm.UserOrGroupId;
            String prefix = String.valueOf(memberId).left(3);

            if (prefix == '005') {
                // Utilisateur direct
                supportFrUserIds.add(memberId);

            } else if (prefix == '00E') {
                // Rôle → récupérer les utilisateurs liés à ce rôle
                for (User u : [
                    SELECT Id FROM User WHERE UserRoleId = :memberId AND IsActive = true
                ]) {
                    supportFrUserIds.add(u.Id);
                }

            } else if (prefix == '00G') {
                // Groupe → récupérer les utilisateurs directs de ce groupe
                for (GroupMember sub : [
                    SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :memberId
                ]) {
                    if (String.valueOf(sub.UserOrGroupId).startsWith('005')) {
                        supportFrUserIds.add(sub.UserOrGroupId);
                    }
                }
            }
        }

        // Précharger les RecordType names
        Set<Id> recordTypeIds = new Set<Id>();
        for (Case c : Trigger.new) {
            recordTypeIds.add(c.RecordTypeId);
        }

        Map<Id, String> recordTypeNames = new Map<Id, String>();
        for (RecordType rt : [
            SELECT Id, Name FROM RecordType WHERE Id IN :recordTypeIds
        ]) {
            recordTypeNames.put(rt.Id, rt.Name);
        }

        for (Case c : Trigger.new) {
            Case oldCase = Trigger.oldMap.get(c.Id);

            // Ne rien faire si OwnerId n'a pas changé
            if (c.OwnerId == oldCase.OwnerId) continue;

            Boolean newOwnerIsQueueOrMember = (
                c.OwnerId == supportFrGroup.Id ||
                supportFrUserIds.contains(c.OwnerId)
            );
            Boolean oldOwnerIsQueueOrMember = (
                oldCase.OwnerId == supportFrGroup.Id ||
                supportFrUserIds.contains(oldCase.OwnerId)
            );

            String recordTypeName = recordTypeNames.get(c.RecordTypeId);

            if (
                newOwnerIsQueueOrMember &&
                !oldOwnerIsQueueOrMember &&
                recordTypeName != 'Support'
            ) {
                c.OwnerId = oldCase.OwnerId; // Réaffecter l'ancien propriétaire
            }
        }
    }
}