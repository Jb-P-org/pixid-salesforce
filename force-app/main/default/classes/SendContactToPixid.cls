public without sharing class SendContactToPixid {

    @InvocableMethod(label='Envoyer contact à PIXID' description='Envoie un contact vers l’API PIXID via Gravitee')
    public static void postToPixid(List<RequestData> requestList) {
        for (RequestData input : requestList) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://recette1api.mypixid.io/V1/salesforce/contacts');
                req.setMethod('POST');
                req.setHeader('X-Gravitee-Api-KEY', '82d13396-bf1d-405e-9133-96bf1d805e63');
                req.setHeader('Accept', 'application/json');
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(20000);

                Map<String, Object> contactMap = new Map<String, Object>{
                    'internal_id_tdg' => input.internal_id_tdg,
                    'account_number' => input.account_number,
                    'customer_contact_email' => input.customer_contact_email,
                    'customer_contact_backup_email' => input.customer_contact_backup_email,
                    'customer_administrator_email' => input.customer_administrator_email,
                    'customer_administrator_backup_email' => input.customer_administrator_backup_email
                };

                Map<String, Object> payload = new Map<String, Object>{
                    'contacts' => new List<Object>{ contactMap }
                };

                String body = JSON.serialize(payload);
                System.debug('📨 Corps envoyé : ' + body);
                req.setBody(body);

                Http http = new Http();
                HttpResponse res = http.send(req);

                System.debug('📥 Réponse reçue : ' + res.getBody());
                System.debug('📊 Statut HTTP : ' + res.getStatusCode());

                if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
                    throw new CalloutException('Erreur HTTP : ' + res.getStatusCode() + ' - ' + res.getBody());
                }

            } catch (Exception e) {
                System.debug('❌ Erreur lors de l’appel à PIXID : ' + e.getMessage());
                // Optionnel : lever une erreur si on veut que le Flow échoue
                // throw new AuraHandledException('Erreur PIXID : ' + e.getMessage());
            }
        }
    }

    public class RequestData {
        @InvocableVariable public String internal_id_tdg;
        @InvocableVariable public String account_number;
        @InvocableVariable public String customer_contact_email;
        @InvocableVariable public String customer_contact_backup_email;
        @InvocableVariable public String customer_administrator_email;
        @InvocableVariable public String customer_administrator_backup_email;
    }
}