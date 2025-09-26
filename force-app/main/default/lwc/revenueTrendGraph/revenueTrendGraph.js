import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { loadScript } from 'lightning/platformResourceLoader';
import chartjs from '@salesforce/resourceUrl/chartjs';
import getRevenueTrendData from '@salesforce/apex/RevenueTrendController.getRevenueTrendData';
import getRevenueSummary from '@salesforce/apex/RevenueTrendController.getRevenueSummary';
import getTopRevenueEvents from '@salesforce/apex/RevenueTrendController.getTopRevenueEvents';

export default class RevenueTrendGraph extends NavigationMixin(LightningElement) {
    @track isLoading = true;
    @track lastUpdated = '';
    
    // Chart data
    @track chartData = [];
    @track topRevenueEvents = [];
    @track revenueInsights = [];
    
    // Summary data
    @track totalRevenue = '0';
    @track averageRevenue = '0';
    @track paidRegistrations = 0;
    @track conversionRate = 0;
    @track totalRevenueTrend = 'neutral';
    @track totalRevenueChange = 0;
    @track avgRevenueTrend = 'neutral';
    @track avgRevenueChange = 0;
    @track paidRegTrend = 'neutral';
    @track paidRegChange = 0;
    @track conversionTrend = 'neutral';
    @track conversionChange = 0;
    
    // Filter options
    @track selectedTimeRange = '90';
    @track selectedGroupBy = 'month';
    @track selectedEventType = '';
    @track selectedChartType = 'line';
    
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

