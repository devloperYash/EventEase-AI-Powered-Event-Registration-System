public with sharing class RegistrationTriggerHandler {
    public static final Set<String> COUNTING_STATUSES = new Set<String>{ 'Confirmed', 'Approved' };
    
    // Enforce capacity before saving records
    public static void beforeInsertOrUpdate(List<Registration__c> newList, Map<Id, Registration__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // Gather affected Event Ids from both new and old records
        Set<Id> eventIds = new Set<Id>();
        for (Registration__c r : newList) {
            if (r.Event__c != null) {
                eventIds.add(r.Event__c);
            }
        }
        
        // Also include old event IDs for updates (in case event is changing)
        if (oldMap != null) {
            for (Registration__c oldR : oldMap.values()) {
                if (oldR.Event__c != null) {
                    eventIds.add(oldR.Event__c);
                }
            }
        }
        
        if (eventIds.isEmpty()) return;

        // Current confirmed counts for the affected events (existing DB state)
        Map<Id, Integer> confirmedCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Event__c, COUNT(Id) cnt
            FROM Registration__c
            WHERE Event__c IN :eventIds AND Status__c IN :COUNTING_STATUSES
            GROUP BY Event__c
        ]) {
            Id eId = (Id) ar.get('Event__c');
            Integer c = (Integer) ar.get('cnt');
            confirmedCounts.put(eId, c);
        }

        // Event capacities, dates and status
        Map<Id, Event__c> eventMap = new Map<Id, Event__c>([
            SELECT Id, Capacity__c, Start_Date__c, Event_Date__c, Status__c
            FROM Event__c
            WHERE Id IN :eventIds
        ]);

        // Track pending net changes per event to prevent bulk over-allocation
        Map<Id, Integer> pendingNetChanges = new Map<Id, Integer>();

        Datetime nowDt = System.now();
        Date today = Date.today();

        for (Registration__c r : newList) {
            if (r.Event__c == null) continue;

            // Block new registrations when event registrations are closed/completed/cancelled
            if (oldMap == null || !oldMap.containsKey(r.Id)) {
                Event__c evStatusCheck = eventMap.get(r.Event__c);
                if (evStatusCheck != null &&
                    (evStatusCheck.Status__c == 'Registration Closed' ||
                     evStatusCheck.Status__c == 'Completed' ||
                     evStatusCheck.Status__c == 'Cancelled')) {
                    r.addError('Registrations are closed for this event.');
                    continue;
                }
            }

            // Determine old state
            Boolean wasCountedInOldEvent = false;
            Boolean wasCountedInNewEvent = false;
            Id oldEventId = null;
            String oldStatus = null;
            
            if (oldMap != null && oldMap.containsKey(r.Id)) {
                Registration__c oldR = oldMap.get(r.Id);
                oldEventId = oldR != null ? oldR.Event__c : null;
                oldStatus = oldR != null ? oldR.Status__c : null;
                wasCountedInOldEvent = (oldR != null && COUNTING_STATUSES.contains(oldR.Status__c));
                // If event is changing, check if old record was counted in the NEW event
                wasCountedInNewEvent = (oldEventId == r.Event__c && wasCountedInOldEvent);
            }
            
            Boolean newIsCounted = COUNTING_STATUSES.contains(r.Status__c);
            // Note: With dual master-detail, Event__c cannot change after insert
            Boolean isEventChanging = false; // Disabled due to master-detail constraint
            
            // Determine if this will increase count for the target event
            Boolean willIncreaseCount = newIsCounted && !wasCountedInNewEvent;

            // If event is closed/completed/cancelled, block any update that would increase counted registrations
            if (willIncreaseCount) {
                Event__c evStatusCheck2 = eventMap.get(r.Event__c);
                if (evStatusCheck2 != null &&
                    (evStatusCheck2.Status__c == 'Registration Closed' ||
                     evStatusCheck2.Status__c == 'Completed' ||
                     evStatusCheck2.Status__c == 'Cancelled')) {
                    r.addError('Registrations are closed for this event.');
                    continue;
                }
            }
            
            // Past event validation - only for new counting statuses or event changes
            Boolean mustValidateEventDate = (oldMap == null) || isEventChanging || 
                (newIsCounted && !COUNTING_STATUSES.contains(oldStatus));
                
            if (mustValidateEventDate && newIsCounted) {
                Event__c evDateCheck = eventMap.get(r.Event__c);
                if (evDateCheck != null) {
                    Boolean isPast = false;
                    if (evDateCheck.Event_Date__c != null && evDateCheck.Event_Date__c < nowDt) {
                        isPast = true;
                    } else if (evDateCheck.Start_Date__c != null && evDateCheck.Start_Date__c < today) {
                        isPast = true;
                    }
                    if (isPast) {
                        r.addError('You cannot register for past events.');
                        continue;
                    }
                }
            }

            if (!willIncreaseCount) continue;

            // Calculate net change for capacity checking
            Integer currentNetChange = pendingNetChanges.containsKey(r.Event__c) ? 
                pendingNetChanges.get(r.Event__c) : 0;

            Event__c ev = eventMap.get(r.Event__c);
            Integer cap = null;
            if (ev != null && ev.Capacity__c != null) {
                cap = Integer.valueOf(ev.Capacity__c.intValue());
            }

            // Only enforce capacity if defined
            if (cap != null) {
                Integer baseCount = confirmedCounts.containsKey(r.Event__c) ? 
                    confirmedCounts.get(r.Event__c) : 0;
                    
                if ((baseCount + currentNetChange + 1) > cap) {
                    r.addError('Event capacity exceeded. No more registrations allowed.');
                } else {
                    pendingNetChanges.put(r.Event__c, currentNetChange + 1);
                }
            }
        }
    }

    // Populate composite unique key for duplicate prevention (Attendee__c|Event__c)
    public static void populateCompositeKey(List<Registration__c> newList) {
        populateCompositeKey(newList, null);
    }
    
    // Overloaded method to handle both insert and update scenarios
    public static void populateCompositeKey(List<Registration__c> newList, Map<Id, Registration__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;
        
        for (Registration__c r : newList) {
            Boolean shouldUpdateKey = false;
            
            // For new records or when key is empty
            if (r.Attendee_Event_Key__c == null || r.Attendee_Event_Key__c.trim().length() == 0) {
                shouldUpdateKey = true;
            }
            // For updates, check if Attendee or Event changed (Note: with dual master-detail, these cannot change)
            else if (oldMap != null && oldMap.containsKey(r.Id)) {
                Registration__c oldR = oldMap.get(r.Id);
                // With dual master-detail relationships, Attendee__c and Event__c cannot be changed after insert
                // This logic is kept for potential future flexibility but will not execute in current setup
                if (oldR != null && (oldR.Attendee__c != r.Attendee__c || oldR.Event__c != r.Event__c)) {
                    shouldUpdateKey = true;
                }
            }
            
            if (shouldUpdateKey && r.Attendee__c != null && r.Event__c != null) {
                r.Attendee_Event_Key__c = String.valueOf(r.Attendee__c) + '|' + String.valueOf(r.Event__c);
            }
        }
    }

    // After-insert automation: send confirmation email, recommend event, and create a task
    public static void afterInsert(List<Registration__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        Set<Id> attendeeIds = new Set<Id>();
        Set<Id> eventIds = new Set<Id>();
        for (Registration__c r : newList) {
            if (r.Attendee__c != null) attendeeIds.add(r.Attendee__c);
            if (r.Event__c != null) eventIds.add(r.Event__c);
        }
        if (attendeeIds.isEmpty() || eventIds.isEmpty()) return;

        Map<Id, Attendee__c> attendeeMap = new Map<Id, Attendee__c>([
            SELECT Id, Name, Email__c, Interest__c, Recommended_Event__c FROM Attendee__c WHERE Id IN :attendeeIds
        ]);
        Map<Id, Event__c> eventMap = new Map<Id, Event__c>([
            SELECT Id, Name, Event_Type__c, Start_Date__c, End_Date__c, Event_Date__c,
                   Mode__c, Meeting_Link__c, Venue__c, Venue_Address__c,
                   OwnerId, Owner.Name
            FROM Event__c
            WHERE Id IN :eventIds
        ]);

        List<Attendee__c> attendeeUpdates = new List<Attendee__c>();
        List<Task> tasksToCreate = new List<Task>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Registration__c r : newList) {
            Attendee__c a = attendeeMap.get(r.Attendee__c);
            Event__c e = eventMap.get(r.Event__c);
            if (a == null || e == null) continue;

            // Recommend current event for simplicity; can be replaced with smarter logic
            if (a.Recommended_Event__c == null) {
                attendeeUpdates.add(new Attendee__c(Id = a.Id, Recommended_Event__c = e.Id));
            }

            // Create task for the event owner
            Task t = new Task();
            t.OwnerId = e.OwnerId;
            t.Subject = 'New Attendee Registered';
            t.WhatId = e.Id; // related to the Event
            t.Description = 'Attendee: ' + a.Name + ' registered for Event: ' + e.Name;
            t.Status = 'Not Started';
            tasksToCreate.add(t);

            // Prepare registration receipt email (best-effort, ignore failures)
            if (a.Email__c != null) {
                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setToAddresses(new String[] { a.Email__c });
                msg.setSubject('Registration Received - ' + e.Name);
                String body = 'Hello ' + a.Name + ',\n\n' +
                              'We have received your registration. Here are the details:\n\n' +
                              'Registration Details:\n' +
                              (r.Name != null ? '- Registration No: ' + r.Name + '\n' : '') +
                              (r.Status__c != null ? '- Status: ' + r.Status__c + '\n' : '') +
                              (r.Payment_Status__c != null ? '- Payment Status: ' + r.Payment_Status__c + '\n' : '') +
                              (r.Amount__c != null ? '- Amount: ' + String.valueOf(r.Amount__c) + '\n' : '') +
                              '\nEvent Details:\n' +
                              '- Name: ' + e.Name + '\n' +
                              (e.Event_Type__c != null ? '- Type: ' + e.Event_Type__c + '\n' : '') +
                              (e.Event_Date__c != null ? '- Event Date/Time: ' + e.Event_Date__c.format('dd/MM/yyyy h:mm a z') + '\n' : '') +
                              (e.Start_Date__c != null ? '- Start Date: ' + e.Start_Date__c.format() + '\n' : '') +
                              (e.End_Date__c != null ? '- End Date: ' + e.End_Date__c.format() + '\n' : '') +
                              (e.Mode__c != null ? '- Mode: ' + e.Mode__c + '\n' : '');

                // Add mode-specific details with security check
                if (e.Mode__c == 'Virtual') {
                    // Only show meeting link if confirmed and paid
                    if (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid' && e.Meeting_Link__c != null) {
                        body += '- Join Link: ' + e.Meeting_Link__c + '\n';
                    } else {
                        body += '- Join Link: Will be shared after confirmation and payment completion\n';
                    }
                } else {
                    // Only show venue details if confirmed and paid
                    if (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid') {
                        body += (e.Venue__c != null ? '- Venue: ' + e.Venue__c + '\n' : '');
                        body += (e.Venue_Address__c != null ? '- Address: ' + e.Venue_Address__c + '\n' : '');
                    } else {
                        body += '- Venue details will be shared after confirmation and payment completion\n';
                    }
                }

                body += (e.Owner != null && e.Owner.Name != null ? '\nOrganizer: ' + e.Owner.Name + '\n' : '');
                body += '\nThanks,\nEventEase Team';

                // HTML version
                String html = '<html><body style="font-family:Arial,Helvetica,sans-serif; color:#111">'
                  + '<h2 style="color:#2E5AAC;margin:0 0 10px">Registration Received</h2>'
                  + '<p>Hello ' + a.Name + ',</p>'
                  + '<p>We have received your registration. Here are the details:</p>'
                  + '<h3 style="margin:16px 0 8px">Registration Details</h3>'
                  + '<table cellpadding="6" cellspacing="0" style="border-collapse:collapse">'
                  +   (r.Name != null ? '<tr><td><b>Registration No</b></td><td>' + r.Name + '</td></tr>' : '')
                  +   (r.Status__c != null ? '<tr><td><b>Status</b></td><td>' + r.Status__c + '</td></tr>' : '')
                  +   (r.Payment_Status__c != null ? '<tr><td><b>Payment Status</b></td><td>' + r.Payment_Status__c + '</td></tr>' : '')
                  +   (r.Amount__c != null ? '<tr><td><b>Amount</b></td><td>' + String.valueOf(r.Amount__c) + '</td></tr>' : '')
                  + '</table>'
                  + '<h3 style="margin:16px 0 8px">Event Details</h3>'
                  + '<table cellpadding="6" cellspacing="0" style="border-collapse:collapse">'
                  +   '<tr><td><b>Name</b></td><td>' + e.Name + '</td></tr>'
                  +   (e.Event_Type__c != null ? '<tr><td><b>Type</b></td><td>' + e.Event_Type__c + '</td></tr>' : '')
                  +   (e.Event_Date__c != null ? '<tr><td><b>Event Date/Time</b></td><td>' + e.Event_Date__c.format('dd/MM/yyyy h:mm a z') + '</td></tr>' : '')
                  +   (e.Start_Date__c != null ? '<tr><td><b>Start Date</b></td><td>' + e.Start_Date__c.format() + '</td></tr>' : '')
                  +   (e.End_Date__c != null ? '<tr><td><b>End Date</b></td><td>' + e.End_Date__c.format() + '</td></tr>' : '')
                  +   (e.Mode__c != null ? '<tr><td><b>Mode</b></td><td>' + e.Mode__c + '</td></tr>' : '')
                  + '</table>'
                  + (e.Mode__c == 'Virtual' ? 
                      (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid' && e.Meeting_Link__c != null ? 
                        '<p><b>Join Link:</b> <a href="' + e.Meeting_Link__c + '" style="color:#2E5AAC">Join Meeting</a></p>' : 
                        '<p><b>Join Link:</b> Will be shared after confirmation and payment completion</p>') : '')
                  + (e.Mode__c != 'Virtual' ? 
                      (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid' ? 
                        ((e.Venue__c != null ? '<p><b>Venue:</b> ' + e.Venue__c + '</p>' : '') + (e.Venue_Address__c != null ? '<p><b>Address:</b> ' + e.Venue_Address__c + '</p>' : '')) : 
                        '<p><b>Venue details:</b> Will be shared after confirmation and payment completion</p>') : '')
                  + (e.Owner != null && e.Owner.Name != null ? '<p><b>Organizer:</b> ' + e.Owner.Name + '</p>' : '')
                  + '<p>Thanks,<br/>EventEase Team</p>'
                  + '</body></html>';

                msg.setHtmlBody(html);
                msg.setPlainTextBody(body);
                emails.add(msg);
            }
        }

        if (!attendeeUpdates.isEmpty()) {
            try { update attendeeUpdates; } catch (Exception ex) { /* ignore */ }
        }
        if (!tasksToCreate.isEmpty()) {
            try { insert tasksToCreate; } catch (Exception ex) { /* ignore */ }
        }
        if (!emails.isEmpty()) {
            try { Messaging.sendEmail(emails, false); } catch (Exception ex) { /* ignore */ }
        }
    }

    // After-update automation: send confirmation email only when Status transitions to Confirmed
    public static void afterUpdate(List<Registration__c> newList, Map<Id, Registration__c> oldMap) {
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) return;

        List<Registration__c> toNotify = new List<Registration__c>();
        for (Registration__c r : newList) {
            Registration__c oldR = oldMap.get(r.Id);
            if (oldR == null) continue;
            
            // Send email on ANY status or payment change
            Boolean statusChanged = (r.Status__c != oldR.Status__c);
            Boolean paymentChanged = (r.Payment_Status__c != oldR.Payment_Status__c);
            
            if (statusChanged || paymentChanged) {
                toNotify.add(r);
            }
        }
        if (toNotify.isEmpty()) return;

        Set<Id> attendeeIds = new Set<Id>();
        Set<Id> eventIds = new Set<Id>();
        for (Registration__c r : toNotify) {
            if (r.Attendee__c != null) attendeeIds.add(r.Attendee__c);
            if (r.Event__c != null) eventIds.add(r.Event__c);
        }
        if (attendeeIds.isEmpty() || eventIds.isEmpty()) return;

        Map<Id, Attendee__c> attendeeMap = new Map<Id, Attendee__c>([
            SELECT Id, Name, Email__c FROM Attendee__c WHERE Id IN :attendeeIds
        ]);
        Map<Id, Event__c> eventMap = new Map<Id, Event__c>([
            SELECT Id, Name, Event_Type__c, Start_Date__c, End_Date__c, Event_Date__c,
                   Mode__c, Meeting_Link__c, Venue__c, Venue_Address__c,
                   OwnerId, Owner.Name
            FROM Event__c WHERE Id IN :eventIds
        ]);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Registration__c r : toNotify) {
            Attendee__c a = attendeeMap.get(r.Attendee__c);
            Event__c e = eventMap.get(r.Event__c);
            if (a == null || e == null) continue;
            if (String.isBlank(a.Email__c)) continue;

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new String[] { a.Email__c });
            
            // Dynamic subject based on status
            String emailSubject = 'Registration Update - ' + e.Name;
            if (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid') {
                emailSubject = 'Registration Confirmed - ' + e.Name;
            } else if (r.Status__c == 'Confirmed') {
                emailSubject = 'Registration Confirmed (Payment Pending) - ' + e.Name;
            } else if (r.Status__c == 'Cancelled') {
                emailSubject = 'Registration Cancelled - ' + e.Name;
            }
            msg.setSubject(emailSubject);
            
            // Dynamic body content based on status
            String bodyIntro = 'Your registration has been updated.';
            if (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid') {
                bodyIntro = 'Your registration is confirmed and payment is complete.';
            } else if (r.Status__c == 'Confirmed') {
                bodyIntro = 'Your registration is confirmed. Please complete payment to receive full event details.';
            } else if (r.Status__c == 'Cancelled') {
                bodyIntro = 'Your registration has been cancelled.';
            }
            
            String body = 'Hello ' + a.Name + ',\n\n' +
                          bodyIntro + ' Here are the details:\n\n' +
                          'Registration Details:\n' +
                          (r.Name != null ? '- Registration No: ' + r.Name + '\n' : '') +
                          (r.Status__c != null ? '- Status: ' + r.Status__c + '\n' : '') +
                          (r.Payment_Status__c != null ? '- Payment Status: ' + r.Payment_Status__c + '\n' : '') +
                          (r.Amount__c != null ? '- Amount: ' + String.valueOf(r.Amount__c) + '\n' : '') +
                          '\nEvent Details:\n' +
                          '- Name: ' + e.Name + '\n' +
                          (e.Event_Type__c != null ? '- Type: ' + e.Event_Type__c + '\n' : '') +
                          (e.Event_Date__c != null ? '- Event Date/Time: ' + e.Event_Date__c.format('dd/MM/yyyy h:mm a z') + '\n' : '') +
                          (e.Start_Date__c != null ? '- Start Date: ' + e.Start_Date__c.format() + '\n' : '') +
                          (e.End_Date__c != null ? '- End Date: ' + e.End_Date__c.format() + '\n' : '') +
                          (e.Mode__c != null ? '- Mode: ' + e.Mode__c + '\n' : '');

            if (e.Mode__c == 'Virtual') {
                // Only show meeting link if confirmed and paid
                if (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid' && e.Meeting_Link__c != null) {
                    body += '- Join Link: ' + e.Meeting_Link__c + '\n';
                } else {
                    body += '- Join Link: Will be shared after confirmation and payment completion\n';
                }
            } else {
                // Only show venue details if confirmed and paid
                if (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid') {
                    body += (e.Venue__c != null ? '- Venue: ' + e.Venue__c + '\n' : '');
                    body += (e.Venue_Address__c != null ? '- Address: ' + e.Venue_Address__c + '\n' : '');
                } else {
                    body += '- Venue details will be shared after confirmation and payment completion\n';
                }
            }

            body += (e.Owner != null && e.Owner.Name != null ? '\nOrganizer: ' + e.Owner.Name + '\n' : '');
            
            // Dynamic closing message based on status
            String closingMessage = '\nThanks,\nEventEase Team';
            if (r.Status__c == 'Confirmed') {
                closingMessage = '\nWe look forward to seeing you!\n\nThanks,\nEventEase Team';
            } else if (r.Status__c == 'Cancelled') {
                closingMessage = '\nIf you have any questions about your cancellation, please contact us.\n\nThanks,\nEventEase Team';
            }
            body += closingMessage;

            // HTML version with dynamic content
            String htmlTitle = 'Registration Update';
            String htmlIntro = bodyIntro;
            if (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid') {
                htmlTitle = 'Registration Confirmed';
            } else if (r.Status__c == 'Cancelled') {
                htmlTitle = 'Registration Cancelled';
            }
            
            String html = '<html><body style="font-family:Arial,Helvetica,sans-serif; color:#111">'
              + '<h2 style="color:#2E5AAC;margin:0 0 10px">' + htmlTitle + '</h2>'
              + '<p>Hello ' + a.Name + ',</p>'
              + '<p>' + htmlIntro + ' Here are the details:</p>'
              + '<h3 style="margin:16px 0 8px">Registration Details</h3>'
              + '<table cellpadding="6" cellspacing="0" style="border-collapse:collapse">'
              +   (r.Name != null ? '<tr><td><b>Registration No</b></td><td>' + r.Name + '</td></tr>' : '')
              +   (r.Status__c != null ? '<tr><td><b>Status</b></td><td>' + r.Status__c + '</td></tr>' : '')
              +   (r.Payment_Status__c != null ? '<tr><td><b>Payment Status</b></td><td>' + r.Payment_Status__c + '</td></tr>' : '')
              +   (r.Amount__c != null ? '<tr><td><b>Amount</b></td><td>' + String.valueOf(r.Amount__c) + '</td></tr>' : '')
              + '</table>'
              + '<h3 style="margin:16px 0 8px">Event Details</h3>'
              + '<table cellpadding="6" cellspacing="0" style="border-collapse:collapse">'
              +   '<tr><td><b>Name</b></td><td>' + e.Name + '</td></tr>'
              +   (e.Event_Type__c != null ? '<tr><td><b>Type</b></td><td>' + e.Event_Type__c + '</td></tr>' : '')
              +   (e.Event_Date__c != null ? '<tr><td><b>Event Date/Time</b></td><td>' + e.Event_Date__c.format('dd/MM/yyyy h:mm a z') + '</td></tr>' : '')
              +   (e.Start_Date__c != null ? '<tr><td><b>Start Date</b></td><td>' + e.Start_Date__c.format() + '</td></tr>' : '')
              +   (e.End_Date__c != null ? '<tr><td><b>End Date</b></td><td>' + e.End_Date__c.format() + '</td></tr>' : '')
              +   (e.Mode__c != null ? '<tr><td><b>Mode</b></td><td>' + e.Mode__c + '</td></tr>' : '')
              + '</table>'
              + (e.Mode__c == 'Virtual' ? 
                  (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid' && e.Meeting_Link__c != null ? 
                    '<p><b>Join Link:</b> <a href="' + e.Meeting_Link__c + '" style="color:#2E5AAC">Join Meeting</a></p>' : 
                    '<p><b>Join Link:</b> Will be shared after confirmation and payment completion</p>') : '')
              + (e.Mode__c != 'Virtual' ? 
                  (r.Status__c == 'Confirmed' && r.Payment_Status__c == 'Paid' ? 
                    ((e.Venue__c != null ? '<p><b>Venue:</b> ' + e.Venue__c + '</p>' : '') + (e.Venue_Address__c != null ? '<p><b>Address:</b> ' + e.Venue_Address__c + '</p>' : '')) : 
                    '<p><b>Venue details:</b> Will be shared after confirmation and payment completion</p>') : '')
              + (e.Owner != null && e.Owner.Name != null ? '<p><b>Organizer:</b> ' + e.Owner.Name + '</p>' : '');
              
            // Dynamic HTML closing
            if (r.Status__c == 'Confirmed') {
                html += '<p>We look forward to seeing you!</p>';
            } else if (r.Status__c == 'Cancelled') {
                html += '<p>If you have any questions about your cancellation, please contact us.</p>';
            }
            html += '<p>Thanks,<br/>EventEase Team</p></body></html>';

            msg.setHtmlBody(html);
            msg.setPlainTextBody(body);
            emails.add(msg);
        }

        if (!emails.isEmpty()) {
            try { Messaging.sendEmail(emails, false); } catch (Exception ex) { /* ignore */ }
        }
    }

    // Recalculate and persist Attendee_Count__c for all impacted events
    public static void afterChange(Set<Id> newEventIds, Set<Id> oldEventIds) {
        Set<Id> eventIds = new Set<Id>();
        if (newEventIds != null) eventIds.addAll(newEventIds);
        if (oldEventIds != null) eventIds.addAll(oldEventIds);
        if (eventIds.isEmpty()) return;

        // Get current confirmed counts per event
        Map<Id, Integer> countsByEvent = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Event__c, COUNT(Id) cnt
            FROM Registration__c
            WHERE Event__c IN :eventIds AND Status__c IN :COUNTING_STATUSES
            GROUP BY Event__c
        ]) {
            countsByEvent.put((Id) ar.get('Event__c'), (Integer) ar.get('cnt'));
        }

        List<Event__c> updates = new List<Event__c>();
        for (Id eId : eventIds) {
            Integer cnt = countsByEvent.containsKey(eId) ? countsByEvent.get(eId) : 0;
            updates.add(new Event__c(Id = eId, Attendee_Count__c = cnt));
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }
}
