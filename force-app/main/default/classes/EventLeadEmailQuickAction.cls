/**
 * @description Quick Action controller for sending event emails to leads
 * @author EventEase Development Team
 * @date 2025
 */
public class EventLeadEmailQuickAction {
    
    /**
     * @description Sends event invitation emails to qualified leads
     * @param eventId The event ID from the record context
     */
    @InvocableMethod(label='Send Event Invitations to Leads' description='Sends event invitation emails to qualified leads')
    public static List<String> sendEventInvitationsToLeads(List<Id> eventIds) {
        List<String> results = new List<String>();
        
        try {
            if (eventIds == null || eventIds.isEmpty()) {
                results.add('Error: No event ID provided');
                return results;
            }
            
            Id eventId = eventIds[0];
            
            // Get event details
            List<Event__c> events = [
                SELECT Id, Name, Event_Type__c 
                FROM Event__c 
                WHERE Id = :eventId 
                LIMIT 1
            ];
            
            if (events.isEmpty()) {
                results.add('Error: Event not found');
                return results;
            }
            
            Event__c event = events[0];
            
            // Get qualified leads with matching interest or all qualified leads
            List<Lead> targetLeads = [
                SELECT Id, FirstName, LastName, Email, Event_Interest__c
                FROM Lead 
                WHERE Status = 'Qualified' 
                AND Email != null 
                AND ConvertedAccountId = null
                AND (Event_Interest__c = :event.Event_Type__c OR Event_Interest__c = null)
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            
            if (targetLeads.isEmpty()) {
                results.add('No qualified leads found for this event type. Consider updating lead statuses or interests.');
                return results;
            }
            
            // Extract lead IDs
            List<Id> leadIds = new List<Id>();
            for (Lead lead : targetLeads) {
                leadIds.add(lead.Id);
            }
            
            // Send invitations
            LeadEventEmailSender.sendEventRegistrationEmails(leadIds, eventId);
            
            // Create activity records
            createEmailActivities(leadIds, eventId, event.Name);
            
            String successMessage = 'Successfully sent event invitations to ' + leadIds.size() + 
                                   ' qualified leads for event: ' + event.Name;
            results.add(successMessage);
            
        } catch (Exception e) {
            results.add('Error sending invitations: ' + e.getMessage());
        }
        
        return results;
    }
    
    /**
     * @description Creates task records to track email activities
     * @param leadIds List of lead IDs
     * @param eventId Event ID
     * @param eventName Event name
     */
    private static void createEmailActivities(List<Id> leadIds, Id eventId, String eventName) {
        try {
            List<Task> emailTasks = new List<Task>();
            
            for (Id leadId : leadIds) {
                Task emailTask = new Task();
                emailTask.WhoId = leadId;
                emailTask.WhatId = eventId;
                emailTask.Subject = 'Event Invitation Sent: ' + eventName;
                emailTask.Description = 'Event invitation email sent via Quick Action for: ' + eventName + 
                                      '\n\nEmail includes event details and registration instructions.';
                emailTask.Status = 'Completed';
                emailTask.Priority = 'Normal';
                emailTask.ActivityDate = System.today();
                emailTask.Type = 'Email';
                
                emailTasks.add(emailTask);
            }
            
            if (!emailTasks.isEmpty()) {
                insert emailTasks;
            }
            
        } catch (Exception e) {
            System.debug('Error creating email activity tasks: ' + e.getMessage());
        }
    }
    
    /**
     * @description Gets lead count for preview (can be called from Flow)
     * @param eventIds List of event IDs
     * @return Lead count information
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getLeadCountForEvent(List<Id> eventIds) {
        List<String> results = new List<String>();
        
        try {
            if (eventIds == null || eventIds.isEmpty()) {
                results.add('No event ID provided');
                return results;
            }
            
            Id eventId = eventIds[0];
            
            // Get event details
            List<Event__c> events = [
                SELECT Id, Name, Event_Type__c 
                FROM Event__c 
                WHERE Id = :eventId 
                LIMIT 1
            ];
            
            if (events.isEmpty()) {
                results.add('Event not found');
                return results;
            }
            
            Event__c event = events[0];
            
            // Count qualified leads
            Integer leadCount = [
                SELECT COUNT() 
                FROM Lead 
                WHERE Status = 'Qualified' 
                AND Email != null 
                AND ConvertedAccountId = null
                AND (Event_Interest__c = :event.Event_Type__c OR Event_Interest__c = null)
            ];
            
            String countMessage = 'Found ' + leadCount + ' qualified leads for event: ' + event.Name;
            if (event.Event_Type__c != null) {
                countMessage += ' (matching interest: ' + event.Event_Type__c + ')';
            }
            
            results.add(countMessage);
            
        } catch (Exception e) {
            results.add('Error getting lead count: ' + e.getMessage());
        }
        
        return results;
    }
}
