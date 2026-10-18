@IsTest
private class ClientReviewServiceTest {
    private static User makeUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = String.valueOf(Crypto.getRandomInteger()).replace('-', 'n');
        User u = new User(
            Alias = 'crtest',
            Email = 'crtest' + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Tester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'crtest' + uniq + '@example.com.bedrockdemo'
        );
        // runAs the current user isolates this setup DML from non-setup DML (avoids MIXED_DML_OPERATION)
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Client_Review_Manager'];
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        }
        return u;
    }

    private static Client_Review__c newReview(Id accountId, Date reviewDate, String risk) {
        return new Client_Review__c(
            Client__c = accountId,
            Review_Date__c = reviewDate,
            Risk_Profile__c = risk
        );
    }

    @IsTest
    static void calculatesDatePerRiskProfile() {
        Date d = Date.newInstance(2026, 1, 15);
        Assert.areEqual(Date.newInstance(2026, 7, 15), ClientReviewService.calculateNextReviewDate(d, 'Growth'));
        Assert.areEqual(Date.newInstance(2027, 1, 15), ClientReviewService.calculateNextReviewDate(d, 'Balanced'));
        Assert.areEqual(Date.newInstance(2027, 1, 15), ClientReviewService.calculateNextReviewDate(d, 'Conservative'));
        Assert.areEqual(Date.newInstance(2027, 1, 15), ClientReviewService.calculateNextReviewDate(d, null));
    }

    // Each test runs as a user holding only the Client_Review_Manager permission set, so the
    // result doesn't depend on the deploying admin's field access in the target org.
    @IsTest
    static void flowSetsStatusAndNextReviewDate() {
        System.runAs(makeUser()) {
            Account a = new Account(Name = 'Flow Test Client');
            insert a;
            Date d = Date.newInstance(2026, 3, 31);
            List<Client_Review__c> reviews = new List<Client_Review__c>{
                newReview(a.Id, d, 'Growth'),
                newReview(a.Id, d, 'Balanced'),
                newReview(a.Id, d, 'Conservative')
            };
            Test.startTest();
            insert reviews;
            Test.stopTest();
            Map<Id, Client_Review__c> byId = new Map<Id, Client_Review__c>([
                SELECT Id, Risk_Profile__c, Status__c, Next_Review_Date__c FROM Client_Review__c
            ]);
            Assert.areEqual(3, byId.size());
            for (Client_Review__c cr : byId.values()) {
                Assert.areEqual('Scheduled', cr.Status__c, 'Flow should default Status to Scheduled');
                Date expected = cr.Risk_Profile__c == 'Growth' ? Date.newInstance(2026, 9, 30) : Date.newInstance(2027, 3, 31);
                Assert.areEqual(expected, cr.Next_Review_Date__c, 'Wrong date for ' + cr.Risk_Profile__c);
            }
        }
    }

    @IsTest
    static void flowKeepsExplicitStatus() {
        System.runAs(makeUser()) {
            Account a = new Account(Name = 'Status Client');
            insert a;
            Client_Review__c cr = newReview(a.Id, Date.newInstance(2026, 2, 1), 'Balanced');
            cr.Status__c = 'Draft';
            insert cr;
            cr = [SELECT Status__c FROM Client_Review__c WHERE Id = :cr.Id];
            Assert.areEqual('Draft', cr.Status__c);
        }
    }

    @IsTest
    static void nullReviewDateIsSkipped() {
        System.runAs(makeUser()) {
            Account a = new Account(Name = 'Null Date Client');
            insert a;
            Client_Review__c cr = newReview(a.Id, null, 'Growth');
            insert cr;
            ClientReviewService.Request req = new ClientReviewService.Request();
            req.reviewId = cr.Id;
            ClientReviewService.setNextReviewDate(new List<ClientReviewService.Request>{ req });
            cr = [SELECT Next_Review_Date__c, Status__c FROM Client_Review__c WHERE Id = :cr.Id];
            Assert.isNull(cr.Next_Review_Date__c);
            Assert.areEqual('Scheduled', cr.Status__c);
        }
    }

    @IsTest
    static void bulkOf200() {
        System.runAs(makeUser()) {
            Account a = new Account(Name = 'Bulk Client');
            insert a;
            List<Client_Review__c> reviews = new List<Client_Review__c>();
            String[] risks = new String[]{ 'Conservative', 'Balanced', 'Growth' };
            for (Integer i = 0; i < 200; i++) {
                reviews.add(newReview(a.Id, Date.newInstance(2026, 1, 10), risks[Math.mod(i, 3)]));
            }
            Test.startTest();
            insert reviews;
            Test.stopTest();
            Integer populated = 0;
            for (Client_Review__c cr : [SELECT Risk_Profile__c, Status__c, Next_Review_Date__c FROM Client_Review__c]) {
                Date expected = cr.Risk_Profile__c == 'Growth' ? Date.newInstance(2026, 7, 10) : Date.newInstance(2027, 1, 10);
                Assert.areEqual(expected, cr.Next_Review_Date__c);
                Assert.areEqual('Scheduled', cr.Status__c);
                populated++;
            }
            Assert.areEqual(200, populated);
        }
    }
}
