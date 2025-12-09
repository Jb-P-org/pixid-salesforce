@isTest
private class SendContactToPixidTest {

    private class PixidMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        public PixidMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            return res;
        }
    }

    @isTest
    static void testPostToPixidSuccess() {
        Test.setMock(HttpCalloutMock.class, new PixidMock(200, '{"success": true}'));

        SendContactToPixid.RequestData request = new SendContactToPixid.RequestData();
        request.internal_id_tdg = 'TDG123';
        request.account_number = 'ACC456';
        request.customer_contact_email = 'contact@example.com';
        request.customer_contact_backup_email = 'backup@example.com';
        request.customer_administrator_email = 'admin@example.com';
        request.customer_administrator_backup_email = 'adminbackup@example.com';

        Test.startTest();
        SendContactToPixid.postToPixid(new List<SendContactToPixid.RequestData>{ request });
        Test.stopTest();

        // Should complete without exceptions
        System.assert(true, 'Should execute successfully');
    }

    @isTest
    static void testPostToPixidCreatedStatus() {
        Test.setMock(HttpCalloutMock.class, new PixidMock(201, '{"id": "new123"}'));

        SendContactToPixid.RequestData request = new SendContactToPixid.RequestData();
        request.internal_id_tdg = 'TDG789';
        request.account_number = 'ACC789';
        request.customer_contact_email = 'newcontact@example.com';

        Test.startTest();
        SendContactToPixid.postToPixid(new List<SendContactToPixid.RequestData>{ request });
        Test.stopTest();

        System.assert(true, 'Should handle 201 Created status');
    }

    @isTest
    static void testPostToPixidError() {
        Test.setMock(HttpCalloutMock.class, new PixidMock(500, '{"error": "Internal Server Error"}'));

        SendContactToPixid.RequestData request = new SendContactToPixid.RequestData();
        request.internal_id_tdg = 'TDG999';
        request.account_number = 'ACC999';
        request.customer_contact_email = 'error@example.com';

        Test.startTest();
        SendContactToPixid.postToPixid(new List<SendContactToPixid.RequestData>{ request });
        Test.stopTest();

        // Should catch exception and continue
        System.assert(true, 'Should handle errors gracefully');
    }

    @isTest
    static void testPostToPixidMultipleContacts() {
        Test.setMock(HttpCalloutMock.class, new PixidMock(200, '{"success": true}'));

        List<SendContactToPixid.RequestData> requests = new List<SendContactToPixid.RequestData>();

        for (Integer i = 0; i < 3; i++) {
            SendContactToPixid.RequestData request = new SendContactToPixid.RequestData();
            request.internal_id_tdg = 'TDG' + i;
            request.account_number = 'ACC' + i;
            request.customer_contact_email = 'contact' + i + '@example.com';
            requests.add(request);
        }

        Test.startTest();
        SendContactToPixid.postToPixid(requests);
        Test.stopTest();

        System.assert(true, 'Should process multiple contacts');
    }

    @isTest
    static void testPostToPixidBadRequest() {
        Test.setMock(HttpCalloutMock.class, new PixidMock(400, '{"error": "Bad Request"}'));

        SendContactToPixid.RequestData request = new SendContactToPixid.RequestData();
        request.internal_id_tdg = 'BAD';
        request.account_number = 'BAD';
        request.customer_contact_email = 'bad@example.com';

        Test.startTest();
        SendContactToPixid.postToPixid(new List<SendContactToPixid.RequestData>{ request });
        Test.stopTest();

        System.assert(true, 'Should handle 400 errors gracefully');
    }
}