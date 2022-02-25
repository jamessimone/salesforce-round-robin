public without sharing class QueryAssigner implements RoundRobinAssigner.IAssignmentRepo {
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
