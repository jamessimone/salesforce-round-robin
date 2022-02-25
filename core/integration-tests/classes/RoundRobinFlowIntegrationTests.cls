@IsTest
private class RoundRobinFlowIntegrationTests {
  @IsTest
  static void successfullyRoundRobinsFromFlow() {
    User existingUser = [
      SELECT Id, LastName, Email, Alias, TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, ProfileId, LanguageLocaleKey, Username
      FROM User
      WHERE Name = 'user user'
    ];
    User roundRobinUser = existingUser.clone();
    roundRobinUser.FirstName = null;
    roundRobinUser.Username = 'roundRobin@test.com';
    // roundRobinUser is hard-coded into the query in flow
    roundRobinUser.LastName = 'roundRobinUser';
    insert roundRobinUser;

    Lead lead = new Lead(LastName = 'Test Assignment', Company = 'Test');
    insert lead;

    lead = [SELECT Id, OwnerId FROM Lead];
    System.assertEquals(roundRobinUser.Id, lead.OwnerId);
  }
}
