/**
 * @description Sends event registration emails to leads
 * @author EventEase Development Team
 * @date 2025
 */
public class LeadEventEmailSender {
    
    /**
     * @description Sends event registration emails to leads
     * @param leadIds List of lead IDs to send emails to
     * @param eventId Optional specific event ID to promote
     */
    public static void sendEventRegistrationEmails(List<Id> leadIds, Id eventId) {
        try {
            // Query leads with required information
            List<Lead> leadsToEmail = [
                SELECT Id, FirstName, LastName, Email, Event_Interest__c
                FROM Lead 
                WHERE Id IN :leadIds 
                AND Email != null
                AND Status != 'Converted'
            ];
            
            if (leadsToEmail.isEmpty()) {
                return;
            }
            
            // Get event information
            Event__c targetEvent = null;
            List<Event__c> upcomingEvents = new List<Event__c>();
            
            if (eventId != null) {
                List<Event__c> events = [
                    SELECT Id, Name, Event_Type__c, Event_Date__c, Start_Date__c, 
                           Mode__c, Venue__c, Registration_Fee__c, Description__c
                    FROM Event__c 
                    WHERE Id = :eventId
                    LIMIT 1
                ];
                if (!events.isEmpty()) {
                    targetEvent = events[0];
                }
            } else {
                upcomingEvents = [
                    SELECT Id, Name, Event_Type__c, Event_Date__c, Start_Date__c, 
                           Mode__c, Venue__c, Registration_Fee__c, Description__c
                    FROM Event__c 
                    WHERE (Event_Date__c > :System.now() OR Start_Date__c > :System.today())
                    ORDER BY Event_Date__c ASC, Start_Date__c ASC
                    LIMIT 5
                ];
            }
            
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            
            for (Lead lead : leadsToEmail) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[]{lead.Email});
                
                if (targetEvent != null) {
                    // Send specific event invitation
                    email.setSubject('Invitation: ' + targetEvent.Name + ' - Register Now!');
                    String emailBody = buildEventInvitationEmail(lead, targetEvent);
                    String htmlBody = buildEventInvitationEmailHTML(lead, targetEvent);
                    email.setPlainTextBody(emailBody);
                    email.setHtmlBody(htmlBody);
                } else {
                    // Send general event recommendations
                    email.setSubject('Upcoming Events You Might Love - EventEase');
                    String emailBody = buildGeneralEventEmail(lead, upcomingEvents);
                    String htmlBody = buildGeneralEventEmailHTML(lead, upcomingEvents);
                    email.setPlainTextBody(emailBody);
                    email.setHtmlBody(htmlBody);
                }
                
                emails.add(email);
            }
            
