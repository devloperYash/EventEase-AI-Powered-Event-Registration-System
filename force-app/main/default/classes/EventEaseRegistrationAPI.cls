/**
 * @description REST API endpoints for EventEase Registration access
 * @author EventEase Development Team
 * @date 2025
 */
@RestResource(urlMapping='/eventease/api/v1/registrations/*')
global with sharing class EventEaseRegistrationAPI {
    
    /**
     * @description GET endpoint to retrieve registrations
     * URL: /services/apexrest/eventease/api/v1/registrations
     */
    @HttpGet
    global static RegistrationResponse getRegistrations() {
        RegistrationResponse response = new RegistrationResponse();
        
        try {
            RestRequest request = RestContext.request;
            String eventId = request.params.get('eventId');
            String status = request.params.get('status');
            String limitStr = request.params.get('limit');
            
            String query = 'SELECT Id, Name, Attendee__r.Name, Attendee__r.Email__c, Attendee__r.Phone__c, ' +
                          'Event__r.Name, Registration_Date__c, Status__c, ' +
                          'Payment_Status__c ' +
                          'FROM Registration__c WHERE Id != null';
            
            if (String.isNotBlank(eventId)) {
                query += ' AND Event__c = :eventId';
            }
            if (String.isNotBlank(status)) {
                query += ' AND Status__c = :status';
            }
            
            query += ' ORDER BY Registration_Date__c DESC';
            
            Integer limitValue = String.isNotBlank(limitStr) ? Integer.valueOf(limitStr) : 100;
            query += ' LIMIT ' + limitValue;
            
            List<Registration__c> registrations = Database.query(query);
            
            List<RegistrationData> registrationDataList = new List<RegistrationData>();
            for (Registration__c reg : registrations) {
                RegistrationData regData = new RegistrationData();
                regData.id = reg.Id;
                regData.name = reg.Name;
                regData.attendeeName = reg.Attendee__r?.Name;
                regData.attendeeEmail = reg.Attendee__r?.Email__c;
                regData.attendeePhone = reg.Attendee__r?.Phone__c;
                regData.eventName = reg.Event__r?.Name;
                regData.registrationDate = reg.Registration_Date__c?.format('yyyy-MM-dd');
                regData.status = reg.Status__c;
                regData.paymentStatus = reg.Payment_Status__c;
                
                registrationDataList.add(regData);
            }
            
            response.success = true;
            response.message = 'Registrations retrieved successfully';
            response.registrations = registrationDataList;
            response.totalCount = registrationDataList.size();
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Error retrieving registrations: ' + e.getMessage();
            response.registrations = new List<RegistrationData>();
            response.totalCount = 0;
        }
        
        return response;
    }
    
    // Response wrapper classes
    global class RegistrationResponse {
        global Boolean success;
        global String message;
        global List<RegistrationData> registrations;
        global Integer totalCount;
    }
    
    global class RegistrationData {
        global String id;
        global String name;
        global String attendeeName;
        global String attendeeEmail;
        global String attendeePhone;
        global String eventName;
        global String registrationDate;
        global String status;
        global String paymentStatus;
    }
}
