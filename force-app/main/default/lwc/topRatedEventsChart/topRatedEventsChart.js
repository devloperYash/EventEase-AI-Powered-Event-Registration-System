import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { loadScript } from 'lightning/platformResourceLoader';
import chartjs from '@salesforce/resourceUrl/chartjs';
import getTopRatedEvents from '@salesforce/apex/TopRatedEventsController.getTopRatedEvents';
import getRatingStatistics from '@salesforce/apex/TopRatedEventsController.getRatingStatistics';

export default class TopRatedEventsChart extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track topEvents = [];
    @track statistics = {};
    @track lastUpdated = '';
    
    // Filter options
    @track selectedTimeRange = '90';
    @track selectedEventType = '';
    @track minFeedbackCount = 3;
    
    // Chart instance
    chart;
    chartInitialized = false;

    // Options
    timeRangeOptions = [
        { label: 'Last 30 Days', value: '30' },
        { label: 'Last 90 Days', value: '90' },
        { label: 'Last 6 Months', value: '180' },
        { label: 'Last Year', value: '365' },
        { label: 'All Time', value: 'all' }
    ];

    eventTypeOptions = [
        { label: 'All Types', value: '' },
        { label: 'Conference', value: 'Conference' },
        { label: 'Workshop', value: 'Workshop' },
        { label: 'Seminar', value: 'Seminar' },
        { label: 'Webinar', value: 'Webinar' },
        { label: 'Training', value: 'Training' },
        { label: 'Networking', value: 'Networking' }
    ];

    // Wired data
    wiredEventsResult;
    wiredStatsResult;

    @wire(getTopRatedEvents, { 
        timeRange: '$selectedTimeRange',
        eventType: '$selectedEventType',
        minFeedbackCount: '$minFeedbackCount'
    })
    wiredEvents(result) {
        this.wiredEventsResult = result;
        if (result.data) {
            this.processEventData(result.data);
            this.updateChart();
            this.isLoading = false;
            this.updateLastUpdated();
        } else if (result.error) {
            console.error('Error loading top rated events:', result.error);
            this.showToast('Error', 'Failed to load top rated events', 'error');
            this.isLoading = false;
        }
    }

    @wire(getRatingStatistics, {
        timeRange: '$selectedTimeRange',
        eventType: '$selectedEventType'
    })
    wiredStats(result) {
        this.wiredStatsResult = result;
        if (result.data) {
            this.statistics = result.data;
        } else if (result.error) {
            console.error('Error loading statistics:', result.error);
        }
    }

    // Computed properties
    get hasData() {
        return this.topEvents && this.topEvents.length > 0;
    }

    get hasTopEvents() {
        return this.hasData;
    }

    get hasChartData() {
        return this.hasData && this.chartInitialized;
    }

    get hasStatistics() {
        return this.statistics && Object.keys(this.statistics).length > 0;
    }

    // Event handlers
    handleTimeRangeChange(event) {
        this.selectedTimeRange = event.detail.value;
        this.isLoading = true;
    }

    handleEventTypeChange(event) {
        this.selectedEventType = event.detail.value;
        this.isLoading = true;
    }

    handleMinFeedbackChange(event) {
        this.minFeedbackCount = parseInt(event.detail.value, 10);
        // Debounce the refresh
        clearTimeout(this.feedbackTimeout);
        this.feedbackTimeout = setTimeout(() => {
            this.isLoading = true;
            refreshApex(this.wiredEventsResult);
        }, 500);
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this.wiredEventsResult),
            refreshApex(this.wiredStatsResult)
        ]).then(() => {
            this.updateLastUpdated();
        }).catch(error => {
            console.error('Error refreshing data:', error);
            this.isLoading = false;
        });
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

    handleViewFeedback(event) {
        const eventId = event.target.dataset.eventId;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Feedback__c',
                actionName: 'list'
            },
            state: {
                filterName: 'Recent'
            }
        });
    }

    handleCloneEvent(event) {
        const eventId = event.target.dataset.eventId;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Event__c',
                actionName: 'new'
            },
            state: {
                clone: '1',
                recordId: eventId
            }
        });
    }

    handleExport() {
        if (!this.hasData) {
            this.showToast('Info', 'No data to export', 'info');
            return;
        }

        const csvContent = this.generateCSVContent();
        const blob = new Blob([csvContent], { type: 'text/csv' });
        const url = window.URL.createObjectURL(blob);
        
        const link = document.createElement('a');
        link.href = url;
        link.download = `top-rated-events-${new Date().toISOString().split('T')[0]}.csv`;
        link.click();
        
        window.URL.revokeObjectURL(url);
        this.showToast('Success', 'Report exported successfully', 'success');
    }

    // Helper methods
    processEventData(data) {
        this.topEvents = data.map((event, index) => ({
            ...event,
            rank: index + 1,
            starArray: this.generateStarArray(event.averageRating)
        }));
    }

    generateStarArray(rating) {
        const stars = [];
        const fullStars = Math.floor(rating);
        const hasHalfStar = rating % 1 >= 0.5;
        
        for (let i = 0; i < 5; i++) {
            if (i < fullStars) {
                stars.push({
                    id: i,
                    icon: 'utility:favorite',
                    variant: 'warning'
                });
            } else if (i === fullStars && hasHalfStar) {
                stars.push({
                    id: i,
                    icon: 'utility:favorite_alt',
                    variant: 'warning'
                });
            } else {
                stars.push({
                    id: i,
                    icon: 'utility:favorite',
                    variant: 'inverse'
                });
            }
        }
        
        return stars;
    }

    async updateChart() {
        if (!this.chartInitialized || !this.hasData) return;

        const ctx = this.template.querySelector('canvas.chart-canvas');
        if (!ctx) return;

        // Destroy existing chart
        if (this.chart) {
            this.chart.destroy();
        }

        // Prepare chart data
        const labels = this.topEvents.slice(0, 10).map(event => event.eventName);
        const ratings = this.topEvents.slice(0, 10).map(event => event.averageRating);
        const feedbackCounts = this.topEvents.slice(0, 10).map(event => event.feedbackCount);

        // Create new chart
        this.chart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Average Rating',
                    data: ratings,
                    backgroundColor: 'rgba(102, 126, 234, 0.8)',
                    borderColor: 'rgba(102, 126, 234, 1)',
                    borderWidth: 1,
                    yAxisID: 'y'
                }, {
                    label: 'Feedback Count',
                    data: feedbackCounts,
                    type: 'line',
                    borderColor: 'rgba(255, 99, 132, 1)',
                    backgroundColor: 'rgba(255, 99, 132, 0.2)',
                    yAxisID: 'y1'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        type: 'linear',
                        display: true,
                        position: 'left',
                        min: 0,
                        max: 5,
                        title: {
                            display: true,
                            text: 'Average Rating'
                        }
                    },
                    y1: {
                        type: 'linear',
                        display: true,
                        position: 'right',
                        title: {
                            display: true,
                            text: 'Feedback Count'
                        },
                        grid: {
                            drawOnChartArea: false,
                        },
                    }
                },
                plugins: {
                    title: {
                        display: true,
                        text: 'Top 10 Rated Events'
                    },
                    legend: {
                        display: true,
                        position: 'top'
                    }
                }
            }
        });
    }

    generateCSVContent() {
        const headers = ['Rank', 'Event Name', 'Event Type', 'Event Date', 'Average Rating', 'Feedback Count', 'Attendee Count'];
        const rows = this.topEvents.map(event => [
            event.rank,
            event.eventName,
            event.eventType,
            event.eventDate,
            event.averageRating,
            event.feedbackCount,
            event.attendeeCount
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

    async connectedCallback() {
        try {
            await loadScript(this, chartjs);
            this.chartInitialized = true;
            this.updateLastUpdated();
        } catch (error) {
            console.error('Error loading Chart.js:', error);
            this.showToast('Error', 'Failed to load chart library', 'error');
        }
    }

    disconnectedCallback() {
        if (this.chart) {
            this.chart.destroy();
        }
        if (this.feedbackTimeout) {
            clearTimeout(this.feedbackTimeout);
        }
    }
}
