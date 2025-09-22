# Salesforce Project (Yash Lawankar) — EventEase — Phase 2

Phase 2 focuses on Org Setup & Configuration to prepare the foundation for data modeling and automation.

---

## What Was Done in Phase 2

- Scratch Org Definition Updated (`config/project-scratch-def.json`)
  - Edition: Enterprise
  - Company Settings:
    - defaultLocale: `en_IN`
    - defaultCurrencyIsoCode: `INR`
    - defaultTimeZone: `Asia/Kolkata`
    - fiscalYearStartMonth: `4`
  - Language Settings: Enabled end-user and platform languages

- Role Hierarchy (Metadata)
  - Top Role: `roles/Admin.role-meta.xml`
  - `roles/Event_Manager.role-meta.xml` → parent `Admin`
  - `roles/Organizer.role-meta.xml` → parent `Event_Manager`

- Profiles (Minimal Scaffolds)
  - `profiles/Admin.profile-meta.xml`
  - `profiles/Organizer.profile-meta.xml`
  - Note: Object/field permissions will be assigned via permission sets in later phases.

- Permission Set (Seed for AI Access)
  - `permissionsets/AI_Recommendations.permissionset-meta.xml`
  - Purpose: Assignable handle for future AI recommendation access.

- OWD Alignment (Per Phase 2)
  - Created minimal custom objects with Private sharing to align with security posture:
    - `objects/Event__c/Event__c.object-meta.xml` → `<sharingModel>Private</sharingModel>`
    - `objects/Attendee__c/Attendee__c.object-meta.xml` → `<sharingModel>Private</sharingModel>`
  - Full data model (Event, Attendee, Registration, Feedback) proceeds in Phase 3.

- Manifest Updated (`manifest/package.xml`)
  - Included types: `Role`, `PermissionSet`, `Profile` (alongside `CustomObject` and `ApexClass`)

- Phase 2 Documentation
  - `docs/phase2/README.md` — Setup steps, SFDX commands, Business Hours options.

- Source Hygiene
  - Ignored a stray placeholder file to avoid push errors:
    - `.forceignore` → `force-app/main/default/objects/Event__c/fields/BannerImageURL__c.field-meta.xml`

---

## How to Validate (Scratch Org)

1) Create scratch org (7 days) and set as default:
```
sfdx force:org:create -f config/project-scratch-def.json -a EventEase -d 7 -s
```

2) Push metadata:
```
sfdx force:source:push
```

3) Assign permission set (optional now):
```
sfdx force:user:permset:assign -n AI_Recommendations
```

4) Open the org:
```
sfdx force:org:open
```

5) Configure Business Hours (recommended via UI):
- Setup → Company Settings → Business Hours → New Business Hours
- Name: EventEase Business Hours
- Time Zone: Asia/Kolkata
- Mon–Fri: 09:00–18:00 (example) → Set as Default

---
## Prerequisites
- Auth to a Dev Hub and sf CLI installed.
- Project API version: see `sfdx-project.json` (currently `sourceApiVersion: 64.0`).

## 1) Create a Scratch Org
The definition file is at `config/project-scratch-def.json`.

Important: We removed `companySettings` due to a known settings deploy error. If you previously added it and see a CompanySettings parse error, remove it and retry.

```powershell
sf org create scratch --definition-file config/project-scratch-def.json --alias EventEase --duration-days 7 --set-default
```

## 2) Deploy Roles (targeted)
Deploy only the EventEase roles to avoid older role files or conflicts:

```powershell
sf project deploy start `
  --source-dir "force-app/main/default/roles/EventEase_Admin.role-meta.xml" `
  --source-dir "force-app/main/default/roles/EventEase_Event_Manager.role-meta.xml" `
  --source-dir "force-app/main/default/roles/EventEase_Organizer.role-meta.xml" `
  --target-org EventEase
```

Verify:
```powershell
sf data query --target-org EventEase `
  --query "SELECT Id, Name, DeveloperName, ParentRoleId FROM UserRole WHERE Name LIKE 'EventEase%' ORDER BY Name"
```

## 3) Deploy Permission Set (AI)
```powershell
sf project deploy start --metadata PermissionSet:AI_Recommendations --target-org EventEase
```

Assign to the default user:
```powershell
sf org assign permset --name AI_Recommendations --target-org EventEase
```

Verify assignment:
```powershell
sf data query --target-org EventEase `
  --query "SELECT Id, PermissionSet.Label, Assignee.Username FROM PermissionSetAssignment WHERE PermissionSet.Name = 'AI_Recommendations'"
```

## 4) Optional: Deploy Minimal Private Objects
These are placeholders to reflect the Private posture; the full data model comes in Phase 3.

```powershell
sf project deploy start `
  --source-dir "force-app/main/default/objects/Event__c" `
  --source-dir "force-app/main/default/objects/Attendee__c" `
  --target-org EventEase
```

## 5) Open the Org
```powershell
sf org open --target-org EventEase
```
