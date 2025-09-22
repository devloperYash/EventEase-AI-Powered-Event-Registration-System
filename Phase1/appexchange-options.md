# AppExchange Options — Communications, Payments, Docs, Check-in

## Email/SMS
- Salesforce Digital Engagement (SMS/WhatsApp): Native, governed, robust routing. Requires licenses.
- Twilio for Salesforce: Flexible SMS/WhatsApp; proven at scale; usage-based pricing.
- 360 SMS or Vonage: Admin-friendly templates; quick to launch.

Recommendation (MVP): Start with Email Alerts (native) + Twilio SMS for reminders (opt-in). Scale to Digital Engagement as needed.

## Payments (Optional in MVP)
- Stripe for Salesforce (various connectors): Easy checkout, strong UX. Evaluate PCI scope.
- Chargent: Mature, supports many gateways, recurring payments.
- Payment Center: Simpler setup for one-time payments.

Recommendation: If paid events are needed, pilot Chargent or Stripe connector with a single gateway.

## Document Management / Resources
- Salesforce Files: Native, versioned, easy sharing. Good default.
- Box for Salesforce / SharePoint integrations: If external collaboration required.

## Check-in & QR
- Build QR code in Apex/LWC + mobile responsive page for scan.
- AppExchange: Several "QR/Check-in" utilities exist; validate maintenance.

Recommendation: Build lightweight QR generation and scan with a simple LWC; revisit apps if scale requires.

## Surveys
- Salesforce Surveys (native) for post-event feedback.
- GetFeedback (Momentive) for richer analytics if needed.
