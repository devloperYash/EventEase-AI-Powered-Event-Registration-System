import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getEventDetails from '@salesforce/apex/EventLeadEmailController.getEventDetails';
import getLeadsForEvent from '@salesforce/apex/EventLeadEmailController.getLeadsForEvent';
import sendEventInvitations from '@salesforce/apex/EventLeadEmailController.sendEventInvitations';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name', type: 'text' },
    { label: 'Email', fieldName: 'Email', type: 'email' },
    { label: 'Company', fieldName: 'Company', type: 'text' },
    { label: 'Status', fieldName: 'Status', type: 'text' },
    { label: 'Interest', fieldName: 'Event_Interest__c', type: 'text' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' }
];

export default class EventLeadEmailSender extends NavigationMixin(LightningElement) {
    @api recordId; // Event ID passed from record page
    
    @track eventName = '';
    @track eventDate = '';
    @track eventMode = '';
    @track eventFee = '';
    @track leads = [];
    @track selectedLeadIds = [];
    @track selectedStatus = '';
    @track selectedInterest = '';
    @track selectAll = false;
    @track isSending = false;
    @track showMessage = false;
    @track message = '';
    @track messageClass = '';

    columns = COLUMNS;

    statusOptions = [
        { label: 'All Statuses', value: '' },
        { label: 'New', value: 'New' },
        { label: 'Working', value: 'Working' },
        { label: 'Qualified', value: 'Qualified' },
        { label: 'Nurturing', value: 'Nurturing' }
    ];

    interestOptions = [
        { label: 'All Interests', value: '' },
        { label: 'Conference', value: 'Conference' },
        { label: 'Workshop', value: 'Workshop' },
        { label: 'Seminar', value: 'Seminar' },
        { label: 'Training', value: 'Training' },
        { label: 'Networking', value: 'Networking' }
    ];

    connectedCallback() {
        this.loadEventDetails();
        this.loadLeads();
    }

    loadEventDetails() {
        if (this.recordId) {
            getEventDetails({ eventId: this.recordId })
                .then(result => {
                    this.eventName = result.Name || 'N/A';
                    this.eventDate = result.Event_Date__c ? 
                        new Date(result.Event_Date__c).toLocaleDateString() : 
                        (result.Start_Date__c ? new Date(result.Start_Date__c).toLocaleDateString() : 'N/A');
                    this.eventMode = result.Mode__c || 'N/A';
                    this.eventFee = result.Registration_Fee__c ? 
                        `₹${result.Registration_Fee__c}` : 'FREE';
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to load event details: ' + error.body.message, 'error');
                });
        }
    }

    loadLeads() {
        getLeadsForEvent({ 
            eventId: this.recordId,
            status: this.selectedStatus,
            interest: this.selectedInterest
        })
        .then(result => {
            this.leads = result.map(lead => ({
                ...lead,
                Name: `${lead.FirstName || ''} ${lead.LastName || ''}`.trim()
            }));
            this.selectedLeadIds = [];
            this.selectAll = false;
        })
        .catch(error => {
            this.showToast('Error', 'Failed to load leads: ' + error.body.message, 'error');
        });
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.loadLeads();
    }

    handleInterestChange(event) {
        this.selectedInterest = event.detail.value;
        this.loadLeads();
    }

    handleSelectAll(event) {
        this.selectAll = event.target.checked;
        if (this.selectAll) {
            this.selectedLeadIds = this.leads.map(lead => lead.Id);
        } else {
            this.selectedLeadIds = [];
        }
    }

    handleRowSelection(event) {
        this.selectedLeadIds = event.detail.selectedRows.map(row => row.Id);
        this.selectAll = this.selectedLeadIds.length === this.leads.length;
    }

    get emailPreview() {
        if (!this.eventName) return '';
        
        return `
            <p><strong>Dear [Lead Name],</strong></p>
            <p>We have an exciting event that matches your interests!</p>
            <br/>
            <p><strong>🎯 EVENT DETAILS:</strong></p>
            <p>📌 Event: ${this.eventName}</p>
            <p>📅 Date: ${this.eventDate}</p>
            <p>📍 Mode: ${this.eventMode}</p>
            <p>💰 Fee: ${this.eventFee}</p>
            <br/>
            <p><strong>🚀 HOW TO REGISTER:</strong></p>
            <p>1. Reply to this email with "REGISTER FOR ${this.eventName}"</p>
            <p>2. Call our registration team</p>
            <p>3. Visit our EventEase portal</p>
            <br/>
            <p>⏰ Don't miss out - Limited seats available!</p>
            <p>Best regards,<br/>EventEase Team</p>
        `;
    }

    sendInvitations() {
        if (this.selectedLeadIds.length === 0) {
            this.showToast('Warning', 'Please select at least one lead to send invitations.', 'warning');
            return;
        }

        this.isSending = true;
        
        sendEventInvitations({ 
            leadIds: this.selectedLeadIds, 
            eventId: this.recordId 
        })
        .then(result => {
            this.showToast('Success', result, 'success');
            this.selectedLeadIds = [];
            this.selectAll = false;
            this.loadLeads(); // Refresh the leads list
        })
        .catch(error => {
            this.showToast('Error', 'Failed to send invitations: ' + error.body.message, 'error');
        })
        .finally(() => {
            this.isSending = false;
        });
    }

    handleCancel() {
        // Navigate back to the event record
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }
}
