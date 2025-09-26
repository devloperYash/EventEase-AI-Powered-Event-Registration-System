/**
 * @description Converts Leads to Attendees for EventEase system
 * @author EventEase Development Team
 * @date 2025
 */
public class LeadToAttendeeConverter {
    
    /**
     * @description Converts qualified leads to attendees
     * @param leadIds List of Lead IDs to convert
     * @return Map of Lead ID to Attendee ID
     */
    public static Map<Id, Id> convertLeadsToAttendees(List<Id> leadIds) {
        Map<Id, Id> leadToAttendeeMap = new Map<Id, Id>();
        
        try {
            // Query leads with required information
            List<Lead> leadsToConvert = [
                SELECT Id, FirstName, LastName, Email, Phone, Company, 
                       Event_Interest__c, Registration_Source__c
                FROM Lead 
                WHERE Id IN :leadIds 
                AND Status = 'Qualified'
                AND ConvertedAccountId = null
            ];
            
            if (leadsToConvert.isEmpty()) {
                return leadToAttendeeMap;
            }
            
            // Create attendees from leads
            List<Attendee__c> attendeesToInsert = new List<Attendee__c>();
            
            for (Lead lead : leadsToConvert) {
                Attendee__c attendee = new Attendee__c();
                attendee.Name = (lead.FirstName != null ? lead.FirstName + ' ' : '') + lead.LastName;
                attendee.Email__c = lead.Email;
                attendee.Phone__c = lead.Phone;
                attendee.Company__c = lead.Company;
                attendee.Interest__c = lead.Event_Interest__c; // Map Event Interest
                // Note: Registration_Source__c moved to Lead object, tracking via Lead_Source__c
                attendee.Lead_Source__c = lead.Id; // Track original lead
                
                attendeesToInsert.add(attendee);
            }
            
            // Insert attendees
            if (!attendeesToInsert.isEmpty()) {
                insert attendeesToInsert;
                
                // Build return map
                for (Integer i = 0; i < leadsToConvert.size(); i++) {
                    leadToAttendeeMap.put(leadsToConvert[i].Id, attendeesToInsert[i].Id);
                }
                
                // Update lead status to converted
                updateLeadStatus(leadIds);
                
                // Send welcome emails
                sendWelcomeEmails(attendeesToInsert);
            }
            
        } catch (Exception e) {
            System.debug('Error converting leads to attendees: ' + e.getMessage());
            throw new LeadConversionException('Failed to convert leads: ' + e.getMessage());
        }
        
        return leadToAttendeeMap;
    }
    
