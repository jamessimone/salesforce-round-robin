global without sharing class FlowRoundRobinAssigner {
  @TestVisible
  RoundRobinAssigner.IAssignmentRepo stubAssignmentRepo;

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
    @InvocableVariable(label='Records to round robin')
    global List<SObject> recordsToRoundRobin = new List<SObject>();
    @InvocableVariable(label='Update records - defaults to false')
    global Boolean updateRecords = false;
  }

  @InvocableMethod(category='Round Robin' label='Round robin records')
  global static void assign(List<FlowInput> flowInputs) {
    for (FlowInput input : flowInputs) {
      if (input.recordsToRoundRobin.isEmpty() == false) {
        SELF.validateInput(input);
        RoundRobinAssigner.IAssignmentRepo assignmentRepo = SELF.getAssignmentRepo(input);
        RoundRobinAssigner.Details assignmentDetails = SELF.getAssignmentDetails(input);
        new RoundRobinAssigner(assignmentRepo, assignmentDetails).assignOwners(input.recordsToRoundRobin);
      }
    }
  }

  private void validateInput(FlowInput input) {
    if (String.isBlank(input.queryToRetrieveAssignees) && String.isBlank(input.assignmentRepoClassName)) {
      throw new IllegalArgumentException('Query To Retrieve Possible Assignees or API name of class implementing RoundRobinAssigner.IAssignment repo is required!');
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
    details.assignmentType = input.recordsToRoundRobin[0].getSObjectType().getDescribe().getName() + '.' + input.ownerFieldApiName;
    details.ownerField = input.ownerFieldApiName;
    return details;
  }

  private without sharing class QueryAssigner implements RoundRobinAssigner.IAssignmentRepo {
    private final List<Id> validAssignmentIds;
    public QueryAssigner(String query, String assignmentFieldName) {
      Set<Id> assignmentIds = new Set<Id>();
      List<SObject> matchingRecords = Database.query(query);
      for (SObject matchingRecord : matchingRecords) {
        assignmentIds.add((Id) matchingRecord.get(assignmentFieldName));
      }
      this.validAssignmentIds = new List<Id>(assignmentIds);
    }
    public List<Id> getAssignmentIds(String assignmentType) {
      return this.validAssignmentIds;
    }
  }
}
