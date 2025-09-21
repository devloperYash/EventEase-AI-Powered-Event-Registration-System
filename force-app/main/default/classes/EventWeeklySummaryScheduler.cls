global with sharing class EventWeeklySummaryScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new EventWeeklySummaryBatch(), 100);
    }

    // Helper to produce a CRON for every Monday at 08:00 org time
    public static String defaultCron() {
        // sec min hour day month weekday year (optional)
        return '0 0 8 ? * MON';
    }
}
