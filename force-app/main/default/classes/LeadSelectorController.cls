/**
 * @description Controller for Lead Selector LWC - Search and select leads for event marketing
 * @author EventEase Development Team
 * @date 2025
 */
public with sharing class LeadSelectorController {
    
    /**
     * @description Searches leads based on criteria
     * @param searchTerm Search term for name/email
     * @param eventInterest Event interest filter
     * @param status Lead status filter
     * @param eventType Event type for matching
     * @return List of matching leads
     */
    @AuraEnabled(cacheable=false)
    public static List<Lead> searchLeads(String searchTerm, String eventInterest, String status, String eventType) {
        try {
            String query = 'SELECT Id, FirstName, LastName, Email, Company, Status, ' +
                          'Event_Interest__c, CreatedDate FROM Lead WHERE Email != null ' +
                          'AND ConvertedAccountId = null';
            
            List<String> conditions = new List<String>();
            Map<String, Object> bindVars = new Map<String, Object>();
            
            // Add search term condition
            if (String.isNotBlank(searchTerm)) {
                conditions.add('(Name LIKE :searchPattern OR Email LIKE :searchPattern)');
                bindVars.put('searchPattern', '%' + searchTerm + '%');
            }
            
            // Add status filter
            if (String.isNotBlank(status)) {
                conditions.add('Status = :leadStatus');
                bindVars.put('leadStatus', status);
            }
            
            // Add interest filter
            if (String.isNotBlank(eventInterest)) {
                conditions.add('Event_Interest__c = :interest');
                bindVars.put('interest', eventInterest);
            }
            
            // Add conditions to query
            if (!conditions.isEmpty()) {
                query += ' AND ' + String.join(conditions, ' AND ');
            }
            
            query += ' ORDER BY CreatedDate DESC LIMIT 200';
            
            // Execute dynamic query
            List<Lead> results = Database.query(query);
            
            return results;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error searching leads: ' + e.getMessage());
        }
    }
    
    /**
     * @description Sends emails to selected leads
     * @param leadIds List of selected lead IDs
     * @param eventId Event ID for the invitation
     * @return Success message
     */
    @AuraEnabled
    public static String sendEmailsToSelectedLeads(List<Id> leadIds, Id eventId) {
        try {
            if (leadIds == null || leadIds.isEmpty()) {
                throw new AuraHandledException('No leads selected for email campaign.');
            }
            
            if (eventId == null) {
                throw new AuraHandledException('Event ID is required.');
            }
            
            // Verify event exists
            List<Event__c> events = [SELECT Id, Name FROM Event__c WHERE Id = :eventId LIMIT 1];
            if (events.isEmpty()) {
                throw new AuraHandledException('Event not found.');
            }
            
            // Verify leads exist and have valid email addresses
            List<Lead> validLeads = [
                SELECT Id, FirstName, LastName, Email, Event_Interest__c
                FROM Lead 
                WHERE Id IN :leadIds 
                AND Email != null 
                AND ConvertedAccountId = null
            ];
            
            if (validLeads.isEmpty()) {
                throw new AuraHandledException('No valid leads found with email addresses.');
            }
            
            // Extract valid lead IDs
            List<Id> validLeadIds = new List<Id>();
            for (Lead lead : validLeads) {
                validLeadIds.add(lead.Id);
            }
            
            // Send emails using existing email sender
            LeadEventEmailSender.sendEventRegistrationEmails(validLeadIds, eventId);
            
            // Create activity records for tracking
            createEmailActivities(validLeadIds, eventId, events[0].Name);
            
            // Build success message
            String successMessage = '✅ SUCCESS!\n\n';
            successMessage += '📧 Event invitations sent to ' + validLeadIds.size() + ' selected leads\n';
            successMessage += '🎯 Event: ' + events[0].Name + '\n';
            successMessage += '📝 Activity records created for tracking\n\n';
            successMessage += '💡 Next steps:\n';
            successMessage += '• Monitor lead responses\n';
            successMessage += '• Check activity history on lead records\n';
            successMessage += '• Follow up with interested prospects';
            
            return successMessage;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error sending emails: ' + e.getMessage());
        }
    }
    
    /**
     * @description Gets lead statistics by interest
     * @param eventId Event ID for context
     * @return Lead statistics
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLeadStatistics(Id eventId) {
        try {
            Map<String, Object> stats = new Map<String, Object>();
            
            // Total qualified leads
            Integer totalQualified = [
                SELECT COUNT() 
                FROM Lead 
                WHERE Status = 'Qualified' 
                AND Email != null 
                AND ConvertedAccountId = null
            ];
            stats.put('totalQualified', totalQualified);
            
            // Leads by interest
            List<AggregateResult> interestStats = [
                SELECT Event_Interest__c interest, COUNT(Id) cnt 
                FROM Lead 
                WHERE Status = 'Qualified' 
                AND Email != null 
                AND ConvertedAccountId = null 
                GROUP BY Event_Interest__c
            ];
            
            Map<String, Integer> interestMap = new Map<String, Integer>();
            for (AggregateResult ar : interestStats) {
                String interest = (String)ar.get('interest');
                Integer cnt = (Integer)ar.get('cnt');
                interestMap.put(interest != null ? interest : 'No Interest', cnt);
            }
            stats.put('leadsByInterest', interestMap);
            
            // Recent leads (last 30 days)
            Integer recentLeads = [
                SELECT COUNT() 
                FROM Lead 
                WHERE Status = 'Qualified' 
                AND Email != null 
                AND ConvertedAccountId = null
                AND CreatedDate >= :Date.today().addDays(-30)
            ];
            stats.put('recentLeads', recentLeads);
            
            return stats;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving lead statistics: ' + e.getMessage());
        }
    }
    
    /**
     * @description Creates task records for email tracking
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
                emailTask.Subject = '📧 Event Invitation: ' + eventName;
                emailTask.Description = 'Event invitation email sent via Lead Selector.\n\n' +
                                      'Event: ' + eventName + '\n' +
                                      'Email Type: Targeted invitation\n' +
                                      'Sent via: EventEase Lead Selector\n' +
                                      'Content: Event details, registration instructions, contact info\n\n' +
                                      'Next steps: Monitor for lead response and follow up as needed.';
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
     * @description Gets available event interests for picklist
     * @return List of event interests
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getEventInterests() {
        try {
            List<String> interests = new List<String>();
            
            // Get picklist values from Lead.Event_Interest__c field
            Schema.DescribeFieldResult fieldResult = Lead.Event_Interest__c.getDescribe();
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            
            for (Schema.PicklistEntry entry : picklistValues) {
                if (entry.isActive()) {
                    interests.add(entry.getValue());
                }
            }
            
            return interests;
            
        } catch (Exception e) {
            // Return default interests if schema access fails
            return new List<String>{
                'Conference', 'Workshop', 'Seminar', 'Training', 
                'Networking', 'Webinar', 'Exhibition'
            };
        }
    }
}
