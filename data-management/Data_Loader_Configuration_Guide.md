# EventEase Data Loader Configuration Guide

## Overview
This guide provides step-by-step instructions for importing data into the EventEase system using Salesforce Data Loader.

## Prerequisites
- Salesforce Data Loader installed
- EventEase metadata deployed to target org
- CSV files prepared with correct field mappings
- User with appropriate permissions

## Import Order (Critical)
**IMPORTANT**: Import data in this exact order to maintain referential integrity:

1. **Events** (Parent object)
2. **Attendees** (Independent object)
3. **Registrations** (Junction object - requires Event and Attendee IDs)
4. **Feedback** (Child object - requires Event and Attendee IDs)

## Field Mappings

### Event Import Mapping
| CSV Column | Salesforce Field | Required | Notes |
|------------|------------------|----------|-------|
| Name | Name | Yes | Event name |
| Event_Type__c | Event_Type__c | Yes | Conference/Summit/Workshop/Launch/Networking |
| Event_Date__c | Event_Date__c | Yes | Format: YYYY-MM-DD |
| Event_Mode__c | Event_Mode__c | Yes | In-Person/Virtual/Hybrid |
| Venue__c | Venue__c | No | Venue name |
| Address__c | Address__c | No | Street address |
| City__c | City__c | No | City name |
| State__c | State__c | No | State/Province |
| Country__c | Country__c | No | Country name |
| Capacity__c | Capacity__c | Yes | Numeric value |
| Registration_Fee__c | Registration_Fee__c | No | Numeric value |
| Description__c | Description__c | No | Event description |
| Event_Owner__c | Event_Owner__c | Yes | User ID |

### Attendee Import Mapping
| CSV Column | Salesforce Field | Required | Notes |
|------------|------------------|----------|-------|
| Name | Name | Yes | Full name |
| Email__c | Email__c | Yes | Valid email format |
| Phone__c | Phone__c | No | Phone number |
| Job_Title__c | Job_Title__c | No | Job title |
| Company__c | Company__c | No | Company name |
| Interest__c | Interest__c | No | Area of interest |

### Registration Import Mapping
| CSV Column | Salesforce Field | Required | Notes |
|------------|------------------|----------|-------|
| Event__c | Event__c | Yes | Event record ID |
| Attendee__c | Attendee__c | Yes | Attendee record ID |
| Registration_Date__c | Registration_Date__c | Yes | Format: YYYY-MM-DD |
| Status__c | Status__c | Yes | Pending/Confirmed/Cancelled |
| VIP__c | VIP__c | No | TRUE/FALSE |
| Discount__c | Discount__c | No | Numeric percentage |

## Data Loader Steps

### 1. Event Import
1. Open Salesforce Data Loader
2. Select "Insert" operation
3. Choose Event__c object
4. Map CSV file: `Event_Data_Loader_Template.csv`
5. Map fields according to table above
6. Run import and save success/error files
7. **Save Event IDs** from success file for Registration import

### 2. Attendee Import
1. Select "Insert" operation
2. Choose Attendee__c object
3. Map CSV file: `Attendee_Data_Loader_Template.csv`
4. Map fields according to table above
5. Run import and save success/error files
6. **Save Attendee IDs** from success file for Registration import

### 3. Registration Import
1. **Update CSV** with actual Event and Attendee IDs from previous imports
2. Select "Insert" operation
3. Choose Registration__c object
4. Map CSV file: `Registration_Data_Loader_Template.csv`
5. Map fields according to table above
6. Run import and save success/error files

## Validation Rules
Ensure your data meets these validation requirements:
- Event dates must be in the future (for new events)
- Registration capacity cannot exceed event capacity
- Email addresses must be unique per event
- Status values must match picklist options

## Error Handling
- Review error files for any failed records
- Common issues: Invalid picklist values, missing required fields, duplicate records
- Reprocess failed records after correcting data

## Post-Import Verification
1. Verify record counts match expected numbers
2. Check related lists are populated correctly
3. Test registration workflows
4. Validate email notifications are working
5. Confirm capacity calculations are accurate

## Backup Recommendations
- Export existing data before import
- Save success/error files for audit trail
- Document any data transformations applied
- Keep original CSV files for reference

## Performance Tips
- Import in batches of 200-500 records for optimal performance
- Use bulk API for large datasets (>10,000 records)
- Schedule imports during low-usage periods
- Monitor org limits during import process
