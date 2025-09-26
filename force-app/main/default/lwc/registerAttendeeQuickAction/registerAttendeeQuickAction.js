import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord } from 'lightning/uiRecordApi';
import getAttendees from '@salesforce/apex/BulkRegistrationController.getAttendees';
import createBulkRegistrations from '@salesforce/apex/BulkRegistrationController.createBulkRegistrations';

const EVENT_FIELDS = ['Event__c.Name', 'Event__c.Capacity__c', 'Event__c.Attendee_Count__c'];

export default class RegisterAttendeeQuickAction extends LightningElement {
    @api recordId; // Event ID
    @track selectedAttendeeId = '';
    @track attendeeOptions = [];
    @track isLoading = false;
    @track eventDetails = {};

    @wire(getRecord, { recordId: '$recordId', fields: EVENT_FIELDS })
    wiredEvent({ error, data }) {
        if (data) {
            this.eventDetails = {
                name: data.fields.Name.value,
                capacity: data.fields.Capacity__c.value,
                attendeeCount: data.fields.Attendee_Count__c.value || 0
            };
        } else if (error) {
            this.showToast('Error', 'Failed to load event details', 'error');
        }
    }

    @wire(getAttendees, { searchTerm: '', sortBy: 'Name', sortDirection: 'asc' })
    wiredAttendees({ error, data }) {
        if (data) {
            this.attendeeOptions = data.map(attendee => ({
                label: `${attendee.Name} (${attendee.Email__c})`,
                value: attendee.Id
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load attendees', 'error');
        }
    }

    handleAttendeeChange(event) {
        this.selectedAttendeeId = event.detail.value;
    }

    async handleRegister() {
        if (!this.selectedAttendeeId) {
            this.showToast('Warning', 'Please select an attendee to register', 'warning');
            return;
        }

        // Check capacity
        if (this.eventDetails.capacity && 
            (this.eventDetails.attendeeCount + 1) > this.eventDetails.capacity) {
            this.showToast('Error', 'Event is at full capacity', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const result = await createBulkRegistrations({
                eventId: this.recordId,
                attendeeIds: [this.selectedAttendeeId]
            });

            if (result.success) {
                this.showToast('Success', 'Attendee registered successfully', 'success');
                this.closeAction();
            } else {
                this.showToast('Error', 'Failed to register attendee', 'error');
            }
        } catch (error) {
            this.showToast('Error', 'Registration failed: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.closeAction();
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get eventName() {
        return this.eventDetails.name || 'Loading...';
    }

    get capacityInfo() {
        if (this.eventDetails.capacity) {
            return `${this.eventDetails.attendeeCount} / ${this.eventDetails.capacity} registered`;
        }
        return `${this.eventDetails.attendeeCount} registered`;
    }

    get canRegister() {
        return this.selectedAttendeeId && !this.isLoading;
    }
}
