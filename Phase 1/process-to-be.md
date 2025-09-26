# Target-State Process (To-Be) — Salesforce

1) Event Setup
- Organizer creates `Event__c` with dates, timezone, capacity, venue, price/type, topics.
- Optional `Session__c` and speaker assignments.
- Validation rules ensure completeness and data quality.

2) Registration Intake
- Web form or on-behalf creation creates `Registration__c` (Contact + Event).
- Duplicate prevention by email and Contact matching.
- Capacity check; auto-waitlist if full.

3) Confirmations & Reminders
- Flow + Email Alerts/SMS: Confirmation on registration with ICS + QR code.
- Reminder schedule: T-7, T-1, T-0 with dynamic merges (time, venue, QR).
- Opt-in/out respected; error handling and retries for bounces.

4) Check-in
- QR scan updates `Registration__c.Status__c` to Attended and stamps CheckInTime.
- Kiosk mode or organizer app for manual override.

5) Post-Event
- Thank-you + survey; certificate (optional) generated and sent.
- Attendance rollups and event performance updates.

6) AI Recommendations Flow
- Batch or on-demand scoring to recommend events per Contact.
- Surfaced via list on Experience Cloud or injected into emails.

## Automation Components (MVP)
- Flow Builder: Registration orchestration, reminders, status transitions.
- Email Alerts + Messaging: Notify with ICS and QR.
- Validation Rules: Mandatory fields and date coherence.
- Duplicate Rules: Contact matching on email + name.
- Roll-Up (DLRS or Apex): Remaining capacity on Event.

## Exception Handling
- Payment failure → hold status + follow-up.
- Over-capacity → auto-waitlist + notify.
- Cancellations → release seat and notify waitlist.
