public with sharing class TopRatedEventsController {
    
    @AuraEnabled(cacheable=true)
    public static List<TopRatedEvent> getTopRatedEvents(String timeRange, String eventType, Integer minFeedbackCount) {
        try {
            Date startDate = calculateStartDate(timeRange);
            
            // 1) Query candidate events
            String evtQuery = 'SELECT Id, Name, Event_Type__c, Event_Date__c ' +
                              'FROM Event__c WHERE Status__c = \'Completed\'';
            List<String> evtConds = new List<String>();
            if (startDate != null) {
                evtConds.add('Event_Date__c >= :startDate');
            }
            if (String.isNotBlank(eventType)) {
                evtConds.add('Event_Type__c = :eventType');
            }
            if (!evtConds.isEmpty()) {
                evtQuery += ' AND ' + String.join(evtConds, ' AND ');
            }
            evtQuery += ' ORDER BY Event_Date__c DESC LIMIT 100';
            List<Event__c> events = Database.query(evtQuery);

            if (events.isEmpty()) {
                return new List<TopRatedEvent>();
            }

            Set<Id> eventIds = new Set<Id>();
            for (Event__c e : events) eventIds.add(e.Id);

            // 2) Aggregate feedback by event (average rating and count)
            Map<Id, AggregateResult> feedbackAggByEvent = new Map<Id, AggregateResult>();
            for (AggregateResult ar : [
                SELECT Event__c eId, AVG(Rating__c) avgRating, COUNT(Id) fbCount
                FROM Feedback__c
                WHERE Event__c IN :eventIds AND Rating__c != null
                GROUP BY Event__c
            ]) {
                feedbackAggByEvent.put((Id)ar.get('eId'), ar);
            }

            // 3) Aggregate confirmed/approved registrations per event
            Map<Id, Integer> confirmedRegsByEvent = new Map<Id, Integer>();
            for (AggregateResult ar : [
                SELECT Event__c eId, COUNT(Id) regCount
                FROM Registration__c
                WHERE Event__c IN :eventIds AND Status__c IN ('Confirmed','Approved')
                GROUP BY Event__c
            ]) {
                confirmedRegsByEvent.put((Id)ar.get('eId'), (Integer)ar.get('regCount'));
            }

            // 4) Build result list (filter by minFeedbackCount)
            List<TopRatedEvent> topEvents = new List<TopRatedEvent>();
            for (Event__c ev : events) {
                AggregateResult fbAgg = feedbackAggByEvent.get(ev.Id);
                if (fbAgg == null) continue; // no feedback
                Integer fbCount = (Integer)fbAgg.get('fbCount');
                if (minFeedbackCount != null && fbCount < minFeedbackCount) continue;

                TopRatedEvent tr = new TopRatedEvent();
                tr.eventId = ev.Id;
                tr.eventName = ev.Name;
                tr.eventType = ev.Event_Type__c;
                tr.eventDate = ev.Event_Date__c != null ? ev.Event_Date__c.format('MMM dd, yyyy') : null;
                tr.feedbackCount = fbCount;
                tr.averageRating = ((Decimal)fbAgg.get('avgRating')).setScale(1);
                tr.attendeeCount = confirmedRegsByEvent.containsKey(ev.Id) ? confirmedRegsByEvent.get(ev.Id) : 0;
                topEvents.add(tr);
            }

            // 5) Sort by rating desc, then feedback count desc
            topEvents.sort(new TopRatedEventComparator());
            return topEvents;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving top rated events: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static RatingStatistics getRatingStatistics(String timeRange, String eventType) {
        try {
            Date startDate = calculateStartDate(timeRange);

            // Build dynamic aggregate for overall feedback
            String fbQuery = 'SELECT AVG(Rating__c) avgRating, COUNT(Id) totalFb ' +
                             'FROM Feedback__c WHERE Event__r.Status__c = \'Completed\'';
            if (startDate != null) {
                fbQuery += ' AND Event__r.Event_Date__c >= :startDate';
            }
            if (!String.isBlank(eventType)) {
                fbQuery += ' AND Event__r.Event_Type__c = :eventType';
            }
            AggregateResult overall = Database.query(fbQuery);

            // Build dynamic aggregate for confirmed/approved registrations
            String regQuery = 'SELECT COUNT(Id) totalRegs FROM Registration__c ' +
                              'WHERE Status__c IN (\'Confirmed\',\'Approved\') ' +
                              'AND Event__r.Status__c = \'Completed\'';
            if (startDate != null) {
                regQuery += ' AND Event__r.Event_Date__c >= :startDate';
            }
            if (!String.isBlank(eventType)) {
                regQuery += ' AND Event__r.Event_Type__c = :eventType';
            }
            AggregateResult regs = Database.query(regQuery);

            // Count events with average rating >= 4.0
            String highQuery = 'SELECT Event__c eId, AVG(Rating__c) avgR ' +
                               'FROM Feedback__c WHERE Event__r.Status__c = \'Completed\'';
            if (startDate != null) {
                highQuery += ' AND Event__r.Event_Date__c >= :startDate';
            }
            if (!String.isBlank(eventType)) {
                highQuery += ' AND Event__r.Event_Type__c = :eventType';
            }
            highQuery += ' GROUP BY Event__c HAVING AVG(Rating__c) >= 4.0';
            List<AggregateResult> highResults = Database.query(highQuery);

            RatingStatistics stats = new RatingStatistics();
            Decimal avgR = (Decimal)overall.get('avgRating');
            Integer totalFb = (Integer)overall.get('totalFb');
            Integer totalRegs = (Integer)regs.get('totalRegs');

            stats.averageRating = (totalFb != null && totalFb > 0 && avgR != null) ? avgR.setScale(1) : 0;
            stats.totalFeedback = (totalFb != null) ? totalFb : 0;
            stats.highRatedEvents = highResults != null ? highResults.size() : 0;
            stats.responseRate = (totalRegs != null && totalRegs > 0) ? Integer.valueOf((stats.totalFeedback * 100.0) / totalRegs) : 0;
            return stats;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving rating statistics: ' + e.getMessage());
        }
    }
    
    private static Date calculateStartDate(String timeRange) {
        if (String.isBlank(timeRange) || timeRange == 'all') {
            return null;
        }
        
        Integer days = Integer.valueOf(timeRange);
        return Date.today().addDays(-days);
    }
    
    // Wrapper classes
    public class TopRatedEvent {
        @AuraEnabled public String eventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String eventType;
        @AuraEnabled public String eventDate;
        @AuraEnabled public Decimal averageRating;
        @AuraEnabled public Integer feedbackCount;
        @AuraEnabled public Integer attendeeCount;
    }
    
    public class RatingStatistics {
        @AuraEnabled public Decimal averageRating;
        @AuraEnabled public Integer totalFeedback;
        @AuraEnabled public Integer highRatedEvents;
        @AuraEnabled public Integer responseRate;
    }
    
    // Comparator for sorting by rating
    public class TopRatedEventComparator implements Comparator<TopRatedEvent> {
        public Integer compare(TopRatedEvent a, TopRatedEvent b) {
            if (a.averageRating > b.averageRating) return -1;
            if (a.averageRating < b.averageRating) return 1;
            // If ratings are equal, sort by feedback count
            if (a.feedbackCount > b.feedbackCount) return -1;
            if (a.feedbackCount < b.feedbackCount) return 1;
            return 0;
        }
    }
}
