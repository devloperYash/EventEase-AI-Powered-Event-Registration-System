import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';

import getEventStats from '@salesforce/apex/EventDashboardController.getEventStats';
import closeRegistrations from '@salesforce/apex/EventDashboardController.closeRegistrations';
import sendReminderEmails from '@salesforce/apex/EventDashboardController.sendReminderEmails';
import sendPromotionMails from '@salesforce/apex/EventLeadEmailController.sendPromotionMails';
import getNewLeadsForEvent from '@salesforce/apex/EventLeadEmailController.getNewLeadsForEvent';
import getEventRegistrations from '@salesforce/apex/BulkRegistrationController.getEventRegistrations';

export default class EventDashboard extends NavigationMixin(LightningElement) {
    @api recordId; // Event__c Id
    @track stats;
    @track loading = false;
    @track message;
    @track sendingPromotion = false;
    @track newLeads = [];
    @track registrations = [];

    leadColumns = [
        { label: 'First Name', fieldName: 'FirstName' },
        { label: 'Last Name', fieldName: 'LastName' },
        { label: 'Email', fieldName: 'Email', type: 'email' },
        { label: 'Company', fieldName: 'Company' },
        { label: 'Status', fieldName: 'Status' }
    ];

    registrationColumns = [
        { label: 'Attendee', fieldName: 'attendeeName' },
        { label: 'Email', fieldName: 'attendeeEmail', type: 'email' },
        { label: 'Status', fieldName: 'Status__c' },
        { label: 'Payment', fieldName: 'Payment_Status__c' },
        { label: 'Registered', fieldName: 'Registration_Date__c', type: 'date' }
    ];

    connectedCallback() {
        this.refresh();
    }

    async refresh() {
        if (!this.recordId) return;
        this.loading = true;
        this.message = undefined;
        try {
            this.stats = await getEventStats({ eventId: this.recordId });
            await this.loadLeadPreview();
            await this.loadRegistrations();
        } catch (e) {
            this.showToast('Error', this.errorMessage(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    async loadLeadPreview() {
        try {
            this.newLeads = await getNewLeadsForEvent({ eventId: this.recordId, maxRecords: 10 });
        } catch (e) {
            // Non-blocking: just clear on error
            this.newLeads = [];
        }
    }

    get hasNewLeads() {
        return Array.isArray(this.newLeads) && this.newLeads.length > 0;
    }

    async loadRegistrations() {
        try {
            const raw = await getEventRegistrations({ eventId: this.recordId });
            this.registrations = (raw || []).map(r => ({
                Id: r.Id,
                attendeeName: r.Attendee__r ? r.Attendee__r.Name : '',
                attendeeEmail: r.Attendee__r ? r.Attendee__r.Email__c : '',
                Status__c: r.Status__c,
                Payment_Status__c: r.Payment_Status__c,
                Registration_Date__c: r.Registration_Date__c
            }));
        } catch (e) {
            this.registrations = [];
        }
    }

    get hasRegistrations() {
        return Array.isArray(this.registrations) && this.registrations.length > 0;
    }

    get capacityPercent() {
        if (!this.stats || !this.stats.capacity) return 0;
        const used = this.stats.attendeeCount || 0;
        const cap = this.stats.capacity || 0;
        if (!cap) return 0;
        return Math.min(100, Math.round((used / cap) * 100));
    }

    get capacityLabel() {
        const used = this.stats?.attendeeCount || 0;
        const cap = this.stats?.capacity || 0;
        return `Capacity: ${used}/${cap}`;
    }

    get totalRegistrationsLabel() {
        return `Registrations: ${this.stats?.totalRegistrations || 0}`;
    }

    get feedbackLabel() {
        return `Feedback: ${this.stats?.feedbackCount || 0}`;
    }

    get confirmedLabel() {
        return `Confirmed: ${this.stats?.confirmed || 0}`;
    }

    get pendingLabel() {
        return `Pending: ${this.stats?.pending || 0}`;
    }

    get cancelledLabel() {
        return `Cancelled: ${this.stats?.cancelled || 0}`;
    }

    get startDateFormatted() {
        if (!this.stats?.startDate) return '';
        try {
            return new Date(this.stats.startDate).toLocaleDateString();
        } catch (e) {
            return this.stats.startDate;
        }
    }

    async handleCloseRegistration() {
        if (!this.recordId) return;
        this.loading = true;
        try {
            const msg = await closeRegistrations({ eventId: this.recordId });
            this.showToast('Success', msg, 'success');
            await this.refresh();
        } catch (e) {
            this.showToast('Error', this.errorMessage(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    async handleSendReminders() {
        if (!this.recordId) return;
        this.loading = true;
        try {
            const msg = await sendReminderEmails({ eventId: this.recordId, target: 'PendingPayment' });
            this.showToast('Success', msg, 'success');
        } catch (e) {
            this.showToast('Error', this.errorMessage(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    async handleSendPromotionMails() {
        if (!this.recordId) return;
        this.sendingPromotion = true;
        try {
            const msg = await sendPromotionMails({ eventId: this.recordId });
            if (msg && msg.toLowerCase().startsWith('no new leads')) {
                this.showToast('Info', msg, 'info');
            } else {
                this.showToast('Success', msg, 'success');
            }
            // Refresh preview after sending to reflect status changes
            await this.loadLeadPreview();
        } catch (e) {
            this.showToast('Error', this.errorMessage(e), 'error');
        } finally {
            this.sendingPromotion = false;
        }
    }

    navigateToSingleRegistration = () => {
        // Navigate to create a new Registration__c with default Event__c
        const defaultValues = encodeDefaultFieldValues({
            Event__c: this.recordId,
            Status__c: 'Pending',
            Payment_Status__c: 'Pending'
        });
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Registration__c',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: defaultValues
            }
        });
    }

    navigateToBulkRegistration = () => {
        // Provide a hint toast; component is expected on the page
        this.showToast('Info', 'Scroll to the Bulk Registration component on this page to add multiple attendees.', 'info');
        // Optionally dispatch an event for parent container to focus/scroll
        this.dispatchEvent(new CustomEvent('focusbulkregistration'));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errorMessage(e) {
        return e?.body?.message || e?.message || 'Unknown error';
    }
}
