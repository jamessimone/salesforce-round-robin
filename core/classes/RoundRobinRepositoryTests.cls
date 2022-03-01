@IsTest
private class RoundRobinRepositoryTests {
  private static String cacheKey = 'a sales team';
  @IsTest
  static void shouldUpdateAssignment() {
    Datetime someTimeAgo = System.now().addDays(-3);
    upsert new RoundRobin__c(LastUpdated__c = someTimeAgo, Name = cacheKey);
    RoundRobinRepository repo = new RoundRobinRepository();

    repo.accept(new VisitorMock(), new List<SObject>());

    RoundRobin__c updatedAssignment = [SELECT LastUpdated__c FROM RoundRobin__c WHERE Name = :cacheKey];
    System.assertEquals(
      true,
      someTimeAgo < updatedAssignment.LastUpdated__c,
      'Cached record should have had its LastUpdated__c field updated properly: ' + updatedAssignment
    );
  }

  @IsTest
  static void avoidsRecursiveUpdateIssues() {
    Datetime someTimeAgo = System.now().addDays(-3);
    upsert new RoundRobin__c(LastUpdated__c = someTimeAgo, Name = cacheKey);
    RoundRobinRepository repo = new RoundRobinRepository();

    Lead firstLead = new Lead();
    Lead secondLead = new Lead();

    repo.accept(new VisitorMock(), new List<SObject>{ firstLead });
    repo.accept(new VisitorMock(), new List<SObject>{ secondLead });

    RoundRobin__c updatedAssignment = [SELECT Id, Index__c FROM RoundRobin__c];
    System.assertEquals(UserInfo.getUserId(), updatedAssignment.Index__c);
  }

  private class VisitorMock implements IThreadSafeCacheVisitor {
    public String getVisitKey() {
      return cacheKey;
    }
    @SuppressWarnings('PMD.EmptyStatementBlock')
    public void visitRecords(List<SObject> records, SObject currentCacheRecord) {
      currentCacheRecord.put('Index__c', UserInfo.getUserId());
    }
  }
}
