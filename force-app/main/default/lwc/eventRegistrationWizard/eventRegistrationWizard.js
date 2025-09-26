import { LightningElement, track, api, wire } from 'lwc';
import { createRecord, getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { getListUi } from 'lightning/uiListApi';
import EVENT_OBJECT from '@salesforce/schema/Event__c';
import NAME_FIELD from '@salesforce/schema/Event__c.Name';
import TYPE_FIELD from '@salesforce/schema/Event__c.Event_Type__c';
import EVENT_DATE_FIELD from '@salesforce/schema/Event__c.Event_Date__c';
import START_DATE_FIELD from '@salesforce/schema/Event__c.Start_Date__c';
import MODE_FIELD from '@salesforce/schema/Event__c.Mode__c';
import FEE_FIELD from '@salesforce/schema/Event__c.Registration_Fee__c';
import DESC_FIELD from '@salesforce/schema/Event__c.Description__c';

export default class EventRegistrationWizard extends LightningElement {
    @track currentStep = 1; // 1: Landing, 2: Lead, 3: Attendee, 4: Event, 5: Done

    // Optional: specific event to display on landing
    _eventId;
    _recordId;
    @track recordOrEventId; // reactive id used by wire
    @track selectedEventId;
    eventRecord;
    @api confirmOnCreate = false;

    @api
    get eventId() { return this._eventId; }
    set eventId(value) {
        this._eventId = value;
        this.updatePreferredId();
    }

    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        this.updatePreferredId();
    }

    updatePreferredId() {
        const newId = this._eventId || this._recordId;
        if (newId !== this.recordOrEventId) {
            this.recordOrEventId = newId;
            this.selectedEventId = newId || this.selectedEventId;
        }
    }

    // Lead fields
    @track leadFirstName = '';
    @track leadLastName = '';
    @track leadEmail = '';
    @track leadPhone = '';
    @track leadCompany = '';
    @track leadInterest = '';
    leadId;

    // Attendee fields
    @track attendeeName = '';
    @track attendeeEmail = '';
    @track attendeePhone = '';
    @track attendeeCompany = '';
    @track attendeeInterest = '';
    attendeeId;

    // Event selection
    @track eventOptions = [];
    // Wire event details when eventId provided
    @wire(getRecord, { recordId: '$recordOrEventId', fields: [NAME_FIELD, TYPE_FIELD, EVENT_DATE_FIELD, START_DATE_FIELD, MODE_FIELD, FEE_FIELD, DESC_FIELD] })
    wiredEvent({ error, data }) {
        if (data) {
            this.eventRecord = data;
            if (!this.selectedEventId) {
                this.selectedEventId = this.recordOrEventId;
            }
        } else if (error) {
            // eslint-disable-next-line no-console
            console.warn('Unable to load event by Id', error);
        }
    }

    // UI state
    @track saving = false;
    @track error;
    
    // Wire list views for Events (prefer 'All', fall back to 'Recent')
    @wire(getListUi, { objectApiName: EVENT_OBJECT, listViewApiName: 'All' })
    wiredEventsAll({ data, error }) {
        this.processListData(data, error, 'All');
    }

    @wire(getListUi, { objectApiName: EVENT_OBJECT, listViewApiName: 'Recent' })
    wiredEventsRecent({ data, error }) {
        // Use Recent only if we don't already have options from 'All'
        if (this.eventOptions && this.eventOptions.length) return;
        this.processListData(data, error, 'Recent');
    }

    // Progress classes
    get step1Class() { return this.classFor(1); }
    get step2Class() { return this.classFor(2); }
    get step3Class() { return this.classFor(3); }
    get step4Class() { return this.classFor(4); }
    get step5Class() { return this.classFor(5); }

    classFor(n) {
        const base = 'slds-progress__item';
        if (this.currentStep === n) return `${base} slds-is-active`;
        if (this.currentStep > n) return `${base} slds-is-completed`;
        return base;
    }

    // Step flags
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }

    get disableRegister() { return !this.selectedEventId; }

    // Combined disabled state for Register button (no complex template expressions)
    get registerDisabled() {
        return this.saving || this.disableRegister;
    }

    // Navigation
    gotoLead = () => { this.currentStep = 2; };
    gotoLanding = () => { this.currentStep = 1; };
    gotoAttendee = () => { this.currentStep = 3; };

    // Handle input changes
    handleLeadChange = (e) => {
        const field = e.target.dataset.field;
        const val = e.target.value;
        switch(field) {
            case 'FirstName': this.leadFirstName = val; break;
            case 'LastName': this.leadLastName = val; break;
            case 'Email': this.leadEmail = val; break;
            case 'Phone': this.leadPhone = val; break;
            case 'Company': this.leadCompany = val; break;
            case 'Event_Interest__c': this.leadInterest = val; break;
            default: break;
        }
    }

    handleAttendeeChange = (e) => {
        const field = e.target.dataset.field;
        const val = e.target.value;
        switch(field) {
            case 'Name': this.attendeeName = val; break;
            case 'Email__c': this.attendeeEmail = val; break;
            case 'Phone__c': this.attendeePhone = val; break;
            case 'Company__c': this.attendeeCompany = val; break;
            case 'Interest__c': this.attendeeInterest = val; break;
            default: break;
        }
    }

    // Create Lead
    saveLead = async () => {
        this.error = undefined;
        if (!this.leadLastName || !this.leadEmail) {
            this.error = 'Please enter Last Name and Email';
            return;
        }
        this.saving = true;
        try {
            const fields = {
                FirstName: this.leadFirstName || null,
                LastName: this.leadLastName,
                Email: this.leadEmail,
                Phone: this.leadPhone || null,
                Company: this.leadCompany || 'Individual',
                Event_Interest__c: this.leadInterest || null,
                Status: 'Open - Not Contacted'
            };
            const result = await createRecord({ apiName: 'Lead', fields });
            this.leadId = result.id;
            this.currentStep = 3; // Next: Attendee
        } catch (e) {
            this.error = this.normalizeError(e);
        } finally {
            this.saving = false;
        }
    }

    // Create Attendee__c
    saveAttendee = async () => {
        this.error = undefined;
        if (!this.attendeeName || !this.attendeeEmail) {
            this.error = 'Please enter Attendee Name and Email';
            return;
        }
        this.saving = true;
        try {
            const fields = {
                Name: this.attendeeName,
                Email__c: this.attendeeEmail,
                Phone__c: this.attendeePhone || null,
                Company__c: this.attendeeCompany || null,
                Interest__c: this.attendeeInterest || null,
                Lead_Source__c: this.leadId || null
            };
            const result = await createRecord({ apiName: 'Attendee__c', fields });
            this.attendeeId = result.id;
            this.currentStep = 4; // Next: Event selection
        } catch (e) {
            this.error = this.normalizeError(e);
        } finally {
            this.saving = false;
        }
    }

    // Build combobox options from list view data, with dedupe and preselect
    processListData(data, error, source) {
        if (!data) {
            // eslint-disable-next-line no-console
            if (error) console.warn('List view wire error', source, error);
            return;
        }
        const recs = (data.records && data.records.records) ? data.records.records : [];
        const opts = recs
            .map(r => ({ label: r.fields?.Name?.value, value: r.id }))
            .filter(opt => !!opt.label && !!opt.value);

        // Merge with existing options and dedupe by value
        const map = new Map();
        [...(this.eventOptions || []), ...opts].forEach(o => {
            if (o && o.value) map.set(o.value, o);
        });

        // Ensure preselected event appears if not present
        if (this.selectedEventId && !map.has(this.selectedEventId) && this.eventRecord) {
            const name = getFieldValue(this.eventRecord, NAME_FIELD);
            if (name) {
                map.set(this.selectedEventId, { label: name, value: this.selectedEventId });
            }
        }

        this.eventOptions = Array.from(map.values());
    }

    handleEventChange = (e) => {
        this.selectedEventId = e.detail.value;
    }

    // Create Registration__c (junction)
    createRegistration = async () => {
        this.error = undefined;
        if (!this.attendeeId || !this.selectedEventId) {
            this.error = 'Missing Attendee or Event selection';
            return;
        }
        this.saving = true;
        try {
            const fields = {
                Attendee__c: this.attendeeId,
                Event__c: this.selectedEventId,
                Status__c: this.confirmOnCreate ? 'Confirmed' : 'Pending'
            };
            await createRecord({ apiName: 'Registration__c', fields });
            this.currentStep = 5; // Done
        } catch (e) {
            this.error = this.normalizeError(e);
        } finally {
            this.saving = false;
        }
    }

    resetAll = () => {
        this.currentStep = 1;
        this.leadFirstName = '';
        this.leadLastName = '';
        this.leadEmail = '';
        this.leadPhone = '';
        this.leadCompany = '';
        this.leadInterest = '';
        this.leadId = undefined;

        this.attendeeName = '';
        this.attendeeEmail = '';
        this.attendeePhone = '';
        this.attendeeCompany = '';
        this.attendeeInterest = '';
        this.attendeeId = undefined;

        this.selectedEventId = undefined;
        this.error = undefined;
    }

    normalizeError(e) {
        if (!e) return 'Unknown error';
        if (Array.isArray(e.body)) {
            return e.body.map(err => err.message).join(', ');
        }
        if (e.body && typeof e.body.message === 'string') {
            return e.body.message;
        }
        return e.message || 'Unknown error';
    }

    // Landing details helpers
    get hasEvent() {
        return !!this.eventRecord;
    }
    get eventName() { return this.eventRecord ? getFieldValue(this.eventRecord, NAME_FIELD) : undefined; }
    get eventType() { return this.eventRecord ? getFieldValue(this.eventRecord, TYPE_FIELD) : undefined; }
    get eventMode() { return this.eventRecord ? getFieldValue(this.eventRecord, MODE_FIELD) : undefined; }
    get eventFee() { return this.eventRecord ? getFieldValue(this.eventRecord, FEE_FIELD) : undefined; }
    get eventDate() {
        if (!this.eventRecord) return undefined;
        return getFieldValue(this.eventRecord, EVENT_DATE_FIELD) || getFieldValue(this.eventRecord, START_DATE_FIELD);
    }
    get eventDescription() { return this.eventRecord ? getFieldValue(this.eventRecord, DESC_FIELD) : undefined; }
}
