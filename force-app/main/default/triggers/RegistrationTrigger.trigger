trigger RegistrationTrigger on Registration__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            // Populate composite key (handles both insert and update scenarios)
            RegistrationTriggerHandler.populateCompositeKey(Trigger.new, Trigger.oldMap);
            // Enforce capacity
            RegistrationTriggerHandler.beforeInsertOrUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            // Recalc counts for current events
            Set<Id> newEventIds = new Set<Id>();
            for (Registration__c r : Trigger.new) if (r.Event__c != null) newEventIds.add(r.Event__c);
            RegistrationTriggerHandler.afterChange(newEventIds, null);
            // Post-insert automation
            RegistrationTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            Set<Id> newEventIds = new Set<Id>();
            Set<Id> oldEventIds = new Set<Id>();
            for (Registration__c r : Trigger.new) if (r.Event__c != null) newEventIds.add(r.Event__c);
            for (Registration__c r : Trigger.old) if (r.Event__c != null) oldEventIds.add(r.Event__c);
            RegistrationTriggerHandler.afterChange(newEventIds, oldEventIds);
            // Post-update automation (e.g., send confirmation email when status changes to Confirmed)
            RegistrationTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            Set<Id> oldEventIds = new Set<Id>();
            for (Registration__c r : Trigger.old) if (r.Event__c != null) oldEventIds.add(r.Event__c);
            RegistrationTriggerHandler.afterChange(null, oldEventIds);
        } else if (Trigger.isUndelete) {
            Set<Id> newEventIds = new Set<Id>();
            for (Registration__c r : Trigger.new) if (r.Event__c != null) newEventIds.add(r.Event__c);
            RegistrationTriggerHandler.afterChange(newEventIds, null);
        }
    }
}
