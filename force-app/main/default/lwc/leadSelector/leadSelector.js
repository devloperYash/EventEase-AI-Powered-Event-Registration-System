import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Event fields
import NAME_FIELD from '@salesforce/schema/Event__c.Name';
import EVENT_TYPE_FIELD from '@salesforce/schema/Event__c.Event_Type__c';

// Apex methods (will be created)
import searchLeads from '@salesforce/apex/LeadSelectorController.searchLeads';
import sendEmailsToSelectedLeads from '@salesforce/apex/LeadSelectorController.sendEmailsToSelectedLeads';

const COLUMNS = [
    {
        label: 'Name',
        fieldName: 'Name',
        type: 'text',
        sortable: true
    },
    {
        label: 'Email',
        fieldName: 'Email',
        type: 'email',
        sortable: true
    },
    {
        label: 'Company',
        fieldName: 'Company',
        type: 'text',
        sortable: true
    },
    {
        label: 'Status',
        fieldName: 'Status',
        type: 'text',
        sortable: true
    },
    {
        label: 'Event Interest',
        fieldName: 'Event_Interest__c',
        type: 'text',
        sortable: true
    },
    {
        label: 'Created Date',
        fieldName: 'CreatedDate',
        type: 'date',
        sortable: true
    }
];

export default class LeadSelector extends LightningElement {
    @api recordId; // Event record ID
    
    @track leads = [];
    @track selectedLeads = [];
    @track selectedLeadIds = [];
    @track searchTerm = '';
    @track selectedInterest = '';
    @track selectedStatus = 'Qualified'; // Default to Qualified
    @track isLoading = false;
    @track showMessage = false;
    @track showPreview = false;
    @track messageTitle = '';
    @track messageText = '';
    @track messageClass = '';

    columns = COLUMNS;

    // Event fields to retrieve
    eventFields = [NAME_FIELD, EVENT_TYPE_FIELD];

    // Wire to get event record
    @wire(getRecord, { recordId: '$recordId', fields: '$eventFields' })
    eventRecord;

    // Picklist options
    interestOptions = [
        { label: 'All Interests', value: '' },
        { label: 'Conference', value: 'Conference' },
        { label: 'Workshop', value: 'Workshop' },
        { label: 'Seminar', value: 'Seminar' },
        { label: 'Training', value: 'Training' },
        { label: 'Networking', value: 'Networking' },
        { label: 'Webinar', value: 'Webinar' }
    ];

    statusOptions = [
        { label: 'All Statuses', value: '' },
        { label: 'New', value: 'New' },
        { label: 'Working', value: 'Working' },
        { label: 'Qualified', value: 'Qualified' },
        { label: 'Nurturing', value: 'Nurturing' }
    ];

    // Getters for event data
    get eventName() {
        return getFieldValue(this.eventRecord.data, NAME_FIELD) || 'Loading...';
    }

    get eventType() {
        return getFieldValue(this.eventRecord.data, EVENT_TYPE_FIELD) || 'Not specified';
    }

    get sendDisabled() {
        return this.isLoading || this.selectedLeads.length === 0;
    }

    // Use a getter for boolean template binding (avoid literal {false} in template)
    get hideCheckbox() {
        return false;
    }

    // Component lifecycle
    connectedCallback() {
        this.searchLeads();
    }

    // Event handlers
    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleInterestFilter(event) {
        this.selectedInterest = event.detail.value;
        this.searchLeads();
    }

    handleStatusFilter(event) {
        this.selectedStatus = event.detail.value;
        this.searchLeads();
    }

    handleRowSelection(event) {
        this.selectedLeads = event.detail.selectedRows;
        this.selectedLeadIds = this.selectedLeads.map(lead => lead.Id);
        this.showPreview = this.selectedLeads.length > 0;
    }

    // Action methods
    searchLeads() {
        this.isLoading = true;
        this.showMessage = false;
        
        const searchParams = {
            searchTerm: this.searchTerm,
            eventInterest: this.selectedInterest,
            status: this.selectedStatus,
            eventType: this.eventType
        };

        // Mock data for now - replace with actual Apex call
        setTimeout(() => {
            this.leads = this.generateMockLeads();
            this.isLoading = false;
            this.showToast('Success', `Found ${this.leads.length} leads matching your criteria`, 'success');
        }, 1500);

        /* Uncomment when Apex controller is ready
        searchLeads(searchParams)
            .then(result => {
                this.leads = result.map(lead => ({
                    ...lead,
                    Name: `${lead.FirstName || ''} ${lead.LastName || ''}`.trim()
                }));
                this.isLoading = false;
                this.showToast('Success', `Found ${this.leads.length} leads`, 'success');
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to search leads: ' + error.body.message, 'error');
            });
        */
    }

