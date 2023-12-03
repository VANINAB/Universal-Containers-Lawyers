public class ulc_DataMigrationScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        ulc_HerokuIntegration.makeHttpRequest();
    }
    DataMigrationScheduler scheduler = new DataMigrationScheduler();
    String myTime = '0 0 0 * * ?'; 
    String mySchedule = System.schedule('Heroku Integration Job', myTime, scheduler);
}



