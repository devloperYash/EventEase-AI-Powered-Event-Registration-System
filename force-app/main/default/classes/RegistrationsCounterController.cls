public with sharing class RegistrationsCounterController {
    
    @AuraEnabled(cacheable=true)
    public static RegistrationStats getRegistrationStats(String eventId) {
        try {
            String query = 'SELECT Id, Status__c FROM Registration__c';
            List<String> conditions = new List<String>();
            
            if (String.isNotBlank(eventId)) {
                conditions.add('Event__c = :eventId');
            }
            
            if (!conditions.isEmpty()) {
                query += ' WHERE ' + String.join(conditions, ' AND ');
            }
            
            List<Registration__c> registrations = Database.query(query);
            
            RegistrationStats stats = new RegistrationStats();
            stats.totalRegistrations = registrations.size();
            
            for (Registration__c reg : registrations) {
                if (reg.Status__c == 'Confirmed' || reg.Status__c == 'Approved') {
                    stats.confirmedRegistrations++;
                } else if (reg.Status__c == 'Pending') {
                    stats.pendingRegistrations++;
                }
            }
            
            return stats;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving registration stats: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<EventCounter> getEventCounters(String eventId) {
        try {
            String query = 'SELECT Id, Name, Event_Type__c, Event_Date__c, Capacity__c, ' +
                          '(SELECT Id, Status__c FROM Registrations__r) ' +
                          'FROM Event__c';
            
            List<String> conditions = new List<String>();
            conditions.add('Event_Date__c >= TODAY');
            conditions.add('Status__c != \'Cancelled\'');
            
            if (String.isNotBlank(eventId)) {
                conditions.add('Id = :eventId');
            }
            
            query += ' WHERE ' + String.join(conditions, ' AND ');
            query += ' ORDER BY Event_Date__c ASC LIMIT 50';
            
            List<Event__c> events = Database.query(query);
            List<EventCounter> counters = new List<EventCounter>();
            
            for (Event__c event : events) {
                EventCounter counter = new EventCounter();
                counter.eventId = event.Id;
                counter.eventName = event.Name;
                counter.eventType = event.Event_Type__c;
                counter.eventDate = event.Event_Date__c?.format('MMM dd, yyyy');
                counter.capacity = Integer.valueOf(event.Capacity__c ?? 0);
                
                // Count confirmed/approved registrations
                Integer confirmedCount = 0;
                for (Registration__c reg : event.Registrations__r) {
                    if (reg.Status__c == 'Confirmed' || reg.Status__c == 'Approved') {
                        confirmedCount++;
                    }
                }
                counter.registrationCount = confirmedCount;
                
                counters.add(counter);
            }
            
            return counters;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving event counters: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Event__c> getEventOptions() {
        try {
            return [
                SELECT Id, Name 
                FROM Event__c 
                WHERE Event_Date__c >= TODAY 
                AND Status__c != 'Cancelled'
                ORDER BY Event_Date__c ASC 
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving event options: ' + e.getMessage());
        }
    }
    
    // Wrapper classes
    public class RegistrationStats {
        @AuraEnabled public Integer totalRegistrations = 0;
        @AuraEnabled public Integer confirmedRegistrations = 0;
        @AuraEnabled public Integer pendingRegistrations = 0;
    }
    
    public class EventCounter {
        @AuraEnabled public String eventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String eventType;
        @AuraEnabled public String eventDate;
        @AuraEnabled public Integer capacity;
        @AuraEnabled public Integer registrationCount;
    }
}
