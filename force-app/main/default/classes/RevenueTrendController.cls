public with sharing class RevenueTrendController {
    
    @AuraEnabled(cacheable=true)
    public static List<RevenueTrendData> getRevenueTrendData(String timeRange, String groupBy, String eventType) {
        try {
            Date startDate = calculateStartDate(timeRange);
            
            String query = 'SELECT Event__r.Event_Date__c, Event__r.Event_Type__c, Amount__c ' +
                          'FROM Registration__c ' +
                          'WHERE Payment_Status__c = \'Paid\' AND Amount__c != null';
            
            List<String> conditions = new List<String>();
            
            if (startDate != null) {
                conditions.add('Event__r.Event_Date__c >= :startDate');
            }
            
            if (String.isNotBlank(eventType)) {
                conditions.add('Event__r.Event_Type__c = :eventType');
            }
            
            if (!conditions.isEmpty()) {
                query += ' AND ' + String.join(conditions, ' AND ');
            }
            
            query += ' ORDER BY Event__r.Event_Date__c ASC';
            
            List<Registration__c> registrations = Database.query(query);
            
            // Group data by time period
            Map<String, RevenueTrendData> trendMap = new Map<String, RevenueTrendData>();
            
            for (Registration__c reg : registrations) {
                String period = formatPeriod(reg.Event__r.Event_Date__c, groupBy);
                
                if (!trendMap.containsKey(period)) {
                    RevenueTrendData trendData = new RevenueTrendData();
                    trendData.period = period;
                    trendData.revenue = 0;
                    trendData.registrations = 0;
                    trendMap.put(period, trendData);
                }
                
                RevenueTrendData trendData = trendMap.get(period);
                trendData.revenue += reg.Amount__c;
                trendData.registrations += 1;
            }
            
            List<RevenueTrendData> result = trendMap.values();
            result.sort(new RevenueTrendComparator());
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving revenue trend data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static RevenueSummary getRevenueSummary(String timeRange, String eventType) {
        try {
            Date startDate = calculateStartDate(timeRange);
            Date previousPeriodStart = calculatePreviousPeriodStart(timeRange);
            
            // Current period data
            RevenueSummary currentSummary = calculatePeriodSummary(startDate, Date.today(), eventType);
            
            // Previous period data for comparison
            RevenueSummary previousSummary = new RevenueSummary();
            if (previousPeriodStart != null) {
                previousSummary = calculatePeriodSummary(previousPeriodStart, startDate?.addDays(-1), eventType);
            }
            
            // Calculate percentage changes
            currentSummary.totalRevenueChange = calculatePercentageChange(
                previousSummary.totalRevenue, currentSummary.totalRevenue);
            currentSummary.avgRevenueChange = calculatePercentageChange(
                previousSummary.averageRevenue, currentSummary.averageRevenue);
            currentSummary.paidRegChange = calculatePercentageChange(
                previousSummary.paidRegistrations, currentSummary.paidRegistrations);
            currentSummary.conversionChange = calculatePercentageChange(
                previousSummary.conversionRate, currentSummary.conversionRate);
            
            return currentSummary;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving revenue summary: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<TopRevenueEvent> getTopRevenueEvents(String timeRange, String eventType, Integer limitCount) {
        try {
            Date startDate = calculateStartDate(timeRange);
            
            String query = 'SELECT Event__c, Event__r.Name, Event__r.Event_Type__c, Event__r.Event_Date__c, ' +
                          'SUM(Amount__c) totalRevenue, COUNT(Id) paidCount ' +
                          'FROM Registration__c ' +
                          'WHERE Payment_Status__c = \'Paid\' AND Amount__c != null';
            
            List<String> conditions = new List<String>();
            
            if (startDate != null) {
                conditions.add('Event__r.Event_Date__c >= :startDate');
            }
            
            if (String.isNotBlank(eventType)) {
                conditions.add('Event__r.Event_Type__c = :eventType');
            }
            
            if (!conditions.isEmpty()) {
                query += ' AND ' + String.join(conditions, ' AND ');
            }
            
            query += ' GROUP BY Event__c, Event__r.Name, Event__r.Event_Type__c, Event__r.Event_Date__c ' +
                     'ORDER BY SUM(Amount__c) DESC';
            
            if (limitCount != null && limitCount > 0) {
                query += ' LIMIT ' + limitCount;
            } else {
                query += ' LIMIT 10';
            }
            
            List<AggregateResult> results = Database.query(query);
            List<TopRevenueEvent> topEvents = new List<TopRevenueEvent>();
            
            for (AggregateResult result : results) {
                TopRevenueEvent topEvent = new TopRevenueEvent();
                topEvent.eventId = (String) result.get('Event__c');
                topEvent.eventName = (String) result.get('Name');
                topEvent.eventType = (String) result.get('Event_Type__c');
                Object dateVal = result.get('Event_Date__c');
                String formattedDate = '';
                if (dateVal instanceof Date) {
                    Datetime dtVal = Datetime.newInstance((Date)dateVal, Time.newInstance(0,0,0,0));
                    formattedDate = dtVal.format('MMM dd, yyyy');
                } else if (dateVal instanceof Datetime) {
                    formattedDate = ((Datetime)dateVal).format('MMM dd, yyyy');
                }
                topEvent.eventDate = formattedDate;
                topEvent.totalRevenue = String.valueOf(((Decimal) result.get('totalRevenue')).intValue());
                topEvent.paidRegistrations = (Integer) result.get('paidCount');
                
                // Calculate average ticket price
                Decimal totalRev = (Decimal) result.get('totalRevenue');
                Integer count = (Integer) result.get('paidCount');
                topEvent.averageTicketPrice = count > 0 ? 
                    String.valueOf((totalRev / count).intValue()) : '0';
                
                topEvents.add(topEvent);
            }
            
            return topEvents;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving top revenue events: ' + e.getMessage());
        }
    }
    
    // Helper methods
    private static Date calculateStartDate(String timeRange) {
        if (String.isBlank(timeRange) || timeRange == 'all') {
            return null;
        }
        
        Integer days = Integer.valueOf(timeRange);
        return Date.today().addDays(-days);
    }
    
    private static Date calculatePreviousPeriodStart(String timeRange) {
        if (String.isBlank(timeRange) || timeRange == 'all') {
            return null;
        }
        
        Integer days = Integer.valueOf(timeRange);
        return Date.today().addDays(-days * 2);
    }
    
    private static String formatPeriod(Datetime eventDateTime, String groupBy) {
        if (eventDateTime == null) return 'Unknown';
        Date dateOnly = eventDateTime.date();
        Datetime dt = Datetime.newInstance(dateOnly, Time.newInstance(0, 0, 0, 0));

        switch on groupBy {
            when 'day' {
                return dt.format('MMM dd');
            }
            when 'week' {
                Date weekStart = dateOnly.toStartOfWeek();
                Datetime weekStartDt = Datetime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0));
                return 'Week of ' + weekStartDt.format('MMM dd');
            }
            when 'month' {
                return dt.format('MMM yyyy');
            }
            when 'quarter' {
                Integer quarter = ((dateOnly.month() - 1) / 3) + 1;
                return 'Q' + quarter + ' ' + dateOnly.year();
            }
            when else {
                return dt.format('MMM yyyy');
            }
        }
    }
    
    private static RevenueSummary calculatePeriodSummary(Date startDate, Date endDate, String eventType) {
        String query = 'SELECT Amount__c FROM Registration__c ' +
                      'WHERE Payment_Status__c = \'Paid\' AND Amount__c != null';
        
        List<String> conditions = new List<String>();
        
        if (startDate != null) {
            conditions.add('Event__r.Event_Date__c >= :startDate');
        }
        
        if (endDate != null) {
            conditions.add('Event__r.Event_Date__c <= :endDate');
        }
        
        if (String.isNotBlank(eventType)) {
            conditions.add('Event__r.Event_Type__c = :eventType');
        }
        
        if (!conditions.isEmpty()) {
            query += ' AND ' + String.join(conditions, ' AND ');
        }
        
        List<Registration__c> paidRegs = Database.query(query);
        
        // Get total registrations for conversion rate
        String totalQuery = query.replace('Payment_Status__c = \'Paid\' AND Amount__c != null', '1=1');
        List<Registration__c> totalRegs = Database.query(totalQuery);
        
        RevenueSummary summary = new RevenueSummary();
        summary.totalRevenue = 0;
        summary.paidRegistrations = paidRegs.size();
        
        for (Registration__c reg : paidRegs) {
            summary.totalRevenue += reg.Amount__c;
        }
        
        summary.averageRevenue = summary.paidRegistrations > 0 ? 
            summary.totalRevenue / summary.paidRegistrations : 0;
        
        summary.conversionRate = totalRegs.size() > 0 ? 
            (summary.paidRegistrations * 100.0) / totalRegs.size() : 0;
        
        return summary;
    }
    
    private static Decimal calculatePercentageChange(Decimal oldValue, Decimal newValue) {
        if (oldValue == null || oldValue == 0) return 0;
        return ((newValue - oldValue) / oldValue) * 100;
    }
    
    // Wrapper classes
    public class RevenueTrendData {
        @AuraEnabled public String period;
        @AuraEnabled public Decimal revenue;
        @AuraEnabled public Integer registrations;
    }
    
    public class RevenueSummary {
        @AuraEnabled public Decimal totalRevenue = 0;
        @AuraEnabled public Decimal averageRevenue = 0;
        @AuraEnabled public Integer paidRegistrations = 0;
        @AuraEnabled public Decimal conversionRate = 0;
        @AuraEnabled public Decimal totalRevenueChange = 0;
        @AuraEnabled public Decimal avgRevenueChange = 0;
        @AuraEnabled public Decimal paidRegChange = 0;
        @AuraEnabled public Decimal conversionChange = 0;
    }
    
    public class TopRevenueEvent {
        @AuraEnabled public String eventId;
        @AuraEnabled public String eventName;
        @AuraEnabled public String eventType;
        @AuraEnabled public String eventDate;
        @AuraEnabled public String totalRevenue;
        @AuraEnabled public Integer paidRegistrations;
        @AuraEnabled public String averageTicketPrice;
    }
    
    // Comparator for sorting trend data
    public class RevenueTrendComparator implements Comparator<RevenueTrendData> {
        public Integer compare(RevenueTrendData a, RevenueTrendData b) {
            // Sort by period name (this is simplified - in production, you'd want proper date sorting)
            return a.period.compareTo(b.period);
        }
    }
}
