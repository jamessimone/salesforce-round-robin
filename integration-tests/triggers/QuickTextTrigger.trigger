trigger QuickTextTrigger on QuickText(before insert) {
  RoundRobinAssigner.IAssignmentRepo queryRepo = new RoundRobinCollectionAssigner(
    'SELECT Id FROM User WHERE IsActive = true AND FirstName = \'' +
    UserInfo.getFirstName() +
    '\' ORDER BY CreatedDate DESC',
    'Id'
  );
  RoundRobinAssigner.Details assignmentDetails = new RoundRobinAssigner.Details();
  assignmentDetails.assignmentType = 'quicktext-assignment';
  new RoundRobinAssigner(queryRepo, assignmentDetails).assignOwners(Trigger.new);
}
