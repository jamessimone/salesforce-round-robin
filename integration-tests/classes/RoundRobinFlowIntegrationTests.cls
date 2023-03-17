@IsTest
private class RoundRobinFlowIntegrationTests {
  @IsTest
  static void successfullyRoundRobinsFromFlow() {
    User existingUser = [
      SELECT Id, LastName, Email, Alias, TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, ProfileId, LanguageLocaleKey, Username
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    User roundRobinUser = existingUser.clone();
    roundRobinUser.FirstName = null;
    roundRobinUser.Username = 'roundRobin@test.com';
    // "roundRobinUser" is hard-coded into the query in flow
    roundRobinUser.LastName = 'roundRobinUser';
    insert roundRobinUser;

    List<Lead> leads = new List<Lead>();
    // stress test!
    for (Integer index = 0; index < 200; index++) {
      leads.add(new Lead(LastName = 'Assignment ' + index, Company = 'Round Robin'));
    }
    insert leads;

    leads = [SELECT Id, OwnerId FROM Lead];
    for (Lead lead : leads) {
      System.assertEquals(roundRobinUser.Id, lead.OwnerId);
    }
  }
}
