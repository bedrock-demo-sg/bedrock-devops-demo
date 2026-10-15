public with sharing class ClientReviewService {
    // Illustrative rule: higher risk profile reviews sooner.
    // Growth = 6 months; Balanced and Conservative (and anything else) = 12 months.
    public static Date calculateNextReviewDate(Date reviewDate, String riskProfile) {
        Integer months = (riskProfile == 'Growth') ? 6 : 12;
        return reviewDate.addMonths(months);
    }

    public class Request {
        @InvocableVariable(required=true)
        public Id reviewId;
    }

    @InvocableMethod(label='Set Next Review Date')
    public static void setNextReviewDate(List<Request> requests) {
        Set<Id> ids = new Set<Id>();
        for (Request r : requests) {
            ids.add(r.reviewId);
        }
        List<Client_Review__c> toUpdate = new List<Client_Review__c>();
        for (Client_Review__c cr : [
            SELECT Id, Review_Date__c, Risk_Profile__c
            FROM Client_Review__c
            WHERE Id IN :ids
            WITH USER_MODE
        ]) {
            if (cr.Review_Date__c != null) {
                cr.Next_Review_Date__c = calculateNextReviewDate(cr.Review_Date__c, cr.Risk_Profile__c);
                toUpdate.add(cr);
            }
        }
        if (!toUpdate.isEmpty()) {
            update as user toUpdate;
        }
    }
}
