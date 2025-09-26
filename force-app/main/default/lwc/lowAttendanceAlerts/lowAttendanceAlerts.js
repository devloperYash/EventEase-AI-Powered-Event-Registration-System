import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getLowAttendanceAlerts from '@salesforce/apex/LowAttendanceController.getLowAttendanceAlerts';
import sendReminderEmails from '@salesforce/apex/LowAttendanceController.sendReminderEmails';

export default class LowAttendanceAlerts extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track alertEvents = [];
    @track lastUpdated = '';
    
    // Threshold settings
    @track criticalThreshold = 30;
    @track warningThreshold = 50;
    @track lowThreshold = 70;
    
    // Summary counts
    @track criticalAlerts = 0;
    @track warningAlerts = 0;
    @track lowAlerts = 0;

    // Wired data
    wiredAlertsResult;

    @wire(getLowAttendanceAlerts, { 
        criticalThreshold: '$criticalThreshold',
        warningThreshold: '$warningThreshold',
        lowThreshold: '$lowThreshold'
    })
    wiredAlerts(result) {
        this.wiredAlertsResult = result;
        if (result.data) {
            this.processAlertData(result.data);
            this.isLoading = false;
            this.updateLastUpdated();
        } else if (result.error) {
            console.error('Error loading alerts:', result.error);
            this.showToast('Error', 'Failed to load attendance alerts', 'error');
            this.isLoading = false;
        }
    }

    // Computed properties
    get hasAlerts() {
        return this.alertEvents && this.alertEvents.length > 0;
    }

    // Event handlers
    handleThresholdChange(event) {
        const threshold = event.target.dataset.threshold;
        const value = parseInt(event.target.value, 10);
        
        if (threshold === 'critical') {
            this.criticalThreshold = value;
        } else if (threshold === 'warning') {
            this.warningThreshold = value;
        } else if (threshold === 'low') {
            this.lowThreshold = value;
        }
        
        // Debounce the refresh
        clearTimeout(this.thresholdTimeout);
        this.thresholdTimeout = setTimeout(() => {
            this.isLoading = true;
            refreshApex(this.wiredAlertsResult);
        }, 500);
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredAlertsResult);
    }

    handleViewEvent(event) {
        const eventId = event.target.dataset.eventId;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: eventId,
                objectApiName: 'Event__c',
                actionName: 'view'
            }
        });
    }

    async handleSendReminder(event) {
        const eventId = event.target.dataset.eventId;
        try {
            const result = await sendReminderEmails({ eventId: eventId });
            this.showToast('Success', result, 'success');
        } catch (error) {
            console.error('Error sending reminders:', error);
            this.showToast('Error', 'Failed to send reminder emails', 'error');
        }
    }

    handleExport() {
        if (!this.hasAlerts) {
            this.showToast('Info', 'No alerts to export', 'info');
            return;
        }

        // Create CSV content
        const csvContent = this.generateCSVContent();
        const blob = new Blob([csvContent], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        
        // Create download link
        const link = document.createElement('a');
        link.href = url;
        link.download = `low-attendance-alerts-${new Date().toISOString().split('T')[0]}.csv`;
        link.click();
        
        window.URL.revokeObjectURL(url);
        this.showToast('Success', 'Alerts exported successfully', 'success');
    }

    // Helper methods
    processAlertData(data) {
        this.criticalAlerts = 0;
        this.warningAlerts = 0;
        this.lowAlerts = 0;

        this.alertEvents = data.map(alert => {
            const capacityPercentage = this.calculateCapacityPercentage(alert.registrationCount, alert.capacity);
            const alertLevel = this.getAlertLevel(capacityPercentage);
            
            // Update summary counts
            if (alertLevel === 'critical') this.criticalAlerts++;
            else if (alertLevel === 'warning') this.warningAlerts++;
            else if (alertLevel === 'low') this.lowAlerts++;

            return {
                ...alert,
                capacityPercentage,
                alertLevel,
                alertClass: `alert-card ${alertLevel}`,
                iconName: this.getAlertIcon(alertLevel),
                iconVariant: this.getAlertIconVariant(alertLevel),
                message: this.getAlertMessage(alertLevel, capacityPercentage),
                daysUntilEvent: this.calculateDaysUntilEvent(alert.eventDate)
            };
        });
    }

    calculateCapacityPercentage(registrationCount, capacity) {
        if (!capacity || capacity === 0) return 0;
        return Math.round((registrationCount / capacity) * 100);
    }

    getAlertLevel(percentage) {
        if (percentage < this.criticalThreshold) return 'critical';
        if (percentage < this.warningThreshold) return 'warning';
        if (percentage < this.lowThreshold) return 'low';
        return 'normal';
    }

    getAlertIcon(level) {
        switch (level) {
            case 'critical': return 'utility:error';
            case 'warning': return 'utility:warning';
            case 'low': return 'utility:info';
            default: return 'utility:success';
        }
    }

    getAlertIconVariant(level) {
        switch (level) {
            case 'critical': return 'error';
            case 'warning': return 'warning';
            case 'low': return 'inverse';
            default: return 'success';
        }
    }

    getAlertMessage(level, percentage) {
        switch (level) {
            case 'critical':
                return `Critical: Only ${percentage}% capacity filled. Immediate action required.`;
            case 'warning':
                return `Warning: ${percentage}% capacity filled. Consider promotional activities.`;
            case 'low':
                return `Low attendance: ${percentage}% capacity filled. Monitor closely.`;
            default:
                return `Good attendance: ${percentage}% capacity filled.`;
        }
    }

    calculateDaysUntilEvent(eventDate) {
        const today = new Date();
        const event = new Date(eventDate);
        const diffTime = event - today;
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        return diffDays;
    }

    generateCSVContent() {
        const headers = ['Event Name', 'Event Type', 'Event Date', 'Capacity', 'Registrations', 'Percentage', 'Alert Level', 'Days Until Event'];
        const rows = this.alertEvents.map(alert => [
            alert.eventName,
            alert.eventType,
            alert.eventDate,
            alert.capacity,
            alert.registrationCount,
            `${alert.capacityPercentage}%`,
            alert.alertLevel,
            alert.daysUntilEvent
        ]);

        return [headers, ...rows].map(row => row.join(',')).join('\n');
    }

    updateLastUpdated() {
        const now = new Date();
        this.lastUpdated = now.toLocaleTimeString();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    connectedCallback() {
        this.updateLastUpdated();
        // Auto-refresh every 5 minutes
        this.refreshInterval = setInterval(() => {
            this.handleRefresh();
        }, 300000);
    }

    disconnectedCallback() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
        }
        if (this.thresholdTimeout) {
            clearTimeout(this.thresholdTimeout);
        }
    }
}
