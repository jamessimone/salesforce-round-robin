@IsTest
private class FlowRoundRobinAssignerTests {
  static final User FAKE_USER = new User(Id = User.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix() + '0'.repeat(12));

  @IsTest
  static void defaultAssignmentToOwnerId() {
    FlowRoundRobinAssigner.FlowInput input = new FlowRoundRobinAssigner.FlowInput();
    input.recordsToRoundRobin = new List<Account>{ new Account() };
    input.collectionOfAssignees = new List<User>{ FAKE_USER };

    FlowRoundRobinAssigner.assign(new List<FlowRoundRobinAssigner.FlowInput>{ input });

    Object possiblyAssignedOwner = input.recordsToRoundRobin[0].get('OwnerId');
    System.assertNotEquals(null, possiblyAssignedOwner, 'Should assign owner by default!');
    System.assertEquals(FAKE_USER.Id, possiblyAssignedOwner);
  }

  @IsTest
  static void queryForMatchingUsers() {
    Id userId = [SELECT Id FROM User LIMIT 1].Id;
    String queryString = 'SELECT Id FROM User WHERE Id = \'' + userId + '\'';

    FlowRoundRobinAssigner.FlowInput input = new FlowRoundRobinAssigner.FlowInput();
    input.recordsToRoundRobin = new List<Account>{ new Account() };
    input.queryToRetrieveAssignees = queryString;

    FlowRoundRobinAssigner.assign(new List<FlowRoundRobinAssigner.FlowInput>{ input });

    System.assertEquals(userId, input.recordsToRoundRobin[0].get('OwnerId'));
  }

  @IsTest
  static void throwExceptionIfQueryNotFilledOutAndAssignmentRepoNotFilledOutAndNoCollectionPassedIn() {
    FlowRoundRobinAssigner.FlowInput input = new FlowRoundRobinAssigner.FlowInput();
    input.recordsToRoundRobin = new List<Account>{ new Account() };

    Exception ex;
    try {
      FlowRoundRobinAssigner.assign(new List<FlowRoundRobinAssigner.FlowInput>{ input });
    } catch (System.IllegalArgumentException e) {
      ex = e;
    }

    System.assertNotEquals(null, ex, 'Exception should be thrown when arguments are not properly provided');
  }

  @IsTest
  static void updatesRecordsWhenFlagIsPassed() {
    ContactPointAddress cpa = new ContactPointAddress(Name = 'updatesRecordsWhenFlagIsPassed');
    insert cpa;
    cpa.OwnerId = null;

    FlowRoundRobinAssigner.FlowInput input = new FlowRoundRobinAssigner.FlowInput();
    input.updateRecords = true;
    input.recordsToRoundRobin = new List<ContactPointAddress>{ cpa };
    input.queryToRetrieveAssignees = 'SELECT Id FROM User WHERE Id = \'' + UserInfo.getUserId() + '\'';

    FlowRoundRobinAssigner.assign(new List<FlowRoundRobinAssigner.FlowInput>{ input });

    System.assertEquals(UserInfo.getUserId(), cpa.OwnerId);
  }

  @IsTest
  static void singleRecordRoundRobinsWithAssigneeQuery() {
    FlowRoundRobinAssigner.FlowInput input = new FlowRoundRobinAssigner.FlowInput();
    input.recordToRoundRobin = new ContactPointAddress();
    input.queryToRetrieveAssignees = 'SELECT Id FROM User WHERE Id = \'' + UserInfo.getUserId() + '\'';

    FlowRoundRobinAssigner.assign(new List<FlowRoundRobinAssigner.FlowInput>{ input });

    System.assertEquals(UserInfo.getUserId(), input.recordToRoundRobin.get('OwnerId'));
  }

  @IsTest
  static void singleRecordRoundRobinsWithCollectionOfAssignees() {
    FlowRoundRobinAssigner.FlowInput input = new FlowRoundRobinAssigner.FlowInput();
    input.recordToRoundRobin = new ContactPointAddress();
    input.collectionOfAssignees = new List<User>{ new User(Id = UserInfo.getUserId()) };

    FlowRoundRobinAssigner.assign(new List<FlowRoundRobinAssigner.FlowInput>{ input });

    System.assertEquals(UserInfo.getUserId(), input.recordToRoundRobin.get('OwnerId'));
  }

  @IsTest
  static void singleRecordGetsUpdatedOwnerFromQueueWhenNotBulkified() {
    FlowRoundRobinAssigner.FlowInput input = new FlowRoundRobinAssigner.FlowInput();
    input.recordToRoundRobin = new ContactPointAddress();
    input.collectionOfAssignees = new List<User>{ new User(Id = '005000000000000'), new User(Id = '005000000000001') };

    FlowRoundRobinAssigner.assign(new List<FlowRoundRobinAssigner.FlowInput>{ input });
    System.assertEquals('005000000000000', input.recordToRoundRobin.get('OwnerId'));
    input.recordToRoundRobin = new ContactPointAddress();
    FlowRoundRobinAssigner.assign(new List<FlowRoundRobinAssigner.FlowInput>{ input });
    System.assertEquals('005000000000001', input.recordToRoundRobin.get('OwnerId'));
  }

  @IsTest
  static void usesCustomNameWhenSupplied() {
    FlowRoundRobinAssigner.FlowInput input = new FlowRoundRobinAssigner.FlowInput();
    input.recordToRoundRobin = new ContactPointAddress();
    input.optionalName = 'Some name';
    input.queryToRetrieveAssignees = 'SELECT Id FROM User WHERE Id = \'' + UserInfo.getUserId() + '\'';

    FlowRoundRobinAssigner.assign(new List<FlowRoundRobinAssigner.FlowInput>{ input });

    System.assertEquals(1, [SELECT COUNT() FROM RoundRobin__c WHERE Name = :input.optionalName]);
  }
}
