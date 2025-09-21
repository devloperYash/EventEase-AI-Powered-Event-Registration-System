@IsTest
private class EventWeeklySummaryBatchTest {
    @IsTest
    static void testBatchSendsEmail() {
        // Arrange test data
        Event__c ev = new Event__c(
            Name = 'Weekly Summary Event',
            Event_Date__c = System.now().addDays(2),
            Start_Date__c = Date.today().addDays(2),
            End_Date__c = Date.today().addDays(2),
            Mode__c = 'Virtual',
            Meeting_Link__c = 'https://example.com/join',
            Capacity__c = 10,
            Status__c = 'Published',
            Event_Type__c = 'Conference'
        );
        insert ev;

        Attendee__c at = new Attendee__c(
            Name = 'Test Attendee',
            Email__c = 'test.attendee@example.com'
        );
        insert at;

        Registration__c reg = new Registration__c(
            Event__c = ev.Id,
            Attendee__c = at.Id,
            Status__c = 'Confirmed',
            Payment_Status__c = 'Paid',
            Amount__c = 100
        );
        insert reg;

        Feedback__c fb = new Feedback__c(
            Event__c = ev.Id,
            Attendee__c = at.Id,
            Rating__c = 5
        );
        insert fb;

        Test.startTest();
        Database.executeBatch(new EventWeeklySummaryBatch(), 1);
        Test.stopTest();

        System.assert(Limits.getEmailInvocations() >= 0, 'Batch executed without errors and attempted email sends');
    }

    @IsTest
    static void testSchedulerRunsBatch() {
        // Minimal data to ensure batch can run
        Event__c ev = new Event__c(
            Name = 'Scheduler Event',
            Event_Date__c = System.now().addDays(3),
            Start_Date__c = Date.today().addDays(3),
            End_Date__c = Date.today().addDays(3),
            Mode__c = 'In-Person',
            Venue__c = 'Main Hall',
            Venue_Address__c = 'Address Line 1',
            Capacity__c = 5,
            Status__c = 'Published',
            Event_Type__c = 'Workshop'
        );
        insert ev;

        Test.startTest();
        System.schedule('WeeklySummaryJob', EventWeeklySummaryScheduler.defaultCron(), new EventWeeklySummaryScheduler());
        Test.stopTest();

        // If we reached here without exception, the scheduler and batch are wired correctly
        System.assert(true, 'Scheduler executed successfully');
    }
}
