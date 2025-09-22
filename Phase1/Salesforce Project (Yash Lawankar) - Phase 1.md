# Salesforce Project (Yash Lawankar) — EventEase — Phase 1

This document presents Phase 1 (Problem Understanding & Industry Analysis) for the Salesforce portfolio project: EventEase — AI-Powered Event Registration System.

---

## Project Overview

- Project Title: EventEase – AI-Powered Event Registration System
- Industry: Event Management / Education / Corporate Training
- Project Type: B2C Salesforce CRM Implementation
- Target Users: Event Organizers, Attendees, Administrators

- Problem Statement:
  Event organizers often rely on manual registration or multiple tools to manage attendees, send confirmations, and track participation. This causes inefficiency, data loss, poor follow-up, and limited analytics. They require a centralized Salesforce CRM to manage events, automate registrations, send AI-driven reminders, and generate real-time insights.

- Use Cases:
  1) Event Management: Maintain a central database of events with details like date, venue, and capacity.
  2) Attendee Registration: Capture registrations online or on-site; automated email confirmations.
  3) AI-Powered Recommendations: Suggest relevant events to attendees based on their interests and past participation.
  4) Reporting & Analytics: Dashboards for organizers to track attendance trends, popular events, and revenue.

---

## Phase 1: Problem Understanding & Industry Analysis

- Requirement Gathering:
  - Sessions with Event Organizers and Admins to identify challenges in attendee registration, confirmations, reminders, and participation tracking.
  - Outcomes: Functional and non-functional requirements, success criteria, and scope boundaries. See `docs/phase1/requirements.md`.

- Stakeholder Analysis:
  - Event Organizers → need easy attendee registration, confirmation emails, and participation tracking.
  - Administrators → need dashboards to monitor event trends, revenue, and attendance.
  - Attendees → need transparent registration, timely reminders, and relevant recommendations.
  - Details and RACI in `docs/phase1/stakeholders.md`.

- Business Process Mapping:
  - Current (As-Is): Manual/third-party registrations, ad-hoc confirmations, inconsistent check-in, spreadsheet-based reporting. See `docs/phase1/process-as-is.md`.
  - Target (To-Be): Salesforce-automated workflow with registration intake, confirmations (ICS + QR), reminders, QR check-in, and post-event follow-ups. See `docs/phase1/process-to-be.md`.

- AppExchange Exploration:
  - Email/SMS: Native Email Alerts + Twilio SMS (fast start) or Digital Engagement (native, licensed).
  - Payments (optional): Stripe connector or Chargent if paid events are required.
  - Document Management: Salesforce Files (default), Box/SharePoint if external collaboration needed.
  - Check-in & QR: Lightweight custom QR + scan LWC; consider apps if scale demands.
  - Summary in `docs/phase1/appexchange-options.md`.

- AI Strategy (Preview for Value Case Only; Build Later):
  - MVP rules-based scoring using interests, popularity, recency, proximity, and personal history.
  - Phase 2+: Einstein Discovery model for “Likelihood to Register.” See `docs/phase1/ai-strategy.md`.

- Security & Compliance (Draft):
  - OWD: Prefer Public Read-Only for Events; Private for Registrations (PII) with sharing to organizers.
  - Consent and FLS enforced; retention policy defined. See `docs/phase1/security-privacy.md`.

- MVP Scope (For Next Phase Planning; Not Executed in Phase 1):
  - Prioritized user stories and acceptance criteria prepared. See `docs/phase1/mvp-scope.md`.

---

## Phase 1 Deliverables Checklist

- Requirements and success criteria
- Stakeholder personas and RACI
- As-Is and To-Be process maps
- Data model and sharing model draft
- AppExchange evaluation
- Reporting & KPIs
- AI recommendation strategy overview

Status: Completed and ready for stakeholder sign-off.

---

## Sign-Off Questions

1) Payments in MVP: include now or defer?
2) SMS provider: Twilio (fast start) vs Digital Engagement (native, licensed)?
3) Check-in approach: lightweight custom QR/LWC vs AppExchange?
4) Experience Cloud portal in MVP or later?
5) Event object OWD: Public Read-Only vs Public Read/Write?


