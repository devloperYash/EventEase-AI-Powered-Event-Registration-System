public with sharing class LowAttendanceController {
    
    @AuraEnabled(cacheable=true)
    public static List<AttendanceAlert> getLowAttendanceAlerts(Integer criticalThreshold, Integer warningThreshold, Integer lowThreshold) {
        try {
            List<Event__c> events = [
                SELECT Id, Name, Event_Type__c, Event_Date__c, Capacity__c,
                       (SELECT Id, Status__c FROM Registrations__r 
                        WHERE Status__c IN ('Confirmed', 'Approved'))
                FROM Event__c 
                WHERE Event_Date__c >= TODAY 
                AND Event_Date__c <= NEXT_N_DAYS:90
                AND Status__c != 'Cancelled'
                AND Capacity__c > 0
                ORDER BY Event_Date__c ASC
            ];
            
            List<AttendanceAlert> alerts = new List<AttendanceAlert>();
            
            for (Event__c event : events) {
                Integer registrationCount = event.Registrations__r.size();
                Integer capacity = Integer.valueOf(event.Capacity__c);
                Decimal capacityPercentage = (registrationCount * 100.0) / capacity;
                
                // Only include events below the low threshold
                if (capacityPercentage < lowThreshold) {
                    AttendanceAlert alert = new AttendanceAlert();
                    alert.eventId = event.Id;
                    alert.eventName = event.Name;
                    alert.eventType = event.Event_Type__c;
                    alert.eventDate = event.Event_Date__c?.format('MMM dd, yyyy');
                    alert.capacity = capacity;
                    alert.registrationCount = registrationCount;
                    
                    alerts.add(alert);
                }
            }
            
            return alerts;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving low attendance alerts: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String sendReminderEmails(String eventId) {
        try {
            // Get event details
            Event__c event = [
                SELECT Id, Name, Event_Date__c, Description__c
                FROM Event__c 
                WHERE Id = :eventId 
                LIMIT 1
            ];
            
            // Get leads interested in this event type
            List<Lead> interestedLeads = [
                SELECT Id, Email, FirstName, LastName
                FROM Lead 
                WHERE Event_Interest__c != null
                AND Email != null
                AND ConvertedAccountId = null
                AND Status = 'Open - Not Contacted'
                LIMIT 50
            ];
            
            // Send emails (simplified version - in production, use proper email templates)
            Integer emailsSent = 0;
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (Lead lead : interestedLeads) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[]{lead.Email});
                email.setSubject('Don\'t Miss Out: ' + event.Name);
                email.setPlainTextBody(
                    'Hi ' + lead.FirstName + ',\n\n' +
                    'We noticed you might be interested in our upcoming event: ' + event.Name + '\n' +
                    'Date: ' + event.Event_Date__c?.format('MMMM dd, yyyy') + '\n\n' +
                    'Limited seats available - register now!\n\n' +
                    'Best regards,\nEventEase Team'
                );
                emails.add(email);
            }
            
            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
                emailsSent = emails.size();
            }
            
            // Create task for follow-up
            Task followUpTask = new Task(
                Subject = 'Follow up on low attendance for ' + event.Name,
                Description = 'Sent reminder emails to ' + emailsSent + ' potential attendees. Monitor registration progress.',
                WhatId = eventId,
                ActivityDate = Date.today().addDays(3),
                Priority = 'High',
                Status = 'Not Started'
            );
            insert followUpTask;
            
            return 'Successfully sent ' + emailsSent + ' reminder emails and created follow-up task.';
            
        } catch (Exception e) {
            throw new AuraHandledException('Error sending reminder emails: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String generateAttendanceReport(List<String> eventIds) {
        try {
            List<Event__c> events = [
                SELECT Id, Name, Event_Type__c, Event_Date__c, Capacity__c,
                       (SELECT Id, Status__c, Attendee__r.Name, Attendee__r.Email__c 
                        FROM Registrations__r)
                FROM Event__c 
                WHERE Id IN :eventIds
                ORDER BY Event_Date__c ASC
            ];
            
            // Generate CSV content
            String csvContent = 'Event Name,Event Type,Event Date,Capacity,Registrations,Percentage,Status\n';
            
            for (Event__c event : events) {
                Integer registrationCount = 0;
                for (Registration__c reg : event.Registrations__r) {
                    if (reg.Status__c == 'Confirmed' || reg.Status__c == 'Approved') {
                        registrationCount++;
                    }
                }
                
                Decimal percentage = event.Capacity__c > 0 ? 
                    (registrationCount * 100.0) / event.Capacity__c : 0;
                
                String status = 'Good';
                if (percentage < 30) status = 'Critical';
                else if (percentage < 50) status = 'Warning';
                else if (percentage < 70) status = 'Low';
                
                csvContent += String.format('{0},{1},{2},{3},{4},{5}%,{6}\n', 
                    new String[]{
                        event.Name,
                        event.Event_Type__c,
                        event.Event_Date__c?.format('yyyy-MM-dd'),
                        String.valueOf(Integer.valueOf(event.Capacity__c)),
                        String.valueOf(registrationCount),
                        String.valueOf(percentage.setScale(1)),
                        status
                    });
            }
            
            return csvContent;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error generating attendance report: ' + e.getMessage());
        }
    }
    
    // Wrapper class
    public class AttendanceAlert {
        @AuraEnabled public String eventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String eventType;
        @AuraEnabled public String eventDate;
        @AuraEnabled public Integer capacity;
        @AuraEnabled public Integer registrationCount;
    }
}
