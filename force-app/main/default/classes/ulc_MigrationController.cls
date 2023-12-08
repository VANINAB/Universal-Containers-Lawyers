public with sharing class ulc_MigrationController {
    @AuraEnabled(cacheable=true)
    public static void callHerokuIntegration() {
        ulc_HerokuIntegration.makeHttpRequest();
    }
}