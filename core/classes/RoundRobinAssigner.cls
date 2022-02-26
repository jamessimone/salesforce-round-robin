public without sharing class RoundRobinAssigner implements IThreadSafeCacheVisitor {
  private final RoundRobinRepository roundRobinRepo;
  private final IAssignmentRepo assignmentRepo;
  private final Details details;

  private static final Integer SENTINEL_INDEX = -1;
  private static final String OWNER_ID = 'OwnerId';

  public interface IAssignmentRepo {
    List<Id> getAssignmentIds(String assignmentType);
  }

  public class Details {
    public String assignmentType { get; set; }
    public String ownerField {
      get {
        if (ownerField == null) {
          ownerField = OWNER_ID;
        }
        return ownerField;
      }
      set;
    }
  }

  public RoundRobinAssigner(IAssignmentRepo assignmentRepo, Details details) {
    this.roundRobinRepo = new RoundRobinRepository();
    this.assignmentRepo = assignmentRepo;
    this.details = details;
  }

  public void assignOwners(List<SObject> records) {
    this.roundRobinRepo.accept(this, records);
  }

  public String getVisitKey() {
    return this.details.assignmentType;
  }

  public void visitRecords(List<SObject> records, SObject currentCachedAssignment) {
    RoundRobin__c cachedAssignment = (RoundRobin__c) currentCachedAssignment;
    List<Id> assignmentIds = this.assignmentRepo.getAssignmentIds(this.details.assignmentType);
    Set<Id> activeAssignmentIds = new Set<Id>(assignmentIds);
    Integer nextAssignmentIndex = this.getNextAssignmentIndex(assignmentIds, cachedAssignment);
    for (SObject record : records) {
      Id ownerId = (Id) record.get(this.details.ownerField);
      Id nextOwnerId = assignmentIds[nextAssignmentIndex];
      if (ownerId == null || activeAssignmentIds.contains(ownerId) == false || nextOwnerId == ownerId) {
        record.put(OWNER_ID, nextOwnerId);
        cachedAssignment.Index__c = nextOwnerId;
        nextAssignmentIndex = nextAssignmentIndex == assignmentIds.size() - 1 ? 0 : nextAssignmentIndex + 1;
      }
    }
  }

  private Integer getNextAssignmentIndex(List<Id> assignmentIds, RoundRobin__c cachedAssignment) {
    if (cachedAssignment.Index__c == null && assignmentIds.isEmpty() == false) {
      return 0;
    }
    Integer currentAssignmentIndex = SENTINEL_INDEX;
    for (Integer index = 0; index < assignmentIds.size(); index++) {
      Id assignmentId = assignmentIds[index];
      if (assignmentId > cachedAssignment.Index__c) {
        currentAssignmentIndex = index;
        break;
      }
    }
    if (currentAssignmentIndex == SENTINEL_INDEX) {
      currentAssignmentIndex = 0;
    }
    return currentAssignmentIndex;
  }
}
