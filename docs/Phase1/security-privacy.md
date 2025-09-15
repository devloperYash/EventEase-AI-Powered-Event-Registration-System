# Security, Privacy & Compliance — EventEase

## Org-Wide Defaults (Draft)
- Event__c: Public Read Only (edit via permissions), or Public Read/Write with stricter profiles.
- Registration__c: Private (contains PII and attendance). Share via roles/sharing rules to organizers.
- Session__c, Venue__c: Public Read/Write for event teams.

## Access Controls
- Use Permission Sets for granular rights (manage events, manage registrations, check-in kiosk).
- Field-Level Security for PII (email, phone) and payment fields.
- Profiles minimized; favor permission set assignments.

## Consent & Communications
- Store Marketing_Opt_In__c on Contact; honor via Flow conditions.
- Provide unsubscribe/preference center (Experience Cloud or provider’s page).

## Data Protection
- Consider Shield Platform Encryption for PII if required.
- Audit: Field History Tracking on Registration__c (status, check-in) and Event__c (capacity).
- Retention: Anonymize or delete attendance/payment data after policy-defined period.

## Compliance
- GDPR/DPDP (India) ready: purpose limitation, consent, access requests.
- Event logs for access and changes; IP login restrictions for kiosk devices (optional).
