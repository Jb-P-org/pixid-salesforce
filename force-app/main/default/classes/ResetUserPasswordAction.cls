public class ResetUserPasswordAction {
    public class Result {
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Success')
        public Boolean success;
    }

    @InvocableMethod(label='Reset Password')
    public static List<Result> resetPasswords(List<Id> userIds) {
        List<Result> results = new List<Result>();
        for (Id userId : userIds) {
            Result r = new Result();
            try {
                System.resetPassword(userId, true);
                r.success = true;
                r.message = 'L\'e-mail de réinitialisation a été envoyé.';
            } catch (Exception e) {
                r.success = false;
                r.message = 'Erreur : ' + e.getMessage();
            }
            results.add(r);
        }
        return results;
    }
}