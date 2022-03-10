global without sharing class FlowRoundRobinAssigner {
  @TestVisible
  private static RoundRobinAssigner.IAssignmentRepo stubAssignmentRepo;
  @TestVisible
  private static Boolean hasBeenUpdated = false;

  private static final Set<Id> PROCESSED_RECORD_IDS = new Set<Id>();
  private static final FlowRoundRobinAssigner SELF = new FlowRoundRobinAssigner();

  global class FlowInput {
    @InvocableVariable(label='Alternative to query: API name of class that implements RoundRobinAssigner.IAssignmentRepo')
    global String assignmentRepoClassName;
    @InvocableVariable(label='Query To Retrieve Possible Assignees')
    global String queryToRetrieveAssignees;
    @InvocableVariable(label='Query Id Field - defaults to Id if not supplied')
    global String queryIdField = 'Id';
    @InvocableVariable(label='Owner Field API Name - defaults to OwnerId')
    global String ownerFieldApiName = 'OwnerId';
    @InvocableVariable(label='Records to round robin - either this or single record is required')
    global List<SObject> recordsToRoundRobin = new List<SObject>();
    @InvocableVariable(label='Single record to round robin - either this or records to round robin is required')
    global SObject recordToRoundRobin;
    @InvocableVariable(label='Update records - defaults to false')
    global Boolean updateRecords = false;
  }

  @InvocableMethod(category='Round Robin' label='Round robin records')
  global static void assign(List<FlowInput> flowInputs) {
    for (FlowInput input : flowInputs) {
      if (input.recordsToRoundRobin?.isEmpty() == false || input.recordToRoundRobin != null) {
        SELF.trackAssignedIds(input);
        SELF.roundRobin(input);
      }
    }
  }

  private void roundRobin(FlowInput input) {
    this.validateInput(input);
    RoundRobinAssigner.IAssignmentRepo assignmentRepo = this.getAssignmentRepo(input);
    RoundRobinAssigner.Details assignmentDetails = this.getAssignmentDetails(input);
    new RoundRobinAssigner(assignmentRepo, assignmentDetails).assignOwners(input.recordsToRoundRobin);
    if (input.updateRecords) {
      update input.recordsToRoundRobin;
      hasBeenUpdated = true;
    }
  }

  private void validateInput(FlowInput input) {
    if (String.isBlank(input.queryToRetrieveAssignees) && String.isBlank(input.assignmentRepoClassName)) {
      throw new IllegalArgumentException(
        'Query To Retrieve Possible Assignees or API name of class implementing RoundRobinAssigner.IAssignment repo is required!'
      );
    }
    if (input.recordsToRoundRobin?.isEmpty() != false && input.recordToRoundRobin != null) {
      input.recordsToRoundRobin = new List<SObject>{ input.recordToRoundRobin };
    }
  }

  private void trackAssignedIds(FlowInput input) {
    for (Integer reverseIndex = input.recordsToRoundRobin.size() - 1; reverseIndex >= 0; reverseIndex--) {
      SObject record = input.recordsToRoundRobin[reverseIndex];
      if (record.Id != null && PROCESSED_RECORD_IDS.contains(record.Id)) {
        input.recordsToRoundRobin.remove(reverseIndex);
      } else if (record.Id != null) {
        PROCESSED_RECORD_IDS.add(record.Id);
      }
    }
  }

  private RoundRobinAssigner.IAssignmentRepo getAssignmentRepo(FlowInput input) {
    RoundRobinAssigner.IAssignmentRepo assignmentRepo;
    if (stubAssignmentRepo != null) {
      assignmentRepo = stubAssignmentRepo;
    } else if (String.isNotBlank(input.assignmentRepoClassName)) {
      assignmentRepo = (RoundRobinAssigner.IAssignmentRepo) Type.forName(input.assignmentRepoClassName).newInstance();
    } else {
      assignmentRepo = new QueryAssigner(input.queryToRetrieveAssignees, input.queryIdField);
    }
    return assignmentRepo;
  }

  private RoundRobinAssigner.Details getAssignmentDetails(FlowInput input) {
    RoundRobinAssigner.Details details = new RoundRobinAssigner.Details();
    if (input.recordsToRoundRobin.isEmpty() == false) {
      details.assignmentType = input.recordsToRoundRobin[0].getSObjectType().getDescribe().getName() + '.' + input.ownerFieldApiName;
    } else {
      details.assignmentType = input.ownerFieldApiName;
    }
    details.ownerField = input.ownerFieldApiName;
    return details;
  }
}
