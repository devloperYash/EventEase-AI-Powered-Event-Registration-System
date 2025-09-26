/**
 * @description Advanced bulk registration controller for grid/CSV workflows
 * Provides attendee upsert (by Email__c) + registration creation with validations
 */
public with sharing class BulkRegistrationApex {

    // Rows coming from LWC grid/CSV
    public class GridRow {
        @AuraEnabled public String id; // client-side id
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String ticketType; // informational (not persisted unless mapped later)
        @AuraEnabled public String status; // Desired registration status (default 'Pending')
    }

    public class RowResult {
        @AuraEnabled public String id; // client-side id
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id attendeeId;
        @AuraEnabled public Id registrationId;
    }

    public class SaveResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Integer attendeeInserts;
        @AuraEnabled public Integer registrationInserts;
        @AuraEnabled public Integer duplicates;
        @AuraEnabled public Integer errors;
        @AuraEnabled public List<RowResult> rows;
        @AuraEnabled public List<String> messages;
    }

    @AuraEnabled
    public static SaveResponse saveGrid(Id eventId, List<GridRow> rows, String defaultStatus, Boolean validateOnly) {
        SaveResponse resp = new SaveResponse();
        resp.success = false;
        resp.attendeeInserts = 0;
        resp.registrationInserts = 0;
        resp.duplicates = 0;
        resp.errors = 0;
        resp.rows = new List<RowResult>();
        resp.messages = new List<String>();

        if (eventId == null) {
            throw new AuraHandledException('Event Id is required');
        }
        if (rows == null || rows.isEmpty()) {
            throw new AuraHandledException('No rows provided');
        }

        // Load event and basic guards
        Event__c ev = [
            SELECT Id, Name, Capacity__c, Attendee_Count__c, Status__c, Start_Date__c, Event_Date__c
            FROM Event__c WHERE Id = :eventId LIMIT 1
        ];

        if (ev.Status__c == 'Registration Closed' || ev.Status__c == 'Completed' || ev.Status__c == 'Cancelled') {
            throw new AuraHandledException('Registrations are closed for this event.');
        }
        // Past event validation
        if (ev.Start_Date__c != null && ev.Start_Date__c < Date.today()) {
            throw new AuraHandledException('Cannot register attendees for past events');
        }

        // Normalize and validate rows
        Map<String, GridRow> byEmail = new Map<String, GridRow>();
        Set<String> dupEmails = new Set<String>();
        // Simple, robust email regex for server-side validation (not exhaustive)
        Pattern emailPattern = Pattern.compile('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$');

        for (GridRow r : rows) {
            RowResult rr = new RowResult();
            rr.id = r != null ? r.id : null;
            rr.name = r != null ? r.name : null;
            rr.email = r != null ? r.email : null;
            rr.success = false;
            rr.message = '';
            resp.rows.add(rr);

            if (r == null) {
                rr.message = 'Empty row';
                resp.errors++;
                continue;
            }
            if (String.isBlank(r.email) || String.isBlank(r.name)) {
                rr.message = 'Name and Email are required';
                resp.errors++;
                continue;
            }
            if (!emailPattern.matcher(r.email).matches()) {
                rr.message = 'Invalid email format';
                resp.errors++;
                continue;
            }
            String key = r.email.trim().toLowerCase();
            if (byEmail.containsKey(key)) {
                // duplicate within payload
                rr.message = 'Duplicate email in upload';
                resp.errors++;
                dupEmails.add(key);
                continue;
            }
            byEmail.put(key, r);
        }

        if (!dupEmails.isEmpty()) {
            resp.messages.add('Duplicate emails found in the uploaded data: ' + String.join(new List<String>(dupEmails), ', '));
        }

        // Filter valid rows (ones without immediate validation errors)
        List<GridRow> validRows = new List<GridRow>();
        for (Integer i = 0; i < resp.rows.size(); i++) {
            RowResult rr = resp.rows[i];
            GridRow original = null;
            if (!String.isBlank(rr.email)) {
                original = byEmail.get(rr.email.trim().toLowerCase());
            }
            if (rr.message == '' && original != null) {
                validRows.add(original);
            }
        }
        if (validRows.isEmpty()) {
            resp.messages.add('No valid rows to process.');
            return resp;
        }

        // Find existing attendees by email
        List<String> emails = new List<String>();
        for (GridRow r : validRows) emails.add(r.email.trim().toLowerCase());
        Map<String, Attendee__c> existingByEmail = new Map<String, Attendee__c>();
        for (Attendee__c a : [SELECT Id, Name, Email__c FROM Attendee__c WHERE Email__c IN :emails]) {
            if (a.Email__c != null) existingByEmail.put(a.Email__c.trim().toLowerCase(), a);
        }

        // Build attendee inserts
        List<Attendee__c> toInsertAttendees = new List<Attendee__c>();
        Map<String, Id> emailToAttId = new Map<String, Id>();
        for (GridRow r : validRows) {
            String key = r.email.trim().toLowerCase();
            if (existingByEmail.containsKey(key)) {
                emailToAttId.put(key, existingByEmail.get(key).Id);
            } else {
                toInsertAttendees.add(new Attendee__c(
                    Name = r.name,
                    Email__c = r.email,
                    Phone__c = r.phone
                ));
            }
        }

        if (!validateOnly && !toInsertAttendees.isEmpty()) {
            Database.SaveResult[] attResults = Database.insert(toInsertAttendees, false);
            Integer idx = 0;
            for (Integer i = 0; i < validRows.size(); i++) {
                GridRow r = validRows[i];
                String key = r.email.trim().toLowerCase();
                if (!emailToAttId.containsKey(key) && idx < attResults.size()) {
                    Database.SaveResult sr = attResults[idx++];
                    if (sr.isSuccess()) {
                        emailToAttId.put(key, sr.getId());
                        RowResult rr2 = findRowResult(resp.rows, r.id, r.email);
                        rr2.attendeeId = sr.getId();
                        resp.attendeeInserts++;
                    } else {
                        // mark corresponding row result as error
                        RowResult rr = findRowResult(resp.rows, r.id, r.email);
                        rr.message = 'Failed to create attendee: ' + joinErrors(sr.getErrors());
                        resp.errors++;
                    }
                }
            }
        } else {
            // validate-only: assume attendee inserts will succeed and simulate Ids with null (we only need to capacity/dup-check registrations)
            for (GridRow r : validRows) {
                String key = r.email.trim().toLowerCase();
                if (!emailToAttId.containsKey(key)) {
                    emailToAttId.put(key, null);
                }
            }
        }

        // Resolve attendee Ids: for newly inserted during validateOnly they are null; we'll skip reg creation in validateOnly anyway
        Set<Id> attendeeIdsForDupCheck = new Set<Id>();
        for (String key : emailToAttId.keySet()) {
            Id aid = emailToAttId.get(key);
            if (aid != null) attendeeIdsForDupCheck.add(aid);
        }

        // Dup registrations (existing). Map by attendee email for easy lookup
        Set<String> duplicateRegEmails = new Set<String>();
        Map<String, Registration__c> existingRegByEmail = new Map<String, Registration__c>();
        if (!attendeeIdsForDupCheck.isEmpty()) {
            for (Registration__c existing : [SELECT Id, Attendee__c, Attendee__r.Email__c, Status__c FROM Registration__c WHERE Event__c = :eventId AND Attendee__c IN :attendeeIdsForDupCheck]) {
                if (existing.Attendee__r != null && !String.isBlank(existing.Attendee__r.Email__c)) {
                    String em = existing.Attendee__r.Email__c.trim().toLowerCase();
                    duplicateRegEmails.add(em);
                    existingRegByEmail.put(em, existing);
                }
            }
        }

        // Capacity pre-check for confirmed registrations
        Integer currentConfirmed = ev.Attendee_Count__c == null ? 0 : ev.Attendee_Count__c.intValue();
        Integer toConfirm = 0;
        Integer toConfirmUpdates = 0;
        for (GridRow r : validRows) {
            String s = String.isBlank(r.status) ? defaultStatus : r.status;
            if (s == null) s = 'Pending';
            String key = r.email.trim().toLowerCase();
            if (s == 'Confirmed') {
                if (!duplicateRegEmails.contains(key)) {
                    // New inserts to Confirmed
                    toConfirm++;
                } else {
                    // Updates to Confirmed (only if existing not already Confirmed)
                    Registration__c ex = existingRegByEmail.get(key);
                    if (ex != null && ex.Status__c != 'Confirmed') {
                        toConfirmUpdates++;
                    }
                }
            }
        }
        if (ev.Capacity__c != null) {
            Integer cap = ev.Capacity__c.intValue();
            if (currentConfirmed + toConfirm + toConfirmUpdates > cap) {
                resp.messages.add('Capacity would be exceeded: ' + (currentConfirmed + toConfirm) + ' > ' + cap);
                // In validateOnly mode, return early to let user adjust
                if (validateOnly) {
                    resp.success = false;
                    return resp;
                }
            }
        }

        if (validateOnly) {
            // Mark all valid rows as pass (unless duplicate in existing)
            for (GridRow r : validRows) {
                RowResult rr = findRowResult(resp.rows, r.id, r.email);
                String key = r.email.trim().toLowerCase();
                if (duplicateRegEmails.contains(key)) {
                    rr.success = false;
                    rr.message = 'Already registered for this event';
                    resp.duplicates++;
                } else {
                    rr.success = true;
                    rr.message = 'Valid';
                }
            }
            resp.success = resp.errors == 0;
            return resp;
        }

        // Build registration inserts (skip duplicates)
        List<Registration__c> toInsertRegs = new List<Registration__c>();
        Map<Integer, GridRow> regIndexToRow = new Map<Integer, GridRow>();
        // Collect updates for duplicates when status change is requested
        List<Registration__c> toUpdateRegs = new List<Registration__c>();
        Map<Integer, GridRow> updIndexToRow = new Map<Integer, GridRow>();
        for (GridRow r : validRows) {
            String key = r.email.trim().toLowerCase();
            if (duplicateRegEmails.contains(key)) {
                // Existing registration: update Status if provided and different
                String s = String.isBlank(r.status) ? defaultStatus : r.status;
                if (String.isBlank(s)) s = 'Pending';
                Registration__c existing = existingRegByEmail.get(key);
                if (!validateOnly && existing != null && existing.Status__c != s) {
                    Registration__c upd = new Registration__c(Id = existing.Id, Status__c = s);
                    updIndexToRow.put(toUpdateRegs.size(), r);
                    toUpdateRegs.add(upd);
                    continue;
                } else {
                    RowResult rr = findRowResult(resp.rows, r.id, r.email);
                    rr.success = false;
                    rr.message = validateOnly ? 'Would update existing registration (no changes)' : 'Already registered for this event';
                    resp.duplicates++;
                    continue;
                }
            }
            Id aId = emailToAttId.get(key);
            if (aId == null) {
                // Attendee failed to insert earlier
                RowResult rr = findRowResult(resp.rows, r.id, r.email);
                if (String.isBlank(rr.message)) rr.message = 'Attendee could not be created';
                resp.errors++;
                continue;
            }
            // Record resolved attendee on row
            RowResult rrExisting = findRowResult(resp.rows, r.id, r.email);
            rrExisting.attendeeId = aId;
            String s = String.isBlank(r.status) ? defaultStatus : r.status;
            if (String.isBlank(s)) s = 'Pending';
            Registration__c reg = new Registration__c(
                Event__c = eventId,
                Attendee__c = aId,
                Status__c = s,
                Registration_Date__c = Date.today(),
                Payment_Status__c = 'Pending'
            );
            regIndexToRow.put(toInsertRegs.size(), r);
            toInsertRegs.add(reg);
        }

        if (!toInsertRegs.isEmpty()) {
            Database.SaveResult[] regResults = Database.insert(toInsertRegs, false);
            for (Integer i = 0; i < regResults.size(); i++) {
                Database.SaveResult sr = regResults[i];
                GridRow r = regIndexToRow.get(i);
                RowResult rr = findRowResult(resp.rows, r.id, r.email);
                if (sr.isSuccess()) {
                    rr.success = true;
                    rr.registrationId = sr.getId();
                    rr.message = 'Registered';
                    resp.registrationInserts++;
                } else {
                    rr.success = false;
                    rr.message = 'Failed to register: ' + joinErrors(sr.getErrors());
                    resp.errors++;
                }
            }
        }

        if (!toUpdateRegs.isEmpty()) {
            Database.SaveResult[] updResults = Database.update(toUpdateRegs, false);
            for (Integer i = 0; i < updResults.size(); i++) {
                Database.SaveResult sr = updResults[i];
                GridRow r = updIndexToRow.get(i);
                RowResult rr = findRowResult(resp.rows, r.id, r.email);
                if (sr.isSuccess()) {
                    rr.success = true;
                    rr.message = 'Registration status updated';
                } else {
                    rr.success = false;
                    rr.message = 'Failed to update status: ' + joinErrors(sr.getErrors());
                    resp.errors++;
                }
            }
        }

        resp.success = (resp.errors == 0);
        return resp;
    }

    private static RowResult findRowResult(List<RowResult> rows, String id, String email) {
        for (RowResult rr : rows) {
            if ((id != null && rr.id == id) || (!String.isBlank(email) && rr.email == email)) {
                return rr;
            }
        }
        // fallback
        RowResult rr = new RowResult();
        rr.id = id;
        rr.email = email;
        rows.add(rr);
        return rr;
    }

    private static String joinErrors(Database.Error[] errors) {
        if (errors == null || errors.isEmpty()) return 'Unknown error';
        List<String> msgs = new List<String>();
        for (Database.Error e : errors) msgs.add(e.getMessage());
        return String.join(msgs, '; ');
    }
}
