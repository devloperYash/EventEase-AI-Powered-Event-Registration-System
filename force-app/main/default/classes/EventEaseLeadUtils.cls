/**
 * @description Utility class for EventEase Lead operations
 * @author EventEase Development Team
 * @date 2025
 */
public class EventEaseLeadUtils {
    
    /**
     * @description Sends event registration emails to all qualified leads
     * @param eventId Optional specific event ID to promote
     * @return Number of leads emailed
     */
    public static Integer sendEventEmailsToQualifiedLeads(Id eventId) {
        try {
            // Get qualified leads who haven't been converted yet
            List<Lead> qualifiedLeads = [
                SELECT Id, FirstName, LastName, Email, Event_Interest__c
                FROM Lead 
                WHERE Status = 'Qualified' 
                AND Email != null
                AND ConvertedAccountId = null
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            
            if (qualifiedLeads.isEmpty()) {
                System.debug('No qualified leads found for email campaign');
                return 0;
            }
            
            List<Id> leadIds = new List<Id>();
            for (Lead lead : qualifiedLeads) {
                leadIds.add(lead.Id);
            }
            
            // Send event registration emails
            LeadEventEmailSender.sendEventRegistrationEmails(leadIds, eventId);
            
            System.debug('Event registration emails sent to ' + leadIds.size() + ' qualified leads');
            return leadIds.size();
            
        } catch (Exception e) {
            System.debug('Error sending event emails to qualified leads: ' + e.getMessage());
            return 0;
        }
    }
    
    /**
     * @description Sends event invitation to specific leads
     * @param leadIds List of lead IDs
     * @param eventId Event ID to promote
     * @return Success message
     */
    public static String sendEventInvitationToLeads(List<Id> leadIds, Id eventId) {
        try {
            if (leadIds == null || leadIds.isEmpty()) {
                return 'No lead IDs provided';
            }
            
            if (eventId == null) {
                return 'Event ID is required for invitations';
            }
            
            // Verify event exists
            List<Event__c> events = [SELECT Id, Name FROM Event__c WHERE Id = :eventId LIMIT 1];
            if (events.isEmpty()) {
                return 'Event not found';
            }
            
            // Send invitations
            LeadEventEmailSender.sendEventRegistrationEmails(leadIds, eventId);
            
            return 'Event invitations sent successfully to ' + leadIds.size() + ' leads for event: ' + events[0].Name;
            
        } catch (Exception e) {
            return 'Error sending invitations: ' + e.getMessage();
        }
    }
    
    /**
     * @description Sends general event recommendations to leads
     * @param leadIds List of lead IDs
     * @return Success message
     */
    public static String sendGeneralEventRecommendations(List<Id> leadIds) {
        try {
            if (leadIds == null || leadIds.isEmpty()) {
                return 'No lead IDs provided';
            }
            
            // Send general recommendations (no specific event)
            LeadEventEmailSender.sendEventRegistrationEmails(leadIds, null);
            
            return 'General event recommendations sent successfully to ' + leadIds.size() + ' leads';
            
        } catch (Exception e) {
            return 'Error sending recommendations: ' + e.getMessage();
        }
    }
    
    /**
     * @description Gets summary of leads ready for event marketing
     * @return Lead marketing summary
     */
    public static String getLeadMarketingSummary() {
        try {
            // Count qualified leads
            Integer qualifiedCount = [SELECT COUNT() FROM Lead WHERE Status = 'Qualified' AND Email != null AND ConvertedAccountId = null];
            
            // Count leads by interest
            Map<String, Integer> leadsByInterest = new Map<String, Integer>();
            for (AggregateResult ar : [
                SELECT Event_Interest__c interest, COUNT(Id) cnt 
                FROM Lead 
                WHERE Status = 'Qualified' AND Email != null AND ConvertedAccountId = null 
                GROUP BY Event_Interest__c
            ]) {
                String interest = (String)ar.get('interest');
                Integer cnt = (Integer)ar.get('cnt');
                leadsByInterest.put(interest != null ? interest : 'No Interest Specified', cnt);
            }
            
            // Count upcoming events
            Integer upcomingEvents = [SELECT COUNT() FROM Event__c WHERE (Event_Date__c > :System.now() OR Start_Date__c > :System.today())];
            
            String summary = '📊 LEAD MARKETING SUMMARY\n';
            summary += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n';
            summary += '📈 Total Qualified Leads: ' + qualifiedCount + '\n';
            summary += '🎯 Upcoming Events: ' + upcomingEvents + '\n\n';
            
            if (!leadsByInterest.isEmpty()) {
                summary += '👥 LEADS BY INTEREST:\n';
                for (String interest : leadsByInterest.keySet()) {
                    summary += '   • ' + interest + ': ' + leadsByInterest.get(interest) + ' leads\n';
                }
            }
            
            summary += '\n💡 RECOMMENDATIONS:\n';
            if (qualifiedCount > 0 && upcomingEvents > 0) {
                summary += '   ✅ Ready for event marketing campaigns\n';
                summary += '   ✅ Use sendEventEmailsToQualifiedLeads() for bulk campaigns\n';
                summary += '   ✅ Use sendEventInvitationToLeads() for targeted invites\n';
            } else if (qualifiedCount == 0) {
                summary += '   ⚠️ No qualified leads available for marketing\n';
            } else if (upcomingEvents == 0) {
                summary += '   ⚠️ No upcoming events to promote\n';
            }
            
            return summary;
            
        } catch (Exception e) {
            return 'Error generating lead marketing summary: ' + e.getMessage();
        }
    }
}
