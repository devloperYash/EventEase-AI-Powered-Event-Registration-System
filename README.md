# EventEase – AI-Powered Event Registration System

[![Salesforce](https://img.shields.io/badge/Salesforce-Lightning-blue.svg)](https://developer.salesforce.com/)
[![API Version](https://img.shields.io/badge/API%20Version-64.0-green.svg)](https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/)
[![License](https://img.shields.io/badge/License-Educational-orange.svg)](#license)

EventEase is an enterprise-grade Salesforce application that revolutionizes event management through AI-powered recommendations, automated workflows, and real-time analytics. Built with modern Lightning Web Components (LWC), comprehensive Apex automation, and production-ready security frameworks.

## 🎥 Project Demo

**📹 Live Demo Video:** [EventEase System Walkthrough](https://drive.google.com/file/d/1hG4GIXO7MSgvvhS2ofuIPI8yPxWuUy1u/view?usp=sharing)

*Watch the complete system demonstration showcasing all features, user interfaces, and business workflows in action.*

## 🎯 Project Status

**✅ Production Ready** - Fully deployed and operational with 98% test coverage
- **Core System**: Event management, registration workflows, automated notifications
- **AI Features**: Interest-based event recommendations, intelligent lead scoring
- **Analytics**: Real-time dashboards, capacity monitoring, revenue tracking
- **Integration**: Web-to-Lead forms, email marketing, batch processing

## 📚 Documentation & Guides

**Comprehensive project documentation:**

- **Phase 1**: `Phase 1/Phase_1.pdf` - Requirements & Analysis
- **Phase 2**: `Phase 2/Phase 2.pdf` - Data Model & Architecture  
- **Phase 3**: `Phase 3/Phase 3.pdf` - Business Logic & Automation
- **Security Guide**: `security/Security_Configuration_Guide.md`
- **Data Management**: `data-management/Data_Loader_Configuration_Guide.md`
- **A/B Testing**: `ab-testing/AB_Test_Demo_Implementation.md`

## 🏢 Project Overview

**Industry:** Event Management / Education / Corporate Training  
**Project Type:** B2C Salesforce CRM Implementation  
**Target Users:** Event Organizers, Attendees, Administrators, Marketing Teams

### Problem Statement
Event organizers struggle with fragmented tools for registration, manual confirmations, poor attendee tracking, and lack of actionable insights. This leads to:
- Revenue loss from capacity mismanagement
- Poor attendee experience due to manual processes
- Limited visibility into event performance
- Inefficient lead nurturing and conversion

**EventEase Solution:** A unified Salesforce platform that automates the entire event lifecycle with AI-driven insights and seamless user experiences.

## 🚀 Key Features

### 📊 Core Data Model
- **Event__c**: Complete event lifecycle management (virtual/in-person, capacity, pricing)
- **Attendee__c**: Comprehensive attendee profiles with interests and preferences
- **Registration__c**: Junction object managing event-attendee relationships with status tracking
- **Feedback__c**: Post-event feedback collection and rating system
- **A/B Testing Objects**: `AB_Test__c`, `AB_Test_Variant__c`, `AB_Test_Result__c` for optimization

### ⚡ Intelligent Automation
- **RegistrationTrigger**: Real-time capacity management, duplicate prevention, email notifications
- **EventWeeklySummaryBatch**: Automated weekly reports to event organizers
- **Smart Email System**: Dynamic content based on registration status and payment
- **Lead Conversion**: Automated lead-to-attendee conversion with interest matching
- **Task Creation**: Automatic follow-up tasks for event organizers

### 🎨 Modern User Interface (Lightning Web Components)
- **eventDashboard**: Real-time event analytics with capacity monitoring
- **bulkRegistration**: Advanced bulk attendee registration with CSV import
- **registrationsCounter**: Live registration counts with progress indicators
- **lowAttendanceAlerts**: Proactive alerts for events below attendance thresholds
- **leadSelector**: Intelligent lead selection for targeted marketing campaigns

### 🤖 AI-Powered Features
- **Event Recommendations**: Interest-based suggestions using attendee history
- **Lead Scoring**: Intelligent qualification based on engagement patterns
- **Capacity Optimization**: Predictive analytics for event sizing
- **A/B Testing Framework**: Continuous optimization of registration flows

### 📧 Marketing & Lead Management
- **Web-to-Lead Integration**: Professional forms with custom field mapping
- **Email Campaigns**: Targeted invitations and follow-up sequences
- **Lead Nurturing**: Automated conversion workflows
- **Event Promotion**: Bulk email capabilities with personalization

### 📈 Analytics & Reporting
- **Real-time Dashboards**: Live metrics and performance indicators
- **Custom Reports**: Registration trends, revenue analysis, capacity utilization
- **Revenue Tracking**: Financial performance with forecasting capabilities
- **Attendance Analytics**: Engagement patterns and optimization insights

### 🔐 Enterprise Security
- **Role-Based Access**: Granular permission sets for different user types
- **GDPR Compliance**: Data privacy controls and consent management
- **IP Restrictions**: Enhanced security for admin access

## 📁 Project Structure

```
EventEase/
├── force-app/main/default/
│   ├── classes/                    # Apex Controllers & Business Logic
│   │   ├── BulkRegistrationApex.cls
│   │   ├── EventDashboardController.cls
│   │   ├── RegistrationTriggerHandler.cls
│   │   ├── LeadToAttendeeConverter.cls
│   │   └── EventWeeklySummaryBatch.cls
│   ├── lwc/                        # Lightning Web Components
│   │   ├── eventDashboard/
│   │   ├── bulkRegistration/
│   │   ├── registrationsCounter/
│   │   └── lowAttendanceAlerts/
│   ├── objects/                    # Custom Objects & Fields
│   │   ├── Event__c/
│   │   ├── Attendee__c/
│   │   ├── Registration__c/
│   │   └── Feedback__c/
│   ├── triggers/                   # Apex Triggers
│   │   └── RegistrationTrigger.trigger
│   ├── flexipages/                 # Lightning Record Pages
│   │   ├── Event_Record_Page.flexipage-meta.xml
│   │   └── Registration_Record_Page.flexipage-meta.xml
│   ├── permissionsets/             # Security & Access Control
│   │   ├── EventEase_Admin_Permissions.permissionset-meta.xml
│   │   └── EventEase_Manager.permissionset-meta.xml
│   └── flows/                      # Process Automation
│       └── Send_Event_Invitations_to_Leads.flow-meta.xml
├── Phase 1/                        # Requirements & Analysis
│   ├── Phase_1.pdf
│   └── ai-strategy.md
├── Phase 2/                        # Data Model & Architecture
│   ├── Phase_2.pdf
│   └── Images/
├── Phase 3/                        # Business Logic & Automation
│   └── Phase_3.pdf
├── Phase 4/                        # Batch Processing & Scheduling
├── Phase 5/                        # Testing & Quality Assurance
├── Phase 6/                        # User Interface Development
├── Phase 7/                        # Integration & Workflows
├── Phase 8/                        # Deployment & Data Management
├── Phase 9/                        # Analytics & Security
├── data-management/                # Data Import Templates
│   ├── Event_Data_Loader_Template.csv
│   ├── Attendee_Data_Loader_Template.csv
│   └── Data_Loader_Configuration_Guide.md
├── web-to-lead/                    # Lead Generation
│   └── Web-To-Lead-Form.html
├── ab-testing/                     # Optimization Framework
│   ├── AB_Test_Demo_Implementation.md
│   └── EventEase_AB_Testing_Scenarios.md
├── security/                       # Security Documentation
│   └── Security_Configuration_Guide.md
├── config/                         # Salesforce Configuration
│   └── project-scratch-def.json
├── manifest/                       # Deployment Manifests
│   └── package.xml
└── sample-data/                    # Sample Data Files
    └── bulk_registration_sample.csv
```

## 💡 Usage Examples

### Event Management Workflow
```apex
// Create a new event
Event__c newEvent = new Event__c(
    Name = 'AI Workshop 2024',
    Event_Type__c = 'Workshop',
    Event_Date__c = Date.today().addDays(30),
    Mode__c = 'Virtual',
    Capacity__c = 100,
    Registration_Fee__c = 0,
    Status__c = 'Active'
);
insert newEvent;

// Bulk register attendees using BulkRegistrationApex
List<Registration__c> registrations = BulkRegistrationApex.saveGrid(
    attendeeIds, 
    newEvent.Id, 
    false // validateOnly = false
);
```

### Lead-to-Attendee Conversion
```apex
// Convert qualified leads to attendees
List<Id> leadIds = new List<Id>{'00Q...', '00Q...'};
LeadToAttendeeConverter.convertLeadsToAttendees(leadIds);

// Send targeted event invitations
EventEaseLeadUtils.sendEventInvitationToLeads(leadIds, eventId);
```

### Real-time Analytics
```javascript
// Get live registration statistics (LWC)
import { LightningElement, api, wire } from 'lwc/core';
import getRegistrationStats from '@salesforce/apex/RegistrationsCounterController.getRegistrationStats';

export default class RegistrationsCounter extends LightningElement {
    @api recordId; // Event ID
    
    @wire(getRegistrationStats, { eventId: '$recordId' })
    registrationData;
    
    get capacityPercentage() {
        return this.registrationData.data ? 
            (this.registrationData.data.confirmedCount / this.registrationData.data.capacity) * 100 : 0;
    }
}
```

### Automated Email Campaigns
```apex
// Send reminder emails to specific registration statuses
EventDashboardController.sendReminderEmails(eventId, 'PendingPayment');

// Bulk email campaign to qualified leads
Integer emailsSent = EventEaseLeadUtils.sendEventEmailsToQualifiedLeads(eventId);
System.debug('Campaign sent to ' + emailsSent + ' leads');
```

### A/B Testing Implementation
```apex
// Create A/B test for registration form optimization
AB_Test__c abTest = new AB_Test__c(
    Name = 'Registration Form Optimization',
    Status__c = 'Active',
    Traffic_Percentage__c = 50,
    Start_Date__c = Date.today(),
    End_Date__c = Date.today().addDays(30)
);

// Track conversion events
ABTestController.trackConversion(testId, userId, 'registration_completed');
```

## Prerequisites

- Salesforce CLI (sf) – https://developer.salesforce.com/tools/salesforcecli
- A Salesforce Dev Hub (for scratch orgs)
- Node.js 18+ and npm (for linting and LWC unit tests)

## Quick Start (Scratch Org)

```bash
# 1) Authorize your Dev Hub (once)
sf org login web --alias DevHub --set-default-dev-hub

# 2) Create a scratch org
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias EventEaseScratch \
  --duration-days 7 \
  --set-default

# 3) Deploy source to the scratch org
sf project deploy start --target-org EventEaseScratch

# 4) Assign permission sets (at least Admin)
sf org assign permset --name EventEase_Admin_Permissions --target-org EventEaseScratch
# Optionally assign additional roles
sf org assign permset --name EventEase_Manager --target-org EventEaseScratch
sf org assign permset --name EventEase_Full_Access --target-org EventEaseScratch
sf org assign permset --name EventEase_Analyst --target-org EventEaseScratch

# 5) Open the org
sf org open --target-org EventEaseScratch
```

### Post-Deploy Configuration

1. **Assign Permission Sets** (Required)
   ```bash
   sf org assign permset --name EventEase_Admin_Permissions
   sf org assign permset --name EventEase_Manager  
   sf org assign permset --name EventEase_Full_Access
   ```

2. **Configure Lightning Record Pages**
   - Navigate to **Setup → Object Manager → Event → Lightning Record Pages**
   - Set `Event_Record_Page` as the default for Event records
   - The page includes `eventDashboard` and `bulkRegistration` components

3. **Enable Weekly Summary Scheduler** (Optional)
   ```apex
   // Execute in Developer Console
   EventWeeklySummaryScheduler scheduler = new EventWeeklySummaryScheduler();
   String cronExp = '0 0 8 ? * MON'; // Every Monday at 8 AM
   System.schedule('EventEase Weekly Summary', cronExp, scheduler);
   ```

4. **Configure Web-to-Lead** (Optional)
   - Update the Org ID in `web-to-lead/Web-To-Lead-Form.html`
   - Deploy the form to your website or test locally

## Deploy to Sandbox/Production

```bash
# Login to your target org (Sandbox example)
sf org login web --alias MySandbox --instance-url https://test.salesforce.com

# Deploy using the manifest
sf project deploy start \
  --target-org MySandbox \
  --manifest manifest/package.xml \
  --test-level RunLocalTests
```

For Production replace the login command with your production org (no instance URL) and ensure required tests exist and pass.

## Optional Analytics & Reports (disabled by default)

Some components are intentionally excluded via `.forceignore` to avoid non‑critical deployment issues. To enable them, remove these lines in `.forceignore`, then redeploy:

```text
force-app/main/default/lwc/revenueTrendGraph/**
force-app/main/default/classes/RevenueTrendController.cls
force-app/main/default/classes/RevenueTrendController.cls-meta.xml
force-app/main/default/staticresources/chartjs.resource
force-app/main/default/staticresources/chartjs.resource-meta.xml
force-app/main/default/reports/EventEase_Reports/**
force-app/main/default/reports/EventEase_Reports-meta.xml
force-app/main/default/reportTypes/Event_with_Registrations.reportType-meta.xml
force-app/main/default/reportTypes/Event_with_Registrations_and_Feedback.reportType-meta.xml
force-app/main/default/lwc/topRatedEventsChart/**
force-app/main/default/classes/TopRatedEventsController.cls
force-app/main/default/classes/TopRatedEventsController.cls-meta.xml
```

There is also an org‑specific validation rule excluded by default:

```text
force-app/main/default/objects/Lead/validationRules/Require_Event_Interest__c.validationRule-meta.xml
```

## Data Management

- CSV templates: `data-management/Event_Data_Loader_Template.csv`, `Attendee_Data_Loader_Template.csv`, `Registration_Data_Loader_Template.csv`
- Guide: `data-management/Data_Loader_Configuration_Guide.md`
- Sample: `sample-data/bulk_registration_sample.csv`

Use Salesforce Data Loader or Import Wizard to load sample data. The app enforces capacity and duplicate rules via triggers.

## Web‑to‑Lead

- A working form is provided at `web-to-lead/Web-To-Lead-Form.html`.
- You can host this on your website or test locally. Ensure the form’s Org ID (oid) is set for your org if you customize it.
- Leads can be converted to attendees via `LeadToAttendeeConverter` and invited using `EventLeadEmailController` / `LeadEventEmailSender`.

## Testing, Linting, and Formatting

```bash
# Install dev dependencies (once)
npm install

# LWC unit tests
npm test

# Lint and format
npm run lint
npm run prettier
npm run prettier:verify
# Apex tests (in your default/target org)
sf apex run test --test-level RunLocalTests --target-org EventEaseScratch --code-coverage --verbose
```

## 🔧 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Analytics components missing** | Check `.forceignore` - remove exclusions for `topRatedEventsChart`, `revenueTrendGraph` |
| **Fields not visible on forms** | Verify field-level security in permission sets and page layouts |
| **Bulk registration fails** | Check event capacity limits and duplicate prevention rules |
| **Email notifications not sent** | Verify email deliverability settings and trigger execution |
| **Permission errors** | Ensure proper permission set assignment for user roles |

### Performance Optimization

1. **Large Dataset Handling**
   ```apex
   // Use selective SOQL queries
   List<Registration__c> regs = [
       SELECT Id, Status__c, Attendee__c, Event__c 
       FROM Registration__c 
       WHERE Event__c = :eventId 
       AND Status__c IN ('Confirmed', 'Pending')
       LIMIT 1000
   ];
   ```

2. **Bulk Operations**
   - Use `BulkRegistrationApex.saveGrid()` for processing multiple registrations
   - Implement proper error handling for governor limits
   - Consider batch processing for operations >200 records

3. **Real-time Components**
   - LWC components auto-refresh every 30 seconds to 5 minutes
   - Disable auto-refresh for better performance if not needed
   - Use caching strategies for frequently accessed data

### Debug Mode

Enable debug logging for troubleshooting:
```apex
// In Developer Console
System.debug(LoggingLevel.INFO, 'Registration processing: ' + registrationData);

// Check trigger execution
System.debug('RegistrationTrigger executed for: ' + Trigger.new.size() + ' records');
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is provided for educational and internal enterprise demonstration purposes. 

## 🆘 Support

For technical support or questions:
- Review the comprehensive documentation in `Phase [1-3]/` folders
- Check the troubleshooting guide above
- Consult Salesforce Trailhead for Lightning development best practices
- Use Salesforce Developer Console for debugging Apex code

---

**Built with ❤️ using Salesforce Lightning Platform**
