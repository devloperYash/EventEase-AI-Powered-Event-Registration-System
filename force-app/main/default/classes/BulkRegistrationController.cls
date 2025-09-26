public with sharing class BulkRegistrationController {
    
    @AuraEnabled(cacheable=true)
    public static List<Attendee__c> getAttendees(String searchTerm, String sortBy, String sortDirection) {
        String query = 'SELECT Id, Name, Email__c, Company__c, Job_Title__c, Interest__c, Phone__c FROM Attendee__c';
        
        // Add search filter
        if (String.isNotBlank(searchTerm)) {
            String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            query += ' WHERE (Name LIKE :searchPattern OR Email__c LIKE :searchPattern OR Company__c LIKE :searchPattern)';
        }
        
        // Add sorting
        if (String.isNotBlank(sortBy)) {
            query += ' ORDER BY ' + String.escapeSingleQuotes(sortBy);
            if (String.isNotBlank(sortDirection)) {
                query += ' ' + String.escapeSingleQuotes(sortDirection);
            }
        } else {
            query += ' ORDER BY Name ASC';
        }
        
        // Add limit
        query += ' LIMIT 1000';
        
        return Database.query(query);
    }
    
    @AuraEnabled(cacheable=true)
    public static Event__c getEventDetails(Id eventId) {
        try {
            return [
                SELECT Id, Name, Capacity__c, Attendee_Count__c, Event_Date__c, 
                       Start_Date__c, End_Date__c, Status__c, Mode__c
                FROM Event__c 
                WHERE Id = :eventId 
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Failed to retrieve event details: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static BulkRegistrationResult createBulkRegistrations(Id eventId, List<Id> attendeeIds) {
        BulkRegistrationResult result = new BulkRegistrationResult();
        
        if (attendeeIds == null || attendeeIds.isEmpty()) {
            throw new AuraHandledException('No attendees selected for registration');
        }
        
        // Validate event exists and get details
        Event__c event;
        try {
            event = [
                SELECT Id, Name, Capacity__c, Attendee_Count__c, Status__c, Start_Date__c
                FROM Event__c 
                WHERE Id = :eventId 
                LIMIT 1
            ];
        } catch (QueryException e) {
            throw new AuraHandledException('Event not found');
        }
        
        // Check registration is open and event not completed/cancelled
        if (event.Status__c == 'Registration Closed' || event.Status__c == 'Completed' || event.Status__c == 'Cancelled') {
            throw new AuraHandledException('Registrations are closed for this event');
        }
        
        // Check if event is in the future
        if (event.Start_Date__c < Date.today()) {
            throw new AuraHandledException('Cannot register attendees for past events');
        }
        
        // Check capacity
        Integer currentCount = Integer.valueOf(event.Attendee_Count__c != null ? event.Attendee_Count__c : 0);
        if (event.Capacity__c != null && (currentCount + attendeeIds.size()) > event.Capacity__c) {
            throw new AuraHandledException(
                'Registration would exceed event capacity. ' +
                'Available spots: ' + (Integer.valueOf(event.Capacity__c) - currentCount)
            );
        }
        
        // Get existing registrations to avoid duplicates
        Set<Id> existingAttendeeIds = new Set<Id>();
        for (Registration__c existing : [
            SELECT Attendee__c 
            FROM Registration__c 
            WHERE Event__c = :eventId AND Attendee__c IN :attendeeIds
        ]) {
            existingAttendeeIds.add(existing.Attendee__c);
        }
        
        // Create registrations for new attendees only
        List<Registration__c> registrationsToInsert = new List<Registration__c>();
        for (Id attendeeId : attendeeIds) {
            if (!existingAttendeeIds.contains(attendeeId)) {
                registrationsToInsert.add(new Registration__c(
                    Event__c = eventId,
                    Attendee__c = attendeeId,
                    Status__c = 'Confirmed',
                    Registration_Date__c = Date.today(),
                    Payment_Status__c = 'Pending'
                ));
            }
        }
        
        if (registrationsToInsert.isEmpty()) {
            throw new AuraHandledException('All selected attendees are already registered for this event');
        }
        
        // Insert registrations with partial success handling
        List<Database.SaveResult> saveResults = Database.insert(registrationsToInsert, false);
        
        // Process results
        for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
                result.successCount++;
            } else {
                result.failureCount++;
                // Log the error (in a real implementation, you might want to collect these)
                System.debug('Registration failed: ' + saveResults[i].getErrors());
            }
        }
        
        result.success = result.successCount > 0;
        return result;
    }

    @AuraEnabled
    public static BulkRegistrationApex.SaveResponse saveGridRows(
        Id eventId,
        List<BulkRegistrationApex.GridRow> rows,
        String defaultStatus,
        Boolean validateOnly
    ) {
        // Pre-validate event and status
        Event__c ev = [SELECT Id, Status__c, Start_Date__c FROM Event__c WHERE Id = :eventId LIMIT 1];
        if (ev.Status__c == 'Registration Closed' || ev.Status__c == 'Completed' || ev.Status__c == 'Cancelled') {
            throw new AuraHandledException('Registrations are closed for this event');
        }
        if (ev.Start_Date__c < Date.today()) {
            throw new AuraHandledException('Cannot register attendees for past events');
        }
        return BulkRegistrationApex.saveGrid(eventId, rows, defaultStatus, validateOnly);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Registration__c> getEventRegistrations(Id eventId) {
        return [
            SELECT Id, Attendee__c, Attendee__r.Name, Attendee__r.Email__c, 
                   Status__c, Registration_Date__c, Payment_Status__c, Amount__c
            FROM Registration__c 
            WHERE Event__c = :eventId 
            ORDER BY Registration_Date__c DESC
            LIMIT 1000
        ];
    }
    
    public class BulkRegistrationResult {
        @AuraEnabled public Boolean success = false;
        @AuraEnabled public Integer successCount = 0;
        @AuraEnabled public Integer failureCount = 0;
        @AuraEnabled public String message = '';
    }
}
