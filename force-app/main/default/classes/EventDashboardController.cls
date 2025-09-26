/**
 * @description Apex controller powering the Event Dashboard LWC (stats, quick actions)
 * @author EventEase
 * @date 2025
 */
public with sharing class EventDashboardController {

    // Wrapper for dashboard stats
    public class EventStats {
        @AuraEnabled public Id eventId;
        @AuraEnabled public String name;
        @AuraEnabled public Datetime eventDate;
        @AuraEnabled public Date startDate;
        @AuraEnabled public String mode;
        @AuraEnabled public String status;
        @AuraEnabled public Integer capacity;
        @AuraEnabled public Integer attendeeCount; // confirmed/approved count persisted on Event
        @AuraEnabled public Integer totalRegistrations;
        @AuraEnabled public Integer confirmed;
        @AuraEnabled public Integer pending;
        @AuraEnabled public Integer cancelled;
        @AuraEnabled public Integer feedbackCount;
        @AuraEnabled public Map<String, Integer> registrationsByStatus;
    }

    // Simple HTML escape helper for safe email HTML content
    private static String html(String s) {
        if (s == null) return '';
        String out = s;
        out = out.replace('&', '&amp;');
        out = out.replace('<', '&lt;');
        out = out.replace('>', '&gt;');
        out = out.replace('"', '&quot;');
        out = out.replace('\'', '&#39;');
        return out;
    }

    /**
     * @description Returns quick stats for an event including registrations breakdown and feedback count
     */
    @AuraEnabled(cacheable=true)
    public static EventStats getEventStats(Id eventId) {
        if (eventId == null) {
            throw new AuraHandledException('Event Id is required');
        }

        EventStats stats = new EventStats();

        // Load event
        Event__c ev = [
            SELECT Id, Name, Capacity__c, Attendee_Count__c, Status__c, Mode__c, Event_Date__c, Start_Date__c
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        stats.eventId = ev.Id;
        stats.name = ev.Name;
        stats.capacity = ev.Capacity__c == null ? null : ev.Capacity__c.intValue();
        stats.attendeeCount = ev.Attendee_Count__c == null ? 0 : ev.Attendee_Count__c.intValue();
        stats.status = ev.Status__c;
        stats.mode = ev.Mode__c;
        stats.eventDate = ev.Event_Date__c;
        stats.startDate = ev.Start_Date__c;

        // Registrations breakdown by Status
        stats.registrationsByStatus = new Map<String, Integer>();
        Integer total = 0;
        for (AggregateResult ar : [
            SELECT Status__c s, COUNT(Id) c
            FROM Registration__c
            WHERE Event__c = :eventId
            GROUP BY Status__c
        ]) {
            String s = (String) ar.get('s');
            Integer c = (Integer) ar.get('c');
            stats.registrationsByStatus.put(s != null ? s : 'Unknown', c);
            total += c;
        }
        stats.totalRegistrations = total;
        stats.confirmed = stats.registrationsByStatus.containsKey('Confirmed') ? stats.registrationsByStatus.get('Confirmed') : 0;
        stats.pending = stats.registrationsByStatus.containsKey('Pending') ? stats.registrationsByStatus.get('Pending') : 0;
        stats.cancelled = stats.registrationsByStatus.containsKey('Cancelled') ? stats.registrationsByStatus.get('Cancelled') : 0;

        // Feedback count
        stats.feedbackCount = [SELECT COUNT() FROM Feedback__c WHERE Event__c = :eventId];

        return stats;
    }

    /**
     * @description Closes registrations for the event by setting Status__c = 'Registration Closed'
     */
    @AuraEnabled
    public static String closeRegistrations(Id eventId) {
        if (eventId == null) {
            throw new AuraHandledException('Event Id is required');
        }
        List<Event__c> events = [SELECT Id, Status__c FROM Event__c WHERE Id = :eventId LIMIT 1];
        if (events.isEmpty()) {
            throw new AuraHandledException('Event not found');
        }
        Event__c ev = events[0];
        if (ev.Status__c == 'Completed' || ev.Status__c == 'Cancelled') {
            throw new AuraHandledException('Cannot change registration status for completed or cancelled events');
        }
        ev.Status__c = 'Registration Closed';
        update ev;
        return 'Registrations closed for this event.';
    }

    /**
     * @description Sends reminder emails to attendees for an event.
     * @param eventId The event Id
     * @param target Optional target group: 'PendingPayment' (default) or 'AllConfirmed'
     */
    @AuraEnabled
    public static String sendReminderEmails(Id eventId, String target) {
        if (eventId == null) {
            throw new AuraHandledException('Event Id is required');
        }
        String tgt = String.isBlank(target) ? 'PendingPayment' : target;

        // Get event for context
        Event__c ev = [SELECT Id, Name, Event_Date__c, Start_Date__c, Mode__c, Meeting_Link__c, Venue__c, Venue_Address__c
                        FROM Event__c WHERE Id = :eventId LIMIT 1];

        List<Registration__c> regs;
        if (tgt == 'PendingPayment') {
            regs = [
                SELECT Id, Name, Status__c, Payment_Status__c, Attendee__r.Email__c, Attendee__r.Name
                FROM Registration__c
                WHERE Event__c = :eventId AND Status__c = 'Confirmed' AND Payment_Status__c = 'Pending'
            ];
        } else if (tgt == 'AllConfirmed') {
            regs = [
                SELECT Id, Name, Status__c, Payment_Status__c, Attendee__r.Email__c, Attendee__r.Name
                FROM Registration__c
                WHERE Event__c = :eventId AND Status__c = 'Confirmed'
            ];
        } else {
            regs = [
                SELECT Id, Name, Status__c, Payment_Status__c, Attendee__r.Email__c, Attendee__r.Name
                FROM Registration__c
                WHERE Event__c = :eventId
            ];
        }
        if (regs.isEmpty()) {
            return 'No matching registrations found for reminders.';
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Registration__c r : regs) {
            String toEmail = r.Attendee__r != null ? r.Attendee__r.Email__c : null;
            String toName = r.Attendee__r != null ? r.Attendee__r.Name : null;
            if (String.isBlank(toEmail)) continue;

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new String[] { toEmail });
            msg.setSubject('Reminder: ' + ev.Name + ' - Complete Your Registration');

            String greeting = 'Hello' + (String.isNotBlank(toName) ? ' ' + toName : '') + ',\n\n';
            String reminderBody = 'This is a friendly reminder for the event: ' + ev.Name + '.\n\n';
            if (tgt == 'PendingPayment' && r.Payment_Status__c == 'Pending') {
                reminderBody += 'Our records show your payment is pending. Please complete payment to secure your spot.\n';
            } else {
                reminderBody += 'Please review your registration details.\n';
            }
            reminderBody += '\nEvent Details:\n';
            if (ev.Event_Date__c != null) {
                reminderBody += '- Event Date/Time: ' + ev.Event_Date__c.format('dd/MM/yyyy h:mm a z') + '\n';
            } else if (ev.Start_Date__c != null) {
                reminderBody += '- Start Date: ' + ev.Start_Date__c.format() + '\n';
            }
            if (ev.Mode__c == 'Virtual') {
                reminderBody += '- Mode: Virtual\n';
                reminderBody += '- Join Link: Will be shared after confirmation and payment completion\n';
            } else {
                reminderBody += '- Mode: In-Person\n';
            }
            reminderBody += '\nThank you,\nEventEase Team';

            msg.setPlainTextBody(greeting + reminderBody);

            String html = '<html><body style="font-family:Arial,Helvetica,sans-serif; color:#111"'
                + '<h2 style="color:#2E5AAC;margin:0 0 10px">Registration Reminder</h2>'
                + '<p>' + html('Hello' + (String.isNotBlank(toName) ? ' ' + toName : '' )) + ',</p>'
                + '<p>This is a friendly reminder for the event: <b>' + html(ev.Name) + '</b>.</p>'
                + (tgt == 'PendingPayment' && r.Payment_Status__c == 'Pending' ? '<p>Please complete your payment to secure your spot.</p>' : '<p>Please review your registration details.</p>')
                + '<h3 style="margin:16px 0 8px">Event Details</h3>'
                + '<ul>'
                +   (ev.Event_Date__c != null ? '<li><b>Event Date/Time:</b> ' + html(ev.Event_Date__c.format('dd/MM/yyyy h:mm a z')) + '</li>' : (ev.Start_Date__c != null ? '<li><b>Start Date:</b> ' + html(ev.Start_Date__c.format()) + '</li>' : ''))
                +   (ev.Mode__c == 'Virtual' ? '<li><b>Mode:</b> Virtual</li>' : '<li><b>Mode:</b> In-Person</li>')
                + '<p>Thank you,<br/>EventEase Team</p>'
                + '</body></html>';
            msg.setHtmlBody(html);

            emails.add(msg);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
        return 'Sent ' + emails.size() + ' reminder email(s).';
    }
}