            if (!emails.isEmpty() && !Test.isRunningTest()) {
                try {
                    Messaging.sendEmail(emails);
                } catch (Exception e) {
                    System.debug('Error sending event registration emails to leads: ' + e.getMessage());
                }
            }
            
        } catch (Exception e) {
            System.debug('Error in sendEventRegistrationEmails: ' + e.getMessage());
        }
    }
    
    /**
     * @description Builds specific event invitation email for lead
     * @param lead The lead
     * @param event The event to promote
     * @return Email body string
     */
    private static String buildEventInvitationEmail(Lead lead, Event__c event) {
        String leadName = (lead.FirstName != null ? lead.FirstName + ' ' : '') + lead.LastName;
        
        String emailBody = 'Dear ' + leadName + ',\n\n';
        emailBody += 'We have an exciting event that matches your interests!\n\n';
        
        emailBody += '🎯 EVENT DETAILS:\n';
        emailBody += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
        emailBody += '📌 Event: ' + event.Name + '\n';
        if (event.Event_Date__c != null) {
            emailBody += '📅 Date & Time: ' + event.Event_Date__c.format('dd/MM/yyyy h:mm a z') + '\n';
        } else if (event.Start_Date__c != null) {
            emailBody += '📅 Date: ' + event.Start_Date__c.format() + '\n';
        }
        emailBody += '📍 Mode: ' + (event.Mode__c != null ? event.Mode__c : 'TBD') + '\n';
        if (event.Registration_Fee__c != null && event.Registration_Fee__c > 0) {
            emailBody += '💰 Registration Fee: ₹' + event.Registration_Fee__c + '\n';
        } else {
            emailBody += '💰 Registration Fee: FREE\n';
        }
        if (event.Description__c != null && event.Description__c.length() > 0) {
            emailBody += '📝 Description: ' + event.Description__c + '\n';
        }
        emailBody += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
        
        emailBody += '🚀 HOW TO REGISTER:\n';
        emailBody += '1. Reply to this email with "REGISTER FOR ' + event.Name + '"\n';
        emailBody += '2. Call our registration team\n';
        emailBody += '3. Visit our EventEase portal\n\n';
        
        emailBody += '⏰ Don\'t miss out - Limited seats available!\n\n';
        emailBody += 'Looking forward to seeing you at the event!\n\n';
        emailBody += 'Best regards,\n';
        emailBody += 'EventEase Team';
        
        return emailBody;
    }
    
    /**
     * @description Builds HTML event invitation email for lead
     * @param lead The lead
     * @param event The event to promote
     * @return HTML email body
     */
    private static String buildEventInvitationEmailHTML(Lead lead, Event__c event) {
        String leadName = (lead.FirstName != null ? lead.FirstName + ' ' : '') + lead.LastName;
        
        String htmlBody = '<html><body style="font-family:Arial,sans-serif;color:#333;line-height:1.6">';
        htmlBody += '<div style="max-width:600px;margin:0 auto;padding:20px">';
        htmlBody += '<h2 style="color:#2E5AAC;margin-bottom:20px">🎯 Special Event Invitation</h2>';
        htmlBody += '<p>Dear <strong>' + leadName + '</strong>,</p>';
        htmlBody += '<p>We have an exciting event that matches your interests!</p>';
        
        htmlBody += '<div style="background:#f8f9fa;padding:25px;border-radius:10px;margin:25px 0;border-left:5px solid #2E5AAC">';
        htmlBody += '<h3 style="color:#2E5AAC;margin-top:0">' + event.Name + '</h3>';
        if (event.Event_Date__c != null) {
            htmlBody += '<p style="margin:10px 0"><strong>📅 Date & Time:</strong> ' + event.Event_Date__c.format('dd/MM/yyyy h:mm a z') + '</p>';
        } else if (event.Start_Date__c != null) {
            htmlBody += '<p style="margin:10px 0"><strong>📅 Date:</strong> ' + event.Start_Date__c.format() + '</p>';
        }
        htmlBody += '<p style="margin:10px 0"><strong>📍 Mode:</strong> ' + (event.Mode__c != null ? event.Mode__c : 'TBD') + '</p>';
        if (event.Registration_Fee__c != null && event.Registration_Fee__c > 0) {
            htmlBody += '<p style="margin:10px 0"><strong>💰 Registration Fee:</strong> ₹' + event.Registration_Fee__c + '</p>';
        } else {
            htmlBody += '<p style="margin:10px 0;color:#28a745"><strong>💰 Registration Fee:</strong> FREE</p>';
        }
        if (event.Description__c != null && event.Description__c.length() > 0) {
            htmlBody += '<p style="margin:15px 0;color:#666"><strong>📝 About:</strong> ' + event.Description__c + '</p>';
        }
        htmlBody += '</div>';
        
        htmlBody += '<div style="background:#e8f4fd;padding:20px;border-radius:8px;margin:25px 0">';
        htmlBody += '<h3 style="color:#2E5AAC;margin-top:0">🚀 How to Register</h3>';
        htmlBody += '<p style="margin:10px 0">📧 <strong>Reply to this email</strong> with "REGISTER FOR ' + event.Name + '"</p>';
        htmlBody += '<p style="margin:10px 0">📱 <strong>Call our registration team</strong> for immediate assistance</p>';
        htmlBody += '<p style="margin:10px 0">🌐 <strong>Visit our EventEase portal</strong> for online registration</p>';
        htmlBody += '</div>';
        
        htmlBody += '<div style="background:#fff3cd;padding:15px;border-radius:8px;margin:20px 0;border:1px solid #ffeaa7">';
        htmlBody += '<p style="margin:0;color:#856404"><strong>⏰ Limited Seats Available!</strong> Register now to secure your spot.</p>';
        htmlBody += '</div>';
        
        htmlBody += '<p style="margin-top:30px">Looking forward to seeing you at the event!</p>';
        htmlBody += '<p style="margin-top:20px">Best regards,<br/><strong>EventEase Team</strong></p>';
        htmlBody += '</div></body></html>';
        
        return htmlBody;
    }
    
    /**
     * @description Builds general event recommendation email for lead
     * @param lead The lead
     * @param events List of upcoming events
     * @return Email body string
     */
    private static String buildGeneralEventEmail(Lead lead, List<Event__c> events) {
        String leadName = (lead.FirstName != null ? lead.FirstName + ' ' : '') + lead.LastName;
        
        String emailBody = 'Dear ' + leadName + ',\n\n';
        emailBody += 'Thank you for your interest in EventEase! We have some exciting upcoming events.\n\n';
        
        if (!events.isEmpty()) {
            emailBody += '🎯 UPCOMING EVENTS:\n';
            emailBody += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
            
            for (Event__c event : events) {
                emailBody += '📌 ' + event.Name + '\n';
                if (event.Event_Date__c != null) {
                    emailBody += '   📅 ' + event.Event_Date__c.format('dd/MM/yyyy h:mm a') + '\n';
                } else if (event.Start_Date__c != null) {
                    emailBody += '   📅 ' + event.Start_Date__c.format() + '\n';
                }
                emailBody += '   📍 ' + (event.Mode__c != null ? event.Mode__c : 'TBD') + '\n';
                if (event.Registration_Fee__c != null && event.Registration_Fee__c > 0) {
                    emailBody += '   💰 ₹' + event.Registration_Fee__c + '\n';
                } else {
                    emailBody += '   💰 FREE\n';
                }
                emailBody += '\n';
            }
            emailBody += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n';
        }
        
        emailBody += '🚀 READY TO JOIN?\n';
        emailBody += 'Reply to this email with the event name you\'re interested in!\n\n';
        
        emailBody += '📧 Email: Reply to this message\n';
        emailBody += '📱 Phone: Contact our team\n';
        emailBody += '🌐 Web: Visit EventEase portal\n\n';
        
        emailBody += 'Don\'t miss out on these amazing opportunities!\n\n';
        emailBody += 'Best regards,\n';
        emailBody += 'EventEase Team';
        
        return emailBody;
    }
    
    /**
     * @description Builds HTML general event recommendation email for lead
     * @param lead The lead
     * @param events List of upcoming events
     * @return HTML email body
     */
    private static String buildGeneralEventEmailHTML(Lead lead, List<Event__c> events) {
        String leadName = (lead.FirstName != null ? lead.FirstName + ' ' : '') + lead.LastName;
        
        String htmlBody = '<html><body style="font-family:Arial,sans-serif;color:#333;line-height:1.6">';
        htmlBody += '<div style="max-width:600px;margin:0 auto;padding:20px">';
        htmlBody += '<h2 style="color:#2E5AAC;margin-bottom:20px">🎯 Upcoming Events Just for You!</h2>';
        htmlBody += '<p>Dear <strong>' + leadName + '</strong>,</p>';
        htmlBody += '<p>Thank you for your interest in EventEase! We have some exciting upcoming events.</p>';
        
        if (!events.isEmpty()) {
            htmlBody += '<h3 style="color:#2E5AAC;margin-top:30px">🎯 Featured Events</h3>';
            
            for (Event__c event : events) {
                htmlBody += '<div style="background:#f8f9fa;padding:20px;border-radius:8px;margin:15px 0;border-left:4px solid #2E5AAC">';
                htmlBody += '<h4 style="margin:0 0 10px;color:#2E5AAC">' + event.Name + '</h4>';
                if (event.Event_Date__c != null) {
                    htmlBody += '<p style="margin:5px 0">📅 <strong>Date:</strong> ' + event.Event_Date__c.format('dd/MM/yyyy h:mm a') + '</p>';
                } else if (event.Start_Date__c != null) {
                    htmlBody += '<p style="margin:5px 0">📅 <strong>Date:</strong> ' + event.Start_Date__c.format() + '</p>';
                }
                htmlBody += '<p style="margin:5px 0">📍 <strong>Mode:</strong> ' + (event.Mode__c != null ? event.Mode__c : 'TBD') + '</p>';
                if (event.Registration_Fee__c != null && event.Registration_Fee__c > 0) {
                    htmlBody += '<p style="margin:5px 0">💰 <strong>Fee:</strong> ₹' + event.Registration_Fee__c + '</p>';
                } else {
                    htmlBody += '<p style="margin:5px 0;color:#28a745">💰 <strong>Fee:</strong> FREE</p>';
                }
                htmlBody += '</div>';
            }
        }
        
        htmlBody += '<div style="background:#e8f4fd;padding:20px;border-radius:8px;margin:25px 0">';
        htmlBody += '<h3 style="color:#2E5AAC;margin-top:0">🚀 Ready to Join?</h3>';
        htmlBody += '<p style="margin:10px 0">📧 <strong>Reply to this email</strong> with the event name you\'re interested in</p>';
        htmlBody += '<p style="margin:10px 0">📱 <strong>Contact our team</strong> for personalized assistance</p>';
        htmlBody += '<p style="margin:10px 0">🌐 <strong>Visit EventEase portal</strong> for more events</p>';
        htmlBody += '</div>';
        
        htmlBody += '<p style="margin-top:30px"><strong>Don\'t miss out on these amazing opportunities!</strong></p>';
        htmlBody += '<p style="margin-top:20px">Best regards,<br/><strong>EventEase Team</strong></p>';
        htmlBody += '</div></body></html>';
        
        return htmlBody;
    }
}
