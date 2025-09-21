public with sharing class EventWeeklySummaryBatch implements Database.Batchable<SObject>, Database.Stateful {
    private static final Set<String> COUNTING_STATUSES = new Set<String>{ 'Confirmed', 'Approved' };

    // Accumulator grouped by Event Owner
    private Map<Id, List<EventSummary>> byOwner = new Map<Id, List<EventSummary>>();

    public class EventSummary {
        public Id eventId;
        public String name;
        public Datetime eventDate;
        public Integer confirmedCount;
        public Integer feedbackCount;
        public Decimal avgRating;
        public EventSummary(Id eventId, String name, Datetime eventDate) {
            this.eventId = eventId;
            this.name = name;
            this.eventDate = eventDate;
            this.confirmedCount = 0;
            this.feedbackCount = 0;
            this.avgRating = null;
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Weekly window: include events in the last 7 days and next 7 days
        String soql = 'SELECT Id, Name, OwnerId, Event_Date__c ' +
                      'FROM Event__c ' +
                      'WHERE Event_Date__c = LAST_N_DAYS:7 OR Event_Date__c = NEXT_N_DAYS:7';
        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext bc, List<Event__c> scope) {
        if (scope == null || scope.isEmpty()) return;
        Set<Id> eventIds = new Set<Id>();
        Map<Id, Event__c> evMap = new Map<Id, Event__c>();
        for (Event__c e : scope) {
            eventIds.add(e.Id);
            evMap.put(e.Id, e);
        }

        // Registrations confirmed in the last 7 days per event
        Map<Id, Integer> regCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Event__c e, COUNT(Id) c
            FROM Registration__c
            WHERE Event__c IN :eventIds
              AND Status__c IN :COUNTING_STATUSES
              AND CreatedDate = LAST_N_DAYS:7
            GROUP BY Event__c
        ]) {
            regCounts.put((Id) ar.get('e'), (Integer) ar.get('c'));
        }

        // Feedback counts and average rating in the last 7 days per event
        Map<Id, Integer> fbCounts = new Map<Id, Integer>();
        Map<Id, Decimal> fbAvg = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Event__c e, COUNT(Id) cnt, AVG(Rating__c) avgR
            FROM Feedback__c
            WHERE Event__c IN :eventIds AND CreatedDate = LAST_N_DAYS:7
            GROUP BY Event__c
        ]) {
            Id eId = (Id) ar.get('e');
            fbCounts.put(eId, (Integer) ar.get('cnt'));
            fbAvg.put(eId, (Decimal) ar.get('avgR'));
        }

        // Build summaries grouped by owner
        for (Event__c e : scope) {
            EventSummary sum = new EventSummary(e.Id, e.Name, e.Event_Date__c);
            if (regCounts.containsKey(e.Id)) sum.confirmedCount = regCounts.get(e.Id);
            if (fbCounts.containsKey(e.Id)) sum.feedbackCount = fbCounts.get(e.Id);
            if (fbAvg.containsKey(e.Id)) sum.avgRating = fbAvg.get(e.Id);

            List<EventSummary> listForOwner = byOwner.get(e.OwnerId);
            if (listForOwner == null) {
                listForOwner = new List<EventSummary>();
                byOwner.put(e.OwnerId, listForOwner);
            }
            listForOwner.add(sum);
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (byOwner.isEmpty()) return;
        Map<Id, User> ownerUsers = new Map<Id, User>([
            SELECT Id, Name, Email, TimeZoneSidKey FROM User WHERE Id IN :byOwner.keySet()
        ]);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Id ownerId : byOwner.keySet()) {
            User u = ownerUsers.get(ownerId);
            if (u == null || String.isBlank(u.Email)) continue;

            List<EventSummary> rows = byOwner.get(ownerId);
            if (rows == null || rows.isEmpty()) continue;

            String subject = 'Weekly Event Summary - EventEase';
            String body = 'Hello ' + u.Name + ',\n\n' +
                          'Here is your weekly event summary (last 7 days activity and next 7 days schedule):\n\n';

            rows.sort(new Comparator());
            for (EventSummary s : rows) {
                body += '- ' + s.name + (s.eventDate != null ? ' | ' + s.eventDate.format('dd/MM/yyyy h:mm a z') : '') + '\n'
                     +  '  Confirmed Registrations (last 7 days): ' + String.valueOf(s.confirmedCount) + '\n'
                     +  '  Feedback (last 7 days): ' + String.valueOf(s.feedbackCount) + (s.avgRating != null ? ' | Avg Rating: ' + String.valueOf(s.avgRating.setScale(2)) : '') + '\n\n';
            }
            body += 'Regards,\nEventEase Bot';

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new String[] { u.Email });
            msg.setSubject(subject);
            msg.setPlainTextBody(body);
            emails.add(msg);
        }
        if (!emails.isEmpty()) {
            try { Messaging.sendEmail(emails, false); } catch (Exception ex) { /* ignore */ }
        }
    }

    // Sort by upcoming event date first
    public class Comparator implements System.Comparator<EventSummary> {
        public Integer compare(EventSummary a, EventSummary b) {
            if (a.eventDate == null && b.eventDate == null) return 0;
            if (a.eventDate == null) return 1;
            if (b.eventDate == null) return -1;
            return a.eventDate.getTime() < b.eventDate.getTime() ? -1 : (a.eventDate.getTime() > b.eventDate.getTime() ? 1 : 0);
        }
    }
}
