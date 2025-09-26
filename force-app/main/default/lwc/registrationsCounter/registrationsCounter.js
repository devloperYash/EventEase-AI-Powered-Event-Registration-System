import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getRegistrationStats from '@salesforce/apex/RegistrationsCounterController.getRegistrationStats';
import getEventCounters from '@salesforce/apex/RegistrationsCounterController.getEventCounters';
import getEventOptions from '@salesforce/apex/RegistrationsCounterController.getEventOptions';

export default class RegistrationsCounter extends LightningElement {
    @track isLoading = true;
    @track selectedEventId = '';
    @track totalRegistrations = 0;
    @track confirmedRegistrations = 0;
    @track pendingRegistrations = 0;
    @track eventCounters = [];
    @track eventOptions = [];
    @track lastUpdated = '';

    // Wired data
    wiredStatsResult;
    wiredCountersResult;
    wiredOptionsResult;

    @wire(getRegistrationStats, { eventId: '$selectedEventId' })
    wiredStats(result) {
        this.wiredStatsResult = result;
        if (result.data) {
            this.totalRegistrations = result.data.totalRegistrations || 0;
            this.confirmedRegistrations = result.data.confirmedRegistrations || 0;
            this.pendingRegistrations = result.data.pendingRegistrations || 0;
            this.updateLastUpdated();
        } else if (result.error) {
            console.error('Error loading stats:', result.error);
        }
    }

    @wire(getEventCounters, { eventId: '$selectedEventId' })
    wiredCounters(result) {
        this.wiredCountersResult = result;
        if (result.data) {
            this.eventCounters = result.data.map(event => ({
                ...event,
                capacityPercentage: this.calculateCapacityPercentage(event.registrationCount, event.capacity),
                capacityBarStyle: this.getCapacityBarStyle(event.registrationCount, event.capacity)
            }));
            this.isLoading = false;
        } else if (result.error) {
            console.error('Error loading counters:', result.error);
            this.isLoading = false;
        }
    }

    @wire(getEventOptions)
    wiredOptions(result) {
        this.wiredOptionsResult = result;
        if (result.data) {
            this.eventOptions = [
                { label: 'All Events', value: '' },
                ...result.data.map(event => ({
                    label: event.Name,
                    value: event.Id
                }))
            ];
        } else if (result.error) {
            console.error('Error loading event options:', result.error);
        }
    }

    // Computed properties
    get hasData() {
        return this.eventCounters && this.eventCounters.length > 0;
    }

    // Event handlers
    handleEventChange(event) {
        this.selectedEventId = event.detail.value;
        this.isLoading = true;
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this.wiredStatsResult),
            refreshApex(this.wiredCountersResult),
            refreshApex(this.wiredOptionsResult)
        ]).then(() => {
            this.updateLastUpdated();
        }).catch(error => {
            console.error('Error refreshing data:', error);
            this.isLoading = false;
        });
    }

    // Helper methods
    calculateCapacityPercentage(registrationCount, capacity) {
        if (!capacity || capacity === 0) return 0;
        return Math.round((registrationCount / capacity) * 100);
    }

    getCapacityBarStyle(registrationCount, capacity) {
        const percentage = this.calculateCapacityPercentage(registrationCount, capacity);
        let color = '#4bca81'; // Green
        
        if (percentage >= 90) {
            color = '#ea001e'; // Red
        } else if (percentage >= 70) {
            color = '#ffb75d'; // Orange
        } else if (percentage >= 50) {
            color = '#ffd23e'; // Yellow
        }
        
        return `width: ${percentage}%; background-color: ${color};`;
    }

    updateLastUpdated() {
        const now = new Date();
        this.lastUpdated = now.toLocaleTimeString();
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
    }
}