    groupByOptions = [
        { label: 'Daily', value: 'day' },
        { label: 'Weekly', value: 'week' },
        { label: 'Monthly', value: 'month' },
        { label: 'Quarterly', value: 'quarter' }
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

    chartTypeOptions = [
        { label: 'Line Chart', value: 'line' },
        { label: 'Bar Chart', value: 'bar' },
        { label: 'Area Chart', value: 'area' }
    ];

    // Wired data
    wiredTrendResult;
    wiredSummaryResult;
    wiredTopEventsResult;

    @wire(getRevenueTrendData, {
        timeRange: '$selectedTimeRange',
        groupBy: '$selectedGroupBy',
        eventType: '$selectedEventType'
    })
    wiredTrend(result) {
        this.wiredTrendResult = result;
        if (result.data) {
            this.chartData = result.data;
            this.updateChart();
            this.generateInsights();
            this.isLoading = false;
            this.updateLastUpdated();
        } else if (result.error) {
            console.error('Error loading trend data:', result.error);
            this.showToast('Error', 'Failed to load revenue trend data', 'error');
            this.isLoading = false;
        }
    }

    @wire(getRevenueSummary, {
        timeRange: '$selectedTimeRange',
        eventType: '$selectedEventType'
    })
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            this.processSummaryData(result.data);
        } else if (result.error) {
            console.error('Error loading summary data:', result.error);
        }
    }

    @wire(getTopRevenueEvents, {
        timeRange: '$selectedTimeRange',
        eventType: '$selectedEventType',
        limitCount: 6
    })
    wiredTopEvents(result) {
        this.wiredTopEventsResult = result;
        if (result.data) {
            this.topRevenueEvents = result.data;
        } else if (result.error) {
            console.error('Error loading top events:', result.error);
        }
    }

    // Computed properties
    get hasData() {
        return this.chartData && this.chartData.length > 0;
    }

    get hasChartData() {
        return this.hasData && this.chartInitialized;
    }

    get hasTopRevenueEvents() {
        return this.topRevenueEvents && this.topRevenueEvents.length > 0;
    }

    get hasInsights() {
        return this.revenueInsights && this.revenueInsights.length > 0;
    }

    // Event handlers
    handleTimeRangeChange(event) {
        this.selectedTimeRange = event.detail.value;
        this.isLoading = true;
    }

    handleGroupByChange(event) {
        this.selectedGroupBy = event.detail.value;
        this.isLoading = true;
    }

    handleEventTypeChange(event) {
        this.selectedEventType = event.detail.value;
        this.isLoading = true;
    }

    handleChartTypeChange(event) {
        this.selectedChartType = event.detail.value;
        this.updateChart();
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this.wiredTrendResult),
            refreshApex(this.wiredSummaryResult),
            refreshApex(this.wiredTopEventsResult)
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
        link.download = `revenue-trend-${new Date().toISOString().split('T')[0]}.csv`;
        link.click();
        
        window.URL.revokeObjectURL(url);
        this.showToast('Success', 'Revenue report exported successfully', 'success');
    }

    handleForecast() {
        // Simple forecast based on trend
        if (!this.hasData || this.chartData.length < 3) {
            this.showToast('Info', 'Insufficient data for forecasting', 'info');
            return;
        }

        const forecast = this.calculateForecast();
        this.showToast('Forecast', `Projected next period revenue: $${forecast}`, 'info');
    }

    // Helper methods
    processSummaryData(data) {
        this.totalRevenue = this.formatCurrency(data.totalRevenue || 0);
        this.averageRevenue = this.formatCurrency(data.averageRevenue || 0);
        this.paidRegistrations = data.paidRegistrations || 0;
        this.conversionRate = data.conversionRate || 0;
        
        // Process trends
        this.totalRevenueTrend = this.getTrendDirection(data.totalRevenueChange || 0);
        this.totalRevenueChange = Math.abs(data.totalRevenueChange || 0);
        this.avgRevenueTrend = this.getTrendDirection(data.avgRevenueChange || 0);
        this.avgRevenueChange = Math.abs(data.avgRevenueChange || 0);
        this.paidRegTrend = this.getTrendDirection(data.paidRegChange || 0);
        this.paidRegChange = Math.abs(data.paidRegChange || 0);
        this.conversionTrend = this.getTrendDirection(data.conversionChange || 0);
        this.conversionChange = Math.abs(data.conversionChange || 0);
    }

    async updateChart() {
        if (!this.chartInitialized || !this.hasData) return;

        const canvas = this.template.querySelector('canvas.revenue-chart');
        if (!canvas) return;

        // Destroy existing chart
        if (this.chart) {
            this.chart.destroy();
        }

        // Prepare chart data
        const labels = this.chartData.map(item => item.period);
        const revenues = this.chartData.map(item => item.revenue);
        const registrations = this.chartData.map(item => item.registrations);

        const chartType = this.selectedChartType === 'area' ? 'line' : this.selectedChartType;

        // Create new chart
        this.chart = new Chart(canvas, {
            type: chartType,
            data: {
                labels: labels,
                datasets: [{
                    label: 'Revenue ($)',
                    data: revenues,
                    borderColor: 'rgba(102, 126, 234, 1)',
                    backgroundColor: this.selectedChartType === 'area' ? 
                        'rgba(102, 126, 234, 0.2)' : 'rgba(102, 126, 234, 0.8)',
                    fill: this.selectedChartType === 'area',
                    tension: 0.4,
                    yAxisID: 'y'
                }, {
                    label: 'Paid Registrations',
                    data: registrations,
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
                        title: {
                            display: true,
                            text: 'Revenue ($)'
                        },
                        ticks: {
                            callback: function(value) {
                                return '$' + value.toLocaleString();
                            }
                        }
                    },
                    y1: {
                        type: 'linear',
                        display: true,
                        position: 'right',
                        title: {
                            display: true,
                            text: 'Registrations'
                        },
                        grid: {
                            drawOnChartArea: false,
                        }
                    }
                },
                plugins: {
                    title: {
                        display: true,
                        text: `Revenue Trend - ${this.selectedGroupBy.charAt(0).toUpperCase() + this.selectedGroupBy.slice(1)}ly`
                    },
                    legend: {
                        display: true,
                        position: 'top'
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                if (context.datasetIndex === 0) {
                                    return `Revenue: $${context.parsed.y.toLocaleString()}`;
                                } else {
                                    return `Registrations: ${context.parsed.y}`;
                                }
                            }
                        }
                    }
                }
            }
        });
    }

    generateInsights() {
        if (!this.hasData) return;

        const insights = [];
        const recentData = this.chartData.slice(-3);
        const trend = this.calculateTrend(recentData.map(d => d.revenue));

        // Revenue trend insight
        if (trend > 0.1) {
            insights.push({
                id: 'revenue-growth',
                type: 'positive',
                icon: 'utility:trending',
                variant: 'success',
                title: 'Revenue Growth Detected',
                description: `Revenue has been trending upward by ${(trend * 100).toFixed(1)}% over recent periods.`,
                recommendation: 'Consider scaling successful event formats and increasing marketing spend.'
            });
        } else if (trend < -0.1) {
            insights.push({
                id: 'revenue-decline',
                type: 'negative',
                icon: 'utility:warning',
                variant: 'error',
                title: 'Revenue Decline Alert',
                description: `Revenue has been declining by ${Math.abs(trend * 100).toFixed(1)}% over recent periods.`,
                recommendation: 'Review event pricing, marketing strategies, and attendee feedback for improvement opportunities.'
            });
        }

        // Conversion rate insight
        if (this.conversionRate < 50) {
            insights.push({
                id: 'low-conversion',
                type: 'warning',
                icon: 'utility:info',
                variant: 'warning',
                title: 'Low Payment Conversion Rate',
                description: `Only ${this.conversionRate}% of registrations result in payment.`,
                recommendation: 'Consider simplifying the payment process or offering early bird discounts.'
            });
        }

        // High performing events insight
        if (this.hasTopRevenueEvents) {
            const topEvent = this.topRevenueEvents[0];
            insights.push({
                id: 'top-performer',
                type: 'positive',
                icon: 'utility:success',
                variant: 'success',
                title: 'Top Revenue Generator',
                description: `${topEvent.eventName} generated $${topEvent.totalRevenue} in revenue.`,
                recommendation: 'Analyze this event\'s success factors and apply them to future events.'
            });
        }

        this.revenueInsights = insights;
    }

    calculateTrend(values) {
        if (values.length < 2) return 0;
        
        const firstValue = values[0];
        const lastValue = values[values.length - 1];
        
        if (firstValue === 0) return 0;
        return (lastValue - firstValue) / firstValue;
    }

    calculateForecast() {
        const recentRevenues = this.chartData.slice(-3).map(d => d.revenue);
        const trend = this.calculateTrend(recentRevenues);
        const lastRevenue = recentRevenues[recentRevenues.length - 1];
        
        return this.formatCurrency(lastRevenue * (1 + trend));
    }

    getTrendDirection(change) {
        if (change > 0) return 'positive';
        if (change < 0) return 'negative';
        return 'neutral';
    }

    formatCurrency(amount) {
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(amount);
    }

    generateCSVContent() {
        const headers = ['Period', 'Revenue', 'Paid Registrations', 'Average per Registration'];
        const rows = this.chartData.map(item => [
            item.period,
            item.revenue,
            item.registrations,
            item.registrations > 0 ? (item.revenue / item.registrations).toFixed(2) : '0'
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
    }
}
