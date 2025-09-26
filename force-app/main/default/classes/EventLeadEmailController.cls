/**
 * @description LWC controller for Event Lead Email workflows (details, lead query, send invitations)
 */
public with sharing class EventLeadEmailController {

    /**
     * @description Returns the org's default, unconverted initial Lead Status label.
     */
    private static String getInitialLeadStatus() {
        // Prefer the default unconverted status
        List<LeadStatus> defaults = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = false AND IsDefault = true
            LIMIT 1
        ];
        if (!defaults.isEmpty()) {
            return defaults[0].MasterLabel;
        }
        // Fallback: first unconverted by sort order
        List<LeadStatus> anyOpen = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = false
            ORDER BY SortOrder
            LIMIT 1
        ];
        if (!anyOpen.isEmpty()) {
            return anyOpen[0].MasterLabel;
        }
        // Ultimate fallback
        return 'Open - Not Contacted';
    }

    @AuraEnabled(cacheable=true)
    public static Event__c getEventDetails(Id eventId) {
        if (eventId == null) {
            throw new AuraHandledException('Event Id is required');
        }
        try {
            return [
                SELECT Id, Name, Event_Date__c, Start_Date__c, Mode__c, Registration_Fee__c
                FROM Event__c
                WHERE Id = :eventId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Failed to retrieve event details: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Lead> getLeadsForEvent(Id eventId, String status, String interest) {
        // Optional: use event type as default interest filter
        String eventType = null;
        if (eventId != null) {
            for (Event__c ev : [SELECT Event_Type__c FROM Event__c WHERE Id = :eventId LIMIT 1]) {
                eventType = ev.Event_Type__c;
            }
        }

        String base = 'SELECT Id, FirstName, LastName, Email, Company, Status, Event_Interest__c, CreatedDate '
                    + 'FROM Lead WHERE Email != null AND ConvertedAccountId = null';

        // Status filter
        if (!String.isBlank(status)) {
            base += ' AND Status = :status';
        } else {
            base += ' AND Status IN (\'New\', \'Working\', \'Qualified\', \'Nurturing\')';
        }
        // Interest filter (explicit parameter takes precedence, otherwise use event type if present, else no filter)
        if (!String.isBlank(interest)) {
            base += ' AND Event_Interest__c = :interest';
        } else if (!String.isBlank(eventType)) {
            base += ' AND (Event_Interest__c = :eventType OR Event_Interest__c = null)';
        }
        base += ' ORDER BY CreatedDate DESC LIMIT 200';

        return Database.query(base);
    }

    @AuraEnabled
    public static String sendEventInvitations(List<Id> leadIds, Id eventId) {
        if (leadIds == null || leadIds.isEmpty()) {
            throw new AuraHandledException('No leads selected');
        }
        if (eventId == null) {
            throw new AuraHandledException('Event Id is required');
        }
        try {
            LeadEventEmailSender.sendEventRegistrationEmails(leadIds, eventId);
            return 'Invitations sent to ' + leadIds.size() + ' lead(s).';
        } catch (Exception e) {
            throw new AuraHandledException('Failed to send invitations: ' + e.getMessage());
        }
    }

    /**
     * @description Sends promotion emails to all New Leads linked to the given Event. Optionally updates status to 'Contacted'.
     */
    @AuraEnabled
    public static String sendPromotionMails(Id eventId) {
        if (eventId == null) {
            throw new AuraHandledException('Event Id is required');
        }

        // Load event context
        Event__c ev = [
            SELECT Id, Name, Event_Date__c, Start_Date__c
            FROM Event__c
            WHERE Id = :eventId
            LIMIT 1
        ];

        // Build dynamic query for "New" leads, optionally filtered by Event__c if field exists
        Boolean hasEventLookup = Schema.SObjectType.Lead.fields.getMap().containsKey('Event__c');
        if (!hasEventLookup) {
            return 'No new leads to promote (Event link not configured)';
        }
        String initialStatus = getInitialLeadStatus();
        String q = 'SELECT Id, FirstName, LastName, Email, Status FROM Lead WHERE '
                 + 'Status = :initialStatus AND Email != null AND ConvertedAccountId = null';
        q += ' AND Event__c = :eventId';
        q += ' LIMIT 500';
        List<Lead> leads = Database.query(q);

        if (leads.isEmpty()) {
            return 'No new leads to promote';
        }

        // Compose emails
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Date eventDate = ev.Event_Date__c != null ? ev.Event_Date__c.date() : ev.Start_Date__c;
        String eventDateStr = eventDate != null ? eventDate.format() : 'TBD';

        for (Lead l : leads) {
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new String[] { l.Email });
            msg.setSubject('Invitation to ' + ev.Name);
            String greeting = 'Hello' + (String.isNotBlank(l.FirstName) ? ' ' + l.FirstName : '') + ',\n\n';
            String body = greeting
                        + 'You are invited to our upcoming event: ' + ev.Name + '.\n'
                        + 'Event Date: ' + eventDateStr + '\n\n'
                        + 'We would love to have you join us. Please reply to this email or visit the event page to register.\n\n'
                        + 'Best regards,\nEventEase Team';
            msg.setPlainTextBody(body);
            emails.add(msg);
        }

        // Send emails in small batches to respect platform limits (e.g., 10 messages per call)
        if (!emails.isEmpty()) {
            Integer chunkSize = 10;
            for (Integer i = 0; i < emails.size(); i += chunkSize) {
                Integer endIndex = Math.min(i + chunkSize, emails.size());
                List<Messaging.SingleEmailMessage> batch = new List<Messaging.SingleEmailMessage>();
                for (Integer j = i; j < endIndex; j++) {
                    batch.add(emails[j]);
                }
                Messaging.sendEmail(batch, false);
            }
        }

        // Optionally update lead status to a valid value ('Contacted' preferred, fallback to 'Working')
        String newStatus;
        Set<String> validStatuses = new Set<String>();
        Schema.DescribeFieldResult dfr = Lead.Status.getDescribe();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            validStatuses.add(pe.getValue());
        }
        if (validStatuses.contains('Contacted')) {
            newStatus = 'Contacted';
        } else if (validStatuses.contains('Working')) {
            newStatus = 'Working';
        }
        if (newStatus != null) {
            for (Lead l : leads) {
                l.Status = newStatus;
            }
            try {
                update leads;
            } catch (DmlException de) {
                // Swallow softly; email already sent. Still return success count.
                System.debug('Failed to update lead statuses: ' + de.getMessage());
            }
        }

        return 'Promotion mails sent to ' + leads.size() + ' new leads.';
    }

    /**
     * @description Returns up to maxRecords 'New' leads linked to the given Event for preview.
     */
    @AuraEnabled(cacheable=true)
    public static List<Lead> getNewLeadsForEvent(Id eventId, Integer maxRecords) {
        if (eventId == null) {
            throw new AuraHandledException('Event Id is required');
        }
        Integer lim = (maxRecords == null || maxRecords <= 0 || maxRecords > 50) ? 10 : maxRecords;

        // Pull the event's type (category) to optionally match with Lead.Event_Interest__c
        String eventType = null;
        try {
            Event__c evType = [SELECT Event_Type__c FROM Event__c WHERE Id = :eventId LIMIT 1];
            eventType = evType.Event_Type__c;
        } catch (Exception e) {
            // If not present, we'll skip interest-based filtering
        }

        Boolean hasEventLookup = Schema.SObjectType.Lead.fields.getMap().containsKey('Event__c');
        String initialStatus = getInitialLeadStatus();
        String q = 'SELECT Id, FirstName, LastName, Email, Company, Status, CreatedDate '
                 + 'FROM Lead WHERE Status = :initialStatus AND Email != null AND ConvertedAccountId = null';
        if (hasEventLookup && !String.isBlank(eventType)) {
            q += ' AND (Event__c = :eventId OR Event_Interest__c = :eventType)';
        } else if (hasEventLookup) {
            q += ' AND Event__c = :eventId';
        } else if (!String.isBlank(eventType)) {
            q += ' AND Event_Interest__c = :eventType';
        }
        q += ' ORDER BY CreatedDate DESC LIMIT :lim';
        return Database.query(q);
    }
}
