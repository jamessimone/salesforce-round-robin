@IsTest
private class RoundRobinAssignerTests {
  @IsTest
  static void shouldReassignOwnersToRecordsPassedIn() {
    // arrange
    String assignmentType = 'example';
    List<Lead> leadsToAssign = new List<Lead>{ new Lead(), new Lead(), new Lead(), new Lead() };
    List<User> users = createUsersForAssignment(assignmentType);

    // act
    RoundRobinAssigner.IAssignmentRepo repo = new MockUserAssignmentRepo(users);
    RoundRobinAssigner.Details details = new RoundRobinAssigner.Details();
    details.assignmentType = assignmentType;
    new RoundRobinAssigner(repo, details).assignOwners(leadsToAssign);

    // assert
    Integer firstInsideSalesUserAssignmentCount = 0;
    Integer secondInsideSalesUserAssignmentCount = 0;

    for (Lead assignedLead : leadsToAssign) {
      System.assertNotEquals(null, assignedLead.OwnerId, 'Assignment should have been run');
      if (assignedLead.OwnerId == users[0].Id) {
        firstInsideSalesUserAssignmentCount++;
      } else if (assignedLead.OwnerId == users[1].Id) {
        secondInsideSalesUserAssignmentCount++;
      }
    }
    System.assertEquals(2, firstInsideSalesUserAssignmentCount, 'Leads should have been assigned equally');
    System.assertEquals(2, secondInsideSalesUserAssignmentCount, 'Leads should have been assigned equally');
    // now verify that the assignment index was updated
    RoundRobin__c cachedAssignment = [SELECT LastUpdated__c, Index__c FROM RoundRobin__c WHERE Name = :assignmentType];
    System.assertEquals(users[1].Id, cachedAssignment.Index__c, 'Last assigned user should match updated index');
  }

  @IsTest
  static void shouldRoundRobinPreviouslyAssignedLeadsWhenTheirCurrentOwnerFlagIsInactive() {
    // arrange
    String assignmentType = 'example';
    List<User> users = createUsersForAssignment(assignmentType);
    User inactiveUser = users.remove(0);

    List<Lead> leadsToAssign = new List<Lead>{
      new Lead(OwnerId = inactiveUser.Id),
      new Lead(OwnerId = inactiveUser.Id),
      new Lead(),
      new Lead()
    };

    // act
    RoundRobinAssigner.Details details = new RoundRobinAssigner.Details();
    details.assignmentType = assignmentType;
    new RoundRobinAssigner(new MockUserAssignmentRepo(users), details).assignOwners(leadsToAssign);

    // assert
    for (Lead assignedLead : leadsToAssign) {
      System.assertEquals(
        users[0].Id,
        assignedLead.OwnerId,
        'Should have re-assigned but failed at index: ' + leadsToAssign.indexOf(assignedLead)
      );
    }
  }

  @IsTest
  static void shouldNotFailWhenRoundRobinNameOverCustomSettingLimit() {
    String assignmentType = '0'.repeat(256);
    List<User> users = createUsersForAssignment(assignmentType);

    Lead lead = new Lead();

    RoundRobinAssigner.Details details = new RoundRobinAssigner.Details();
    details.assignmentType = assignmentType;
    new RoundRobinAssigner(new MockUserAssignmentRepo(users), details).assignOwners(new List<Lead>{ lead });

    System.assertEquals(users[0].Id, lead.OwnerId);
  }

  static List<User> createUsersForAssignment(String assignmentType) {
    List<User> users = new List<User>();
    String baseIdString = Schema.User.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix() + '0'.repeat(11);
    for (Integer index = 0; index < 2; index++) {
      users.add(new User(Department = assignmentType, Id = baseIdString + (index + 1)));
    }
    return users;
  }
}
