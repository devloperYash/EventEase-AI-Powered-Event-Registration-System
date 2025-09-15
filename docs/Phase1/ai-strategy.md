# AI Strategy — Recommendations (MVP → Future)

## Objective
Increase registrations and attendance by recommending relevant events to each attendee (Contact).

## MVP Approach (Rules + Scoring)
- Use topics/interest overlap, popularity, recency, and proximity to score events per Contact.
- Compute a score S(Event, Contact) with weights tuned during pilot.

Suggested scoring (0–100):
- Topic overlap (w1=40): % overlap between Contact.Interest_Topics__c and Event.Topics__c.
- Popularity (w2=20): normalized registrations in last N days for this Event.
- Recency (w3=20): exponential decay by days until event (closer = higher).
- Proximity (w4=10): local vs remote; same city/country boost.
- Personal history (w5=10): similarity to previously attended event topics.

Implementation (MVP):
- Nightly Flow (Scheduled Path) or Batch Apex computes scores and stores on a Recommendation store (custom object or Recommendation standard object).
- Use Next Best Action (NBA) to surface top-N recommendations with explanation text.

## Phase 2+ (Einstein)
- Einstein Discovery model to predict "Likelihood to Register" using features: interests, past registration/attendance, email engagement, event features, time, location.
- Use model score in NBA strategy with eligibility and prioritization rules.

## Cold Start & Safeguards
- If no interests, fallback to popular/upcoming events; collect interests during registration.
- Respect opt-out flags and capacity (do not recommend closed/full events unless waitlist is desired).

## Explainability
- Store reason codes (e.g., "Matches your interest: AI & Data"; "Near you in Mumbai on Sep 21"). Include snippets in emails/UI.
