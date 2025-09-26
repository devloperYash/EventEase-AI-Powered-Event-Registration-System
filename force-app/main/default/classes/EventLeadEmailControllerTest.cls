@isTest
private class EventLeadEmailControllerTest {

    @isTest
    static void testSendPromotionMails_withOrWithoutEventLookup() {
        // Create an Event for context
        Event__c ev = new Event__c(Name = 'Promo Test Event', Event_Date__c = System.now());
        Map<String, Schema.SObjectField> efields = Schema.SObjectType.Event__c.fields.getMap();
        if (efields.containsKey('Start_Date__c')) ev.put('Start_Date__c', Date.today());
        if (efields.containsKey('Capacity__c')) ev.put('Capacity__c', 100);
        insert ev;

        Boolean hasEventLookup = Schema.SObjectType.Lead.fields.getMap().containsKey('Event__c');
        // Determine the org's default, unconverted initial lead status
        String initialStatus;
        List<LeadStatus> defaults = [
            SELECT MasterLabel FROM LeadStatus WHERE IsConverted = false AND IsDefault = true LIMIT 1
        ];
        if (!defaults.isEmpty()) {
            initialStatus = defaults[0].MasterLabel;
        } else {
            List<LeadStatus> anyOpen = [
                SELECT MasterLabel FROM LeadStatus WHERE IsConverted = false ORDER BY SortOrder LIMIT 1
            ];
            initialStatus = anyOpen.isEmpty() ? 'Open - Not Contacted' : anyOpen[0].MasterLabel;
        }

        if (hasEventLookup) {
            // Create three NEW leads linked to the event (set Event__c dynamically)
            List<Lead> leads = new List<Lead>{
                new Lead(LastName='L1', Company='Acme', Email='l1@example.com', Status=initialStatus),
                new Lead(LastName='L2', Company='Acme', Email='l2@example.com', Status=initialStatus),
                new Lead(LastName='L3', Company='Acme', Email='l3@example.com', Status=initialStatus)
            };
            for (Lead l : leads) {
                l.put('Event__c', ev.Id);
            }
            insert leads;

            Test.startTest();
            String msg = EventLeadEmailController.sendPromotionMails(ev.Id);
            Test.stopTest();
            System.assert(msg != null && msg.contains('Promotion mails sent to 3'), 'Unexpected message: ' + msg);
        } else {
            // If the org doesn't have Lead.Event__c, method should return guard message
            Test.startTest();
            String msg = EventLeadEmailController.sendPromotionMails(ev.Id);
            Test.stopTest();
            System.assertEquals('No new leads to promote (Event link not configured)', msg);
        }
    }

    @isTest
    static void testSendPromotionMails_noNewLeads() {
        Boolean hasEventLookup = Schema.SObjectType.Lead.fields.getMap().containsKey('Event__c');
        if (!hasEventLookup) {
            // If field not present, skip this test scenario (covered above)
            return;
        }
        // Determine initial (default unconverted) status and a different unconverted status
        String initialStatus;
        List<LeadStatus> defaults = [
            SELECT MasterLabel FROM LeadStatus WHERE IsConverted = false AND IsDefault = true LIMIT 1
        ];
        if (!defaults.isEmpty()) {
            initialStatus = defaults[0].MasterLabel;
        } else {
            List<LeadStatus> anyOpen = [
                SELECT MasterLabel FROM LeadStatus WHERE IsConverted = false ORDER BY SortOrder LIMIT 1
            ];
            initialStatus = anyOpen.isEmpty() ? 'Open - Not Contacted' : anyOpen[0].MasterLabel;
        }
        String otherOpen = null;
        for (LeadStatus ls : [SELECT MasterLabel, IsConverted FROM LeadStatus WHERE IsConverted = false ORDER BY SortOrder]) {
            if (ls.MasterLabel != initialStatus) { otherOpen = ls.MasterLabel; break; }
        }
        if (otherOpen == null) {
            // No alternate open status available; skip this scenario
            return;
        }
        Event__c ev = new Event__c(Name = 'No Leads Event', Event_Date__c = System.now());
        Map<String, Schema.SObjectField> efields2 = Schema.SObjectType.Event__c.fields.getMap();
        if (efields2.containsKey('Start_Date__c')) ev.put('Start_Date__c', Date.today());
        if (efields2.containsKey('Capacity__c')) ev.put('Capacity__c', 100);
        insert ev;

        // Create leads not matching criteria (different status)
        Lead l = new Lead(LastName='Lx', Company='Acme', Email='lx@example.com', Status=otherOpen);
        l.put('Event__c', ev.Id);
        insert l;

        Test.startTest();
        String msg = EventLeadEmailController.sendPromotionMails(ev.Id);
        Test.stopTest();

        System.assertEquals('No new leads to promote', msg);
    }
}
