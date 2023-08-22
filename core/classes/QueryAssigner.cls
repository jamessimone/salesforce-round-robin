public without sharing class QueryAssigner implements RoundRobinAssigner.IAssignmentRepo {
  private static final Map<String, List<SObject>> QUERY_TO_RECORDS = new Map<String, List<SObject>>();
  private final List<Id> validAssignmentIds;

  public QueryAssigner(String query, String assignmentFieldName) {
    Set<Id> assignmentIds = new Set<Id>();
    List<SObject> matchingRecords = QUERY_TO_RECORDS.get(query);
    if (matchingRecords == null) {
      matchingRecords = Database.query(query);
      QUERY_TO_RECORDS.put(query, matchingRecords);
    }

    for (SObject matchingRecord : matchingRecords) {
      assignmentIds.add((Id) matchingRecord.get(assignmentFieldName));
    }
    this.validAssignmentIds = new List<Id>(assignmentIds);
  }

  public List<Id> getAssignmentIds(String assignmentType) {
    return this.validAssignmentIds;
  }
}
