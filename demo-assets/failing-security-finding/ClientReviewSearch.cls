public with sharing class ClientReviewSearch {
    // DELIBERATELY INSECURE - demo asset for the failing Code Analyzer check. Do not merge.
    @AuraEnabled
    public static List<Client_Review__c> search(String riskProfile) {
        String soql = 'SELECT Id, Name, Status__c FROM Client_Review__c WHERE Risk_Profile__c = \'' + riskProfile + '\'';
        return Database.query(soql);
    }
}
