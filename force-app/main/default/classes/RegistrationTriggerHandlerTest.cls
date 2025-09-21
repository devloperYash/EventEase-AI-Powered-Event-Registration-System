@IsTest
private class RegistrationTriggerHandlerTest {
    @IsTest
    static void testCapacityAndCountsAndCompositeKey() {
        // Create Attendees
        Attendee__c a1 = new Attendee__c(Name = 'Att One', Email__c = 'a1@example.com', Interest__c = 'Technology');
        Attendee__c a2 = new Attendee__c(Name = 'Att Two', Email__c = 'a2@example.com', Interest__c = 'Business');
        Attendee__c a3 = new Attendee__c(Name = 'Att Three', Email__c = 'a3@example.com', Interest__c = 'Technology');
        insert new List<Attendee__c>{ a1, a2, a3 };

        // Create Event with capacity 2 and future start date
        Event__c ev = new Event__c(
            Name = 'Test Event',
            Capacity__c = 2,
            Start_Date__c = Date.today().addDays(5),
            Event_Date__c = System.now().addDays(5)
        );
        insert ev;

        // Insert first confirmed registration
        Registration__c r1 = new Registration__c(
            Attendee__c = a1.Id,
            Event__c = ev.Id,
            Status__c = 'Confirmed'
        );
        // Insert second confirmed registration
        Registration__c r2 = new Registration__c(
            Attendee__c = a2.Id,
            Event__c = ev.Id,
            Status__c = 'Confirmed'
        );

        Test.startTest();
        insert new List<Registration__c>{ r1, r2 };
        Test.stopTest();

        // Event count should now be 2
        ev = [SELECT Id, Attendee_Count__c FROM Event__c WHERE Id = :ev.Id];
        System.assertEquals(2, (Integer)ev.Attendee_Count__c, 'Attendee count should be 2 after two confirmed registrations');

        // Composite key should be populated automatically
        List<Registration__c> regs = [SELECT Id, Attendee_Event_Key__c FROM Registration__c WHERE Event__c = :ev.Id ORDER BY CreatedDate ASC];
        System.assertEquals(2, regs.size());
        System.assertNotEquals(null, regs[0].Attendee_Event_Key__c, 'Composite key should be populated');
        System.assertNotEquals('', regs[0].Attendee_Event_Key__c, 'Composite key should be populated');

        // Third confirmed registration should fail due to capacity
        Registration__c r3 = new Registration__c(
            Attendee__c = a3.Id,
            Event__c = ev.Id,
            Status__c = 'Confirmed'
        );
        Boolean caught = false;
        try {
            insert r3;
        } catch (DmlException ex) {
            caught = true;
            System.assert(ex.getMessage().contains('Event capacity exceeded'), 'Should block over-capacity registration');
        }
        System.assertEquals(true, caught, 'Expected DmlException for over capacity');

        // Update one confirmed to cancelled -> count decrements to 1
        regs = [SELECT Id, Status__c FROM Registration__c WHERE Event__c = :ev.Id LIMIT 1];
        Registration__c toCancel = regs[0];
        toCancel.Status__c = 'Cancelled';

        update toCancel;

        ev = [SELECT Id, Attendee_Count__c FROM Event__c WHERE Id = :ev.Id];
        System.assertEquals(1, (Integer)ev.Attendee_Count__c, 'Attendee count should decrement to 1 after cancelling a registration');

        // Delete the other confirmed -> count decrements to 0
        regs = [SELECT Id FROM Registration__c WHERE Event__c = :ev.Id];
        delete regs;

        ev = [SELECT Id, Attendee_Count__c FROM Event__c WHERE Id = :ev.Id];
        System.assertEquals(0, (Integer)ev.Attendee_Count__c, 'Attendee count should be 0 after deleting remaining registrations');
    }
}
