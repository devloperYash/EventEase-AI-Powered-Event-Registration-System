# MVP Scope & Backlog — EventEase

## MVP Objective
Enable organizers to publish events, accept registrations, send confirmations/reminders, perform QR check-in, and view core dashboards. Include simple AI recommendations.

## User Stories (Prioritized)
1. As an Organizer, I can create an Event with dates, venue, capacity, and topics.
2. As an Attendee, I can register via a simple form and receive a confirmation with ICS.
3. As the System, I automatically send reminders at T-7, T-1, and T-0 (opt-in aware).
4. As an Organizer, I can view registrations and manage waitlists.
5. As an Attendee, I can be checked in by scanning a QR code.
6. As an Organizer/Admin, I can view dashboards for attendance trends and popular events.
7. As the System, I can recommend up to 3 upcoming events to each attendee based on interests.

## Acceptance Criteria (Examples)
- Duplicate registrations prevented via email + name matching.
- Confirmation sent within 1 minute of registration; includes ICS and QR link.
- Check-in updates Registration status to Attended with timestamp.
- Dashboards reflect real-time counts and rates.

## Out of Scope (MVP)
- Complex payments and refunds.
- Advanced Einstein models (use rules-based scoring first).
- Speaker management portal and multi-day conference scheduling (phased later).

## Risks & Mitigations
- Email/SMS deliverability: use verified domains and sender authentication.
- Data quality: enforce validation and duplicates early.
- Adoption: training and clear dashboards for value realization.

## Next Steps
- Phase 2: Configure metadata (objects/fields), build forms/flows/LWCs, wire comms and (optional) payments, and deploy to a scratch org for testing.
