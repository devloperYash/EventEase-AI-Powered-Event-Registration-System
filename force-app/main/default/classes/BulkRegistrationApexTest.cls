@IsTest
private class BulkRegistrationApexTest {

    private static Event__c makeEvent(Integer capacity) {
        Event__c e = new Event__c(
            Name = 'Test Event ' + String.valueOf(Crypto.getRandomInteger()),
            Start_Date__c = Date.today().addDays(7),
            Capacity__c = capacity
        );
        insert e;
        return e;
    }

    private static BulkRegistrationApex.GridRow makeRow(String name, String email, String phone, String status) {
        BulkRegistrationApex.GridRow r = new BulkRegistrationApex.GridRow();
        r.id = 'cid-' + String.valueOf(Crypto.getRandomInteger());
        r.name = name;
        r.email = email;
        r.phone = phone;
        r.ticketType = 'General';
        r.status = status;
        return r;
    }

    @IsTest
    static void testValidateAndSaveRows_success() {
        Event__c e = makeEvent(10);
        List<BulkRegistrationApex.GridRow> rows = new List<BulkRegistrationApex.GridRow>();
        rows.add(makeRow('Alice', 'alice@test.com', '1234567890', 'Confirmed'));

        Test.startTest();
        BulkRegistrationApex.SaveResponse validateResp = BulkRegistrationApex.saveGrid(e.Id, rows, 'Pending', true);
        Test.stopTest();
        System.assertEquals(0, validateResp.errors, 'No validation errors expected');

        Test.startTest();
        BulkRegistrationApex.SaveResponse saveResp = BulkRegistrationApex.saveGrid(e.Id, rows, 'Pending', false);
        Test.stopTest();
        System.assertEquals(true, saveResp.success, 'Save should succeed');
        System.assertEquals(1, saveResp.registrationInserts, 'One registration should be inserted');

        Integer regCount = [SELECT COUNT() FROM Registration__c WHERE Event__c = :e.Id];
        System.assertEquals(1, regCount);
    }

    @IsTest
    static void testCapacityExceeded_validateOnly() {
        Event__c e = makeEvent(0);
        List<BulkRegistrationApex.GridRow> rows = new List<BulkRegistrationApex.GridRow>();
        rows.add(makeRow('Bob', 'bob@test.com', '9999999999', 'Confirmed'));

        Test.startTest();
        BulkRegistrationApex.SaveResponse resp = BulkRegistrationApex.saveGrid(e.Id, rows, 'Pending', true);
        Test.stopTest();
        System.assertEquals(false, resp.success, 'Validate should fail due to capacity');
        System.assert(resp.messages != null && resp.messages.size() > 0, 'Expect capacity warning message');
    }

    @IsTest
    static void testDuplicateRegistration_detected() {
        Event__c e = makeEvent(10);
        Attendee__c a = new Attendee__c(Name = 'Charlie', Email__c = 'charlie@test.com');
        insert a;
        Registration__c reg = new Registration__c(Event__c = e.Id, Attendee__c = a.Id, Status__c = 'Confirmed', Payment_Status__c = 'Pending');
        insert reg;

        List<BulkRegistrationApex.GridRow> rows = new List<BulkRegistrationApex.GridRow>();
        rows.add(makeRow('Charlie', 'charlie@test.com', '8888888888', 'Confirmed'));

        Test.startTest();
        BulkRegistrationApex.SaveResponse resp = BulkRegistrationApex.saveGrid(e.Id, rows, 'Pending', false);
        Test.stopTest();
        System.assertEquals(0, resp.registrationInserts, 'No new registrations should be inserted');
        System.assertEquals(1, resp.duplicates, 'Duplicate should be detected');
    }

    @IsTest
    static void testClosedRegistration_guard() {
        Event__c e = makeEvent(5);
        e.Status__c = 'Registration Closed';
        update e;
        List<BulkRegistrationApex.GridRow> rows = new List<BulkRegistrationApex.GridRow>();
        rows.add(makeRow('Dana', 'dana@test.com', '7777777777', 'Pending'));

        Boolean threw = false;
        Test.startTest();
        try {
            BulkRegistrationApex.saveGrid(e.Id, rows, 'Pending', true);
        } catch (AuraHandledException ex) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw, 'Should block when registration is closed');
    }
}
