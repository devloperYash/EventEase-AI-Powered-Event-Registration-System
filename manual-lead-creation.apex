// Manual Lead Creation for Testing
// Execute this in Developer Console → Execute Anonymous

// Create test lead
Lead testLead = new Lead();
testLead.FirstName = 'Yash';
testLead.LastName = 'Test User';
testLead.Email = 'yash.test@eventease.com';
testLead.Phone = '+91 98765 43210';
testLead.Company = 'EventEase Testing Pvt Ltd';
testLead.City = 'Mumbai';
testLead.Country = 'India';
testLead.State = 'Maharashtra';
testLead.LeadSource = 'Website';
testLead.Status = 'Open - Not Contacted';

// Set Event Interest (custom field)
testLead.put('Event_Interest__c', 'Workshop');

// Set Registration Source (custom field)
testLead.put('Registration_Source__c', 'Web-to-Lead');

try {
    insert testLead;
    System.debug('✅ SUCCESS: Lead created with ID: ' + testLead.Id);
    System.debug('Lead Details: ' + testLead);
    
    // Query back to verify
    Lead createdLead = [SELECT Id, Name, Email, Event_Interest__c, Registration_Source__c 
                       FROM Lead WHERE Id = :testLead.Id];
    System.debug('✅ VERIFIED: Created Lead: ' + createdLead);
    
} catch (Exception e) {
    System.debug('❌ ERROR creating lead: ' + e.getMessage());
    System.debug('Error Details: ' + e.getStackTraceString());
}
