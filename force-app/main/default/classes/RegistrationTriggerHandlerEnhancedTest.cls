@IsTest
private class RegistrationTriggerHandlerEnhancedTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test attendees
        List<Attendee__c> attendees = new List<Attendee__c>();
        for (Integer i = 1; i <= 5; i++) {
            attendees.add(new Attendee__c(
                Name = 'Test Attendee ' + i,
                Email__c = 'attendee' + i + '@test.com',
                Interest__c = 'Technology'
            ));
        }
        insert attendees;
        
        // Create test events
        List<Event__c> events = new List<Event__c>();
        events.add(new Event__c(
            Name = 'Future Event with Capacity',
            Capacity__c = 3,
            Start_Date__c = Date.today().addDays(10),
            Event_Date__c = System.now().addDays(10)
        ));
        events.add(new Event__c(
            Name = 'Past Event',
            Capacity__c = 5,
            Start_Date__c = Date.today().addDays(-5),
            Event_Date__c = System.now().addDays(-5)
        ));
        events.add(new Event__c(
            Name = 'No Capacity Event',
            Start_Date__c = Date.today().addDays(15),
            Event_Date__c = System.now().addDays(15)
        ));
        events.add(new Event__c(
            Name = 'Another Future Event',
            Capacity__c = 5,
            Start_Date__c = Date.today().addDays(20),
            Event_Date__c = System.now().addDays(20)
        ));
        insert events;
    }
    
    @IsTest
    static void testBulkStatusChangesAndCounting() {
        List<Attendee__c> attendees = [SELECT Id FROM Attendee__c LIMIT 3];
        Event__c event = [SELECT Id FROM Event__c WHERE Name = 'Future Event with Capacity' LIMIT 1];
        
        // Create registrations in Pending status
        List<Registration__c> registrations = new List<Registration__c>();
        for (Attendee__c att : attendees) {
            registrations.add(new Registration__c(
                Attendee__c = att.Id,
                Event__c = event.Id,
                Status__c = 'Pending'
            ));
        }
        
        Test.startTest();
        insert registrations;
        
        // Verify count is 0 (Pending doesn't count)
        event = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event.Id];
        System.assertEquals(0, event.Attendee_Count__c, 'Count should be 0 for Pending registrations');
        
        // Bulk update to Confirmed
        for (Registration__c reg : registrations) {
            reg.Status__c = 'Confirmed';
        }
        update registrations;
        
        // Verify count increased to 3
        event = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event.Id];
        System.assertEquals(3, event.Attendee_Count__c, 'Count should be 3 after confirming all registrations');
        
        // Change one to Cancelled
        registrations[0].Status__c = 'Cancelled';
        update registrations[0];
        
        // Verify count decreased to 2
        event = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event.Id];
        System.assertEquals(2, event.Attendee_Count__c, 'Count should be 2 after cancelling one registration');
        
        // Change one to Approved (should still count)
        registrations[1].Status__c = 'Approved';
        update registrations[1];
        
        // Verify count remains 2
        event = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event.Id];
        System.assertEquals(2, event.Attendee_Count__c, 'Count should remain 2 (Approved still counts)');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testCapacityEnforcementWithMixedOperations() {
        List<Attendee__c> attendees = [SELECT Id FROM Attendee__c];
        Event__c event = [SELECT Id FROM Event__c WHERE Name = 'Future Event with Capacity' LIMIT 1];
        
        // Create 2 confirmed registrations (within capacity of 3)
        List<Registration__c> initialRegs = new List<Registration__c>();
        for (Integer i = 0; i < 2; i++) {
            initialRegs.add(new Registration__c(
                Attendee__c = attendees[i].Id,
                Event__c = event.Id,
                Status__c = 'Confirmed'
            ));
        }
        insert initialRegs;
        
        // Verify count is 2
        event = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event.Id];
        System.assertEquals(2, event.Attendee_Count__c, 'Initial count should be 2');
        
        Test.startTest();
        
        // Try to add 2 more confirmed (should fail - would exceed capacity)
        List<Registration__c> excessRegs = new List<Registration__c>();
        for (Integer i = 2; i < 4; i++) {
            excessRegs.add(new Registration__c(
                Attendee__c = attendees[i].Id,
                Event__c = event.Id,
                Status__c = 'Confirmed'
            ));
        }
        
        Boolean caughtException = false;
        try {
            insert excessRegs;
        } catch (DmlException ex) {
            caughtException = true;
            System.assert(ex.getMessage().contains('capacity exceeded'), 
                'Should get capacity exceeded error');
        }
        System.assert(caughtException, 'Should have caught capacity exception');
        
        // Cancel one existing registration, then add one new confirmed (should work)
        initialRegs[0].Status__c = 'Cancelled';
        update initialRegs[0];
        
        Registration__c newReg = new Registration__c(
            Attendee__c = attendees[2].Id,
            Event__c = event.Id,
            Status__c = 'Confirmed'
        );
        insert newReg; // Should succeed
        
        // Verify final count is 2
        event = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event.Id];
        System.assertEquals(2, event.Attendee_Count__c, 'Final count should be 2');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testEventChangeScenarios() {
        List<Attendee__c> attendees = [SELECT Id FROM Attendee__c LIMIT 2];
        List<Event__c> events = [SELECT Id FROM Event__c WHERE Name LIKE '%Future%' OR Name LIKE '%No Capacity%'];
        Event__c event1 = events[0];
        Event__c event2 = events[1];
        
        Test.startTest();
        
        // Create registration for event1
        Registration__c reg1 = new Registration__c(
            Attendee__c = attendees[0].Id,
            Event__c = event1.Id,
            Status__c = 'Confirmed'
        );
        insert reg1;
        
        // Verify event1 count is 1
        event1 = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event1.Id];
        System.assertEquals(1, event1.Attendee_Count__c, 'Event1 count should be 1');
        
        // Create another registration for event2 (cannot move existing due to master-detail)
        Registration__c reg2 = new Registration__c(
            Attendee__c = attendees[1].Id,
            Event__c = event2.Id,
            Status__c = 'Confirmed'
        );
        insert reg2;
        
        // Verify both events have correct counts
        event1 = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event1.Id];
        event2 = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event2.Id];
        
        System.assertEquals(1, event1.Attendee_Count__c, 'Event1 count should remain 1');
        System.assertEquals(1, event2.Attendee_Count__c, 'Event2 count should be 1');
        
        // Verify composite keys are correct
        List<Registration__c> regs = [SELECT Id, Attendee_Event_Key__c, Attendee__c, Event__c FROM Registration__c WHERE Id IN (:reg1.Id, :reg2.Id)];
        for (Registration__c r : regs) {
            String expectedKey = String.valueOf(r.Attendee__c) + '|' + String.valueOf(r.Event__c);
            System.assertEquals(expectedKey, r.Attendee_Event_Key__c, 'Composite key should be correctly populated');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testPastEventValidation() {
        List<Attendee__c> attendees = [SELECT Id FROM Attendee__c LIMIT 1];
        Event__c pastEvent = [SELECT Id FROM Event__c WHERE Name = 'Past Event' LIMIT 1];
        
        Test.startTest();
        
        // Create pending registration for past event (should work now)
        Registration__c reg = new Registration__c(
            Attendee__c = attendees[0].Id,
            Event__c = pastEvent.Id,
            Status__c = 'Pending'
        );
        
        // This should succeed as Pending status is allowed for past events
        insert reg;
        System.assertNotEquals(null, reg.Id, 'Pending registration should be created for past event');
        
        // Try to update to confirmed (should fail due to validation rules)
        reg.Status__c = 'Confirmed';
        Boolean caughtException = false;
        try {
            update reg;
        } catch (DmlException ex) {
            caughtException = true;
            System.assert(ex.getMessage().contains('past event') || ex.getMessage().contains('past events'), 
                'Should get past event error on update to Confirmed: ' + ex.getMessage());
        }
        System.assert(caughtException, 'Should have caught past event exception on update to Confirmed');
        
        // Try to create confirmed registration directly for past event (should fail)
        Registration__c reg2 = new Registration__c(
            Attendee__c = attendees[0].Id,
            Event__c = pastEvent.Id,
            Status__c = 'Confirmed'
        );
        
        caughtException = false;
        try {
            insert reg2;
        } catch (DmlException ex) {
            caughtException = true;
            System.assert(ex.getMessage().contains('past event') || ex.getMessage().contains('past events'), 
                'Should get past event error on direct Confirmed insert: ' + ex.getMessage());
        }
        System.assert(caughtException, 'Should have caught past event exception on direct Confirmed insert');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testCompositeKeyDuplicatePrevention() {
        List<Attendee__c> attendees = [SELECT Id FROM Attendee__c LIMIT 1];
        Event__c event = [SELECT Id FROM Event__c WHERE Name = 'Future Event with Capacity' LIMIT 1];
        
        // Create first registration
        Registration__c reg1 = new Registration__c(
            Attendee__c = attendees[0].Id,
            Event__c = event.Id,
            Status__c = 'Pending'
        );
        insert reg1;
        
        Test.startTest();
        
        // Try to create duplicate registration
        Registration__c reg2 = new Registration__c(
            Attendee__c = attendees[0].Id,
            Event__c = event.Id,
            Status__c = 'Confirmed'
        );
        
        Boolean caughtException = false;
        try {
            insert reg2;
        } catch (DmlException ex) {
            caughtException = true;
            System.assert(ex.getMessage().contains('duplicate'), 
                'Should get duplicate error due to unique composite key');
        }
        System.assert(caughtException, 'Should have caught duplicate exception');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testDeleteAndUndeleteScenarios() {
        List<Attendee__c> attendees = [SELECT Id FROM Attendee__c LIMIT 2];
        Event__c event = [SELECT Id FROM Event__c WHERE Name = 'Future Event with Capacity' LIMIT 1];
        
        // Create confirmed registrations
        List<Registration__c> regs = new List<Registration__c>();
        for (Integer i = 0; i < 2; i++) {
            regs.add(new Registration__c(
                Attendee__c = attendees[i].Id,
                Event__c = event.Id,
                Status__c = 'Confirmed'
            ));
        }
        insert regs;
        
        // Verify count is 2
        event = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event.Id];
        System.assertEquals(2, event.Attendee_Count__c, 'Count should be 2 after insert');
        
        Test.startTest();
        
        // Delete one registration
        delete regs[0];
        
        // Verify count decreased to 1
        event = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event.Id];
        System.assertEquals(1, event.Attendee_Count__c, 'Count should be 1 after delete');
        
        // Undelete the registration
        undelete regs[0];
        
        // Verify count increased back to 2
        event = [SELECT Attendee_Count__c FROM Event__c WHERE Id = :event.Id];
        System.assertEquals(2, event.Attendee_Count__c, 'Count should be 2 after undelete');
        
        Test.stopTest();
    }
    
    @IsTest
    static void testMasterDetailConstraints() {
        List<Attendee__c> attendees = [SELECT Id FROM Attendee__c LIMIT 2];
        List<Event__c> events = [SELECT Id FROM Event__c WHERE Name LIKE '%Future%' ORDER BY Name];
        
        // Ensure we have at least 2 events and 2 attendees
        System.assert(events.size() >= 2, 'Need at least 2 future events for this test. Found: ' + events.size());
        System.assert(attendees.size() >= 2, 'Need at least 2 attendees for this test. Found: ' + attendees.size());
        
        // Create registration
        Registration__c reg = new Registration__c(
            Attendee__c = attendees[0].Id,
            Event__c = events[0].Id,
            Status__c = 'Confirmed'
        );
        insert reg;
        
        Test.startTest();
        
        // Verify that master-detail relationships are properly established
        reg = [SELECT Id, Attendee__c, Event__c, Status__c FROM Registration__c WHERE Id = :reg.Id];
        System.assertEquals(attendees[0].Id, reg.Attendee__c, 'Attendee relationship should be established');
        System.assertEquals(events[0].Id, reg.Event__c, 'Event relationship should be established');
        
        // Test that status changes work (this is what should be updatable)
        reg.Status__c = 'Cancelled';
        update reg; // Should succeed
        
        reg = [SELECT Status__c FROM Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Cancelled', reg.Status__c, 'Status should be updatable');
        
        // Change back to Confirmed to test count updates
        reg.Status__c = 'Confirmed';
        update reg; // Should succeed
        
        reg = [SELECT Status__c FROM Registration__c WHERE Id = :reg.Id];
        System.assertEquals('Confirmed', reg.Status__c, 'Status should be updatable back to Confirmed');
        
        // Verify that we cannot create duplicate registrations (composite key constraint)
        Registration__c duplicateReg = new Registration__c(
            Attendee__c = attendees[0].Id,
            Event__c = events[0].Id,
            Status__c = 'Pending'
        );
        
        Boolean caughtDuplicateException = false;
        try {
            insert duplicateReg;
        } catch (DmlException ex) {
            caughtDuplicateException = true;
            System.assert(ex.getMessage().contains('duplicate') || ex.getMessage().contains('DUPLICATE'), 
                'Should get duplicate error: ' + ex.getMessage());
        }
        System.assert(caughtDuplicateException, 'Should have caught duplicate exception due to composite key');
        
        Test.stopTest();
    }
}
