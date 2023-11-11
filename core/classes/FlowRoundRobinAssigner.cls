global without sharing class FlowRoundRobinAssigner {
  @TestVisible
  private static RoundRobinAssigner.IAssignmentRepo stubAssignmentRepo;

  private static final Set<Id> PROCESSED_RECORD_IDS = new Set<Id>();
  private static final FlowRoundRobinAssigner SELF = new FlowRoundRobinAssigner();

  global class FlowInput {
    @InvocableVariable(label='Alternative to query: API name of class that implements RoundRobinAssigner.IAssignmentRepo')
    global String assignmentRepoClassName;
    @InvocableVariable(label='Query To Retrieve Possible Assignees')
    global String queryToRetrieveAssignees;
    @InvocableVariable(label='Alternative to Assignee Query - Collection of Users from Flow')
    global List<User> collectionOfAssignees = new List<User>();
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
    @InvocableVariable(label='Name For Custom Setting Record')
    global String optionalName;
  }

  @InvocableMethod(category='Round Robin' label='Round robin records')
  global static void assign(List<FlowInput> flowInputs) {
    FlowInput bulkifiedInput;
    for (FlowInput input : flowInputs) {
      if (bulkifiedInput == null) {
        bulkifiedInput = input;
      }
      if (input.recordsToRoundRobin?.isEmpty() != false && input.recordToRoundRobin != null) {
        input.recordsToRoundRobin = new List<SObject>{ input.recordToRoundRobin };
      }
      bulkifiedInput.recordsToRoundRobin.addAll(input.recordsToRoundRobin);
    }

    if (bulkifiedInput?.recordsToRoundRobin.isEmpty() == false) {
      SELF.trackAssignedIds(bulkifiedInput);
      SELF.roundRobin(bulkifiedInput);
    }
    if (bulkifiedInput?.updateRecords == true) {
      update bulkifiedInput.recordsToRoundRobin;
    }
  }

  private void roundRobin(FlowInput input) {
    this.validateInput(input);
    RoundRobinAssigner.IAssignmentRepo assignmentRepo = this.getAssignmentRepo(input);
    RoundRobinAssigner.Details assignmentDetails = this.getAssignmentDetails(input);
    new RoundRobinAssigner(assignmentRepo, assignmentDetails).assignOwners(input.recordsToRoundRobin);
  }

  private void validateInput(FlowInput input) {
    if (String.isBlank(input.queryToRetrieveAssignees) && String.isBlank(input.assignmentRepoClassName) && input.collectionOfAssignees.size()==0) {
      throw new IllegalArgumentException(
        'Query To Retrieve Possible Assignees, API name of class implementing RoundRobinAssigner.IAssignment repo, or a collection of at least one user passed in is required!'
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
    } else if (input.collectionOfAssignees.size() != 0) {
      assignmentRepo = new QueryAssigner(input.collectionOfAssignees);
    } else {
      assignmentRepo = new QueryAssigner(input.queryToRetrieveAssignees, input.queryIdField);
    }
    return assignmentRepo;
  }

  private RoundRobinAssigner.Details getAssignmentDetails(FlowInput input) {
    RoundRobinAssigner.Details details = new RoundRobinAssigner.Details();
    if (input.optionalName != null) {
      details.assignmentType = input.optionalName;
    } else if (input.recordsToRoundRobin.isEmpty() == false) {
      details.assignmentType = input.recordsToRoundRobin[0].getSObjectType().getDescribe().getName() + '.' + input.ownerFieldApiName;
    } else {
      details.assignmentType = input.ownerFieldApiName;
    }
    details.ownerField = input.ownerFieldApiName;
    return details;
  }
}