    /**
     * @description Updates lead status after conversion
     * @param leadIds List of converted lead IDs
     */
    private static void updateLeadStatus(List<Id> leadIds) {
        List<Lead> leadsToUpdate = new List<Lead>();
        
        for (Id leadId : leadIds) {
            Lead lead = new Lead(Id = leadId);
            lead.Status = 'Converted - Attendee Created';
            lead.Converted_Date__c = System.now();
            leadsToUpdate.add(lead);
        }
        
        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }
    }
    
    /**
     * @description Sends welcome emails with event registration links to new attendees
     * @param attendees List of new attendees
     */
    private static void sendWelcomeEmails(List<Attendee__c> attendees) {
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        // Get upcoming events based on attendee interests
        Map<String, List<Event__c>> eventsByInterest = getUpcomingEventsByInterest();
        
        for (Attendee__c attendee : attendees) {
            if (attendee.Email__c != null) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[]{attendee.Email__c});
                email.setSubject('Welcome to EventEase - Explore Upcoming Events');
                
                String emailBody = buildWelcomeEmailWithEvents(attendee, eventsByInterest);
                String htmlBody = buildWelcomeEmailHTMLWithEvents(attendee, eventsByInterest);
                
                email.setPlainTextBody(emailBody);
                email.setHtmlBody(htmlBody);
                emails.add(email);
            }
        }
        
        if (!emails.isEmpty() && !Test.isRunningTest()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug('Error sending welcome emails: ' + e.getMessage());
            }
        }
    }
    
    /**
     * @description Gets upcoming events grouped by interest
     * @return Map of interest to events
     */
    private static Map<String, List<Event__c>> getUpcomingEventsByInterest() {
        Map<String, List<Event__c>> eventsByInterest = new Map<String, List<Event__c>>();
        
        List<Event__c> upcomingEvents = [
            SELECT Id, Name, Event_Type__c, Event_Date__c, Start_Date__c, 
                   Mode__c, Venue__c, Registration_Fee__c, Description__c
            FROM Event__c 
            WHERE (Event_Date__c > :System.now() OR Start_Date__c > :System.today())
            AND Status__c != 'Cancelled'
            ORDER BY Event_Date__c ASC, Start_Date__c ASC
            LIMIT 10
        ];
        
        for (Event__c event : upcomingEvents) {
            String eventType = event.Event_Type__c != null ? event.Event_Type__c : 'General';
            
            if (!eventsByInterest.containsKey(eventType)) {
                eventsByInterest.put(eventType, new List<Event__c>());
            }
            eventsByInterest.get(eventType).add(event);
        }
        
        return eventsByInterest;
    }
    
    /**
     * @description Builds welcome email body with event recommendations
     * @param attendee The attendee
     * @param eventsByInterest Map of events by interest
     * @return Email body string
     */
    private static String buildWelcomeEmailWithEvents(Attendee__c attendee, Map<String, List<Event__c>> eventsByInterest) {
        String emailBody = 'Dear ' + attendee.Name + ',\n\n';
        emailBody += 'Welcome to EventEase! We\'re excited to have you join our community.\n\n';
        
        // Add personalized event recommendations
        String attendeeInterest = attendee.Interest__c != null ? attendee.Interest__c : 'General';
        List<Event__c> recommendedEvents = eventsByInterest.get(attendeeInterest);
        
        if (recommendedEvents != null && !recommendedEvents.isEmpty()) {
            emailBody += 'Based on your interest in ' + attendeeInterest + ', here are some upcoming events you might like:\n\n';
            
            for (Event__c event : recommendedEvents) {
                emailBody += '🎯 ' + event.Name + '\n';
                if (event.Event_Date__c != null) {
                    emailBody += '   📅 Date: ' + event.Event_Date__c.format('dd/MM/yyyy h:mm a') + '\n';
                } else if (event.Start_Date__c != null) {
                    emailBody += '   📅 Date: ' + event.Start_Date__c.format() + '\n';
                }
                emailBody += '   📍 Mode: ' + (event.Mode__c != null ? event.Mode__c : 'TBD') + '\n';
                if (event.Registration_Fee__c != null && event.Registration_Fee__c > 0) {
                    emailBody += '   💰 Fee: ₹' + event.Registration_Fee__c + '\n';
                } else {
                    emailBody += '   💰 Fee: Free\n';
                }
                emailBody += '   🔗 Register: Contact us to register for this event\n\n';
            }
        } else {
            emailBody += 'Here are some upcoming events you might be interested in:\n\n';
            // Show general events
            for (String interest : eventsByInterest.keySet()) {
                List<Event__c> events = eventsByInterest.get(interest);
                if (events != null && !events.isEmpty()) {
                    Event__c event = events[0]; // Show first event from each category
                    emailBody += '🎯 ' + event.Name + ' (' + interest + ')\n';
                    emailBody += '   📅 Date: ' + (event.Event_Date__c != null ? event.Event_Date__c.format('dd/MM/yyyy') : event.Start_Date__c.format()) + '\n';
                    emailBody += '   🔗 Contact us to register\n\n';
                    break; // Show only one example
                }
            }
        }
        
        emailBody += 'To register for any event or get more information:\n';
        emailBody += '📧 Reply to this email\n';
        emailBody += '📱 Contact our team\n';
        emailBody += '🌐 Visit our EventEase portal\n\n';
        
        emailBody += 'You will receive event notifications and updates at this email address.\n\n';
        emailBody += 'Thank you for your interest!\n\n';
        emailBody += 'Best regards,\n';
        emailBody += 'EventEase Team';
        
        return emailBody;
    }
    
    /**
     * @description Builds HTML welcome email with event recommendations
     * @param attendee The attendee
     * @param eventsByInterest Map of events by interest
     * @return HTML email body
     */
    private static String buildWelcomeEmailHTMLWithEvents(Attendee__c attendee, Map<String, List<Event__c>> eventsByInterest) {
        String htmlBody = '<html><body style="font-family:Arial,sans-serif;color:#333;line-height:1.6">';
        htmlBody += '<div style="max-width:600px;margin:0 auto;padding:20px">';
        htmlBody += '<h2 style="color:#2E5AAC;margin-bottom:20px">Welcome to EventEase! 🎉</h2>';
        htmlBody += '<p>Dear <strong>' + attendee.Name + '</strong>,</p>';
        htmlBody += '<p>We\'re excited to have you join our community of event enthusiasts!</p>';
        
        // Add personalized event recommendations
        String attendeeInterest = attendee.Interest__c != null ? attendee.Interest__c : 'General';
        List<Event__c> recommendedEvents = eventsByInterest.get(attendeeInterest);
        
        if (recommendedEvents != null && !recommendedEvents.isEmpty()) {
            htmlBody += '<h3 style="color:#2E5AAC;margin-top:30px">🎯 Recommended Events for You</h3>';
            htmlBody += '<div style="background:#f8f9fa;padding:20px;border-radius:8px;margin:20px 0">';
            
            for (Event__c event : recommendedEvents) {
                htmlBody += '<div style="border-left:4px solid #2E5AAC;padding-left:15px;margin-bottom:20px">';
                htmlBody += '<h4 style="margin:0 0 10px 0;color:#2E5AAC">' + event.Name + '</h4>';
                htmlBody += '<p style="margin:5px 0">🎪 <strong>Type:</strong> ' + (event.Event_Type__c != null ? event.Event_Type__c : 'Event') + '</p>';
                
                if (event.Start_Date__c != null) {
                    htmlBody += '<p style="margin:5px 0">📅 <strong>Date:</strong> ' + event.Start_Date__c.format() + '</p>';
                }
                htmlBody += '<p style="margin:5px 0">📍 <strong>Mode:</strong> ' + (event.Mode__c != null ? event.Mode__c : 'TBD') + '</p>';
                if (event.Registration_Fee__c != null && event.Registration_Fee__c > 0) {
                    htmlBody += '<p style="margin:5px 0">💰 <strong>Fee:</strong> ₹' + event.Registration_Fee__c + '</p>';
                } else {
                    htmlBody += '<p style="margin:5px 0">💰 <strong>Fee:</strong> Free</p>';
                }
                if (event.Description__c != null) {
                    htmlBody += '<p style="margin:10px 0;color:#666">' + event.Description__c.substring(0, Math.min(100, event.Description__c.length())) + '...</p>';
                }
                htmlBody += '</div>';
            }
            htmlBody += '</div>';
        }
        
        htmlBody += '<h3 style="color:#2E5AAC;margin-top:30px">🚀 How to Register</h3>';
        htmlBody += '<div style="background:#e8f4fd;padding:20px;border-radius:8px;margin:20px 0">';
        htmlBody += '<p style="margin:10px 0">📧 <strong>Reply to this email</strong> with the event name you\'re interested in</p>';
        htmlBody += '<p style="margin:10px 0">📱 <strong>Contact our team</strong> for personalized assistance</p>';
        htmlBody += '<p style="margin:10px 0">🌐 <strong>Visit our EventEase portal</strong> for more events</p>';
        htmlBody += '</div>';
        
        htmlBody += '<p style="margin-top:30px">You will receive event notifications and updates at this email address.</p>';
        htmlBody += '<p><strong>Thank you for your interest!</strong></p>';
        htmlBody += '<p style="margin-top:30px">Best regards,<br/><strong>EventEase Team</strong></p>';
        htmlBody += '</div></body></html>';
        
        return htmlBody;
    }
    
    /**
     * @description Batch converts all qualified leads
     * @return Number of leads converted
     */
    public static Integer batchConvertQualifiedLeads() {
        List<Lead> qualifiedLeads = [
            SELECT Id 
            FROM Lead 
            WHERE Status = 'Qualified' 
            AND Email != null 
            AND Converted_Date__c = null
            LIMIT 100
        ];
        
        if (!qualifiedLeads.isEmpty()) {
            List<Id> leadIds = new List<Id>();
            for (Lead lead : qualifiedLeads) {
                leadIds.add(lead.Id);
            }
            
            Map<Id, Id> conversionResults = convertLeadsToAttendees(leadIds);
            return conversionResults.size();
        }
        
        return 0;
    }
    
    /**
     * @description Custom exception for lead conversion errors
     */
    public class LeadConversionException extends Exception {}
}