    selectAllLeads() {
        this.selectedLeadIds = this.leads.map(lead => lead.Id);
        this.selectedLeads = [...this.leads];
        this.showPreview = true;
        this.showToast('Info', `Selected all ${this.leads.length} leads`, 'info');
    }

    clearAllLeads() {
        this.selectedLeadIds = [];
        this.selectedLeads = [];
        this.showPreview = false;
        this.showToast('Info', 'Cleared all selections', 'info');
    }

    sendEmails() {
        if (this.selectedLeads.length === 0) {
            this.showToast('Warning', 'Please select at least one lead', 'warning');
            return;
        }

        this.isLoading = true;
        this.showMessage = false;

        // Mock email sending - replace with actual Apex call
        setTimeout(() => {
            this.messageTitle = '✅ Success!';
            this.messageText = `Event invitations sent successfully!\n\n📧 Recipients: ${this.selectedLeads.length} selected leads\n🎯 Event: ${this.eventName}\n📝 Activity records created for tracking\n\n💡 Next steps:\n• Monitor lead responses\n• Check activity history on lead records\n• Follow up with interested prospects`;
            this.messageClass = 'slds-notify slds-notify_alert slds-theme_success';
            this.showMessage = true;
            this.isLoading = false;
            
            // Clear selections after successful send
            this.clearAllLeads();
            
            this.showToast('Success', `Invitations sent to ${this.selectedLeads.length} leads!`, 'success');
        }, 2000);

        /* Uncomment when Apex controller is ready
        const emailParams = {
            leadIds: this.selectedLeadIds,
            eventId: this.recordId
        };

        sendEmailsToSelectedLeads(emailParams)
            .then(result => {
                this.messageTitle = '✅ Success!';
                this.messageText = result;
                this.messageClass = 'slds-notify slds-notify_alert slds-theme_success';
                this.showMessage = true;
                this.isLoading = false;
                this.clearAllLeads();
                this.showToast('Success', 'Invitations sent successfully!', 'success');
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to send emails: ' + error.body.message, 'error');
            });
        */
    }

    // Utility methods
    generateMockLeads() {
        const mockLeads = [
            {
                Id: '00Q1',
                Name: 'Priya Sharma',
                Email: 'priya.sharma@example.com',
                Company: 'Tech Solutions',
                Status: 'Qualified',
                Event_Interest__c: 'Conference',
                CreatedDate: new Date().toISOString()
            },
            {
                Id: '00Q2',
                Name: 'Rahul Kumar',
                Email: 'rahul.kumar@example.com',
                Company: 'Digital Corp',
                Status: 'Qualified',
                Event_Interest__c: 'Workshop',
                CreatedDate: new Date().toISOString()
            },
            {
                Id: '00Q3',
                Name: 'Anita Patel',
                Email: 'anita.patel@example.com',
                Company: 'Innovation Hub',
                Status: 'Working',
                Event_Interest__c: 'Seminar',
                CreatedDate: new Date().toISOString()
            },
            {
                Id: '00Q4',
                Name: 'Vikash Singh',
                Email: 'vikash.singh@example.com',
                Company: 'StartUp Inc',
                Status: 'Qualified',
                Event_Interest__c: 'Training',
                CreatedDate: new Date().toISOString()
            },
            {
                Id: '00Q5',
                Name: 'Meera Gupta',
                Email: 'meera.gupta@example.com',
                Company: 'Business Solutions',
                Status: 'Qualified',
                Event_Interest__c: 'Networking',
                CreatedDate: new Date().toISOString()
            }
        ];

        // Filter based on current criteria
        return mockLeads.filter(lead => {
            const matchesSearch = !this.searchTerm || 
                lead.Name.toLowerCase().includes(this.searchTerm.toLowerCase()) ||
                lead.Email.toLowerCase().includes(this.searchTerm.toLowerCase());
            
            const matchesInterest = !this.selectedInterest || 
                lead.Event_Interest__c === this.selectedInterest;
            
            const matchesStatus = !this.selectedStatus || 
                lead.Status === this.selectedStatus;
            
            return matchesSearch && matchesInterest && matchesStatus;
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
