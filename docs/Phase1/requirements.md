# Requirements — EventEase Phase 1

## Goals
- Centralize event and attendee data in Salesforce (B2C).
- Automate registrations, confirmations, reminders, and check-in.
- Provide AI-driven recommendations to increase engagement and attendance.
- Deliver real-time analytics for organizers and admins.

## In Scope (Phase 1 Outcomes)
- Documented requirements and success criteria.
- Target Salesforce workflows (registrations, confirmations, reminders, check-in).
- Data model and integration approach.
- AppExchange recommendations for comms, payments, check-in, and docs.
- Reporting definitions and security model.

## Out of Scope (Build Phase)
- Final metadata deployment, LWCs, Flows, and integrations (planned for Phase 2).

## Functional Requirements

1) Event Management
- Create/Update Events with: Name, Dates, Timezone, Venue, Capacity, Status, Type, Price, Topics.
- Manage Sessions (optional in MVP), Speakers, and Rooms.
- Maintain Venues and capacity constraints.
- Waitlist when event reaches capacity.

2) Registration
- Support web registration, on-site registration, and on-behalf (organizer creates).
- Duplicate prevention by email + name or by Contact lookup.
- Automated confirmation email with calendar (.ics) and QR code for check-in.
- Optional payment capture (see AppExchange evaluation) with status tracking.

3) Communications
- Automated reminder emails/SMS (e.g., T-7, T-1, T-0) with dynamic content.
- Resend logic for bounced emails and opt-in/opt-out handling.
- Post-event follow-up: thank-you, survey link, certificate (optional).

4) Check-in & Attendance
- Scan QR code to mark attendance and time.
- Kiosk mode or organizer-assisted check-in.
- Attended/No-Show status updates and audit.

5) AI Recommendations (MVP)
- Suggest relevant events to attendees based on topics/interests and past participation.
- Provide a ranked list of up to N events per attendee with reasons (explainability).
- Display on Experience Cloud page (future) or email snippets.

6) Reporting & Analytics
- Dashboards: Attendance Trends, Popular Events, Registration Funnel, Revenue (if paid).
- Organizer drill-down on event performance and no-show rate.

## Non-Functional Requirements
- Performance: Registration form save < 2s; check-in scan < 1s.
- Scale: 100k Contacts, 5k registrations/day.
- Data Quality: Mandatory fields; validation rules; duplicate management.
- Auditability: Track status changes and communications.
- Accessibility: WCAG-compliant forms; mobile-friendly.
- Localization: Timezone-aware events and reminders.

## Integrations
- Email/SMS: Native or AppExchange (e.g., Digital Engagement, Twilio).
- Payments: Stripe/Chargent (MVP optional if events are free).
- Calendar: ICS attachments in confirmation.
- Docs: Salesforce Files for resources.

## Success Criteria / KPIs
- 50%+ reduction in manual effort for registration management.
- 95%+ delivery rate for confirmations/reminders.
- 20%+ increase in registrations from recommendations or reminders.
- 90%+ check-in accuracy via QR scanning.
- Time-to-report reduced to real-time dashboards from ad-hoc spreadsheets.
