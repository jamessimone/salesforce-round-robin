public without sharing class RoundRobinRepository {
  private static final Map<String, RoundRobin__c> CACHED_ASSIGNMENTS = new Map<String, RoundRobin__c>();

  public void accept(IThreadSafeCacheVisitor visitor, List<SObject> records) {
    RoundRobin__c currentAssignment = this.getCurrentAssignment(visitor.getVisitKey());
    visitor.visitRecords(records, currentAssignment);
    if (this.commitUpdatedAssignment(currentAssignment) == false) {
      this.accept(visitor, records);
    }
  }

  private RoundRobin__c getCurrentAssignment(String assignmentType) {
    if (CACHED_ASSIGNMENTS.containsKey(assignmentType) == false) {
      CACHED_ASSIGNMENTS.putAll(new Map<String, RoundRobin__c>(RoundRobin__c.getAll()));
    }
    RoundRobin__c cachedAssignment = CACHED_ASSIGNMENTS.get(assignmentType);
    if (cachedAssignment == null) {
      cachedAssignment = new RoundRobin__c(
        Name = assignmentType,
        // some sentinel value
        LastUpdated__c = Datetime.newInstanceGmt(1970, 1, 1)
      );
      CACHED_ASSIGNMENTS.put(assignmentType, cachedAssignment);
    }
    return cachedAssignment;
  }

  @SuppressWarnings('PMD.ApexCRUDViolation')
  private Boolean commitUpdatedAssignment(RoundRobin__c assignment) {
    RoundRobin__c cachedAssignment = CACHED_ASSIGNMENTS.get(assignment.Name);
    if (cachedAssignment != null && cachedAssignment.LastUpdated__c > CACHED_ASSIGNMENTS.get(assignment.Name).LastUpdated__c) {
      return false;
    }
    assignment.LastUpdated__c = System.now();
    /**
     * integration tests with after save Flows have shown something unfortunate:
     * though the second (recursive) call to the assigner is spawned in a second transaction
     * the RoundRobin__c.getAll() call still doesn't contain the Id of the inserted record (for the times where the assignment
     * is being run for the first time).
     * That means that we can't just call "upsert", and instead have to do this goofy
     * song and dance to ensure the Id is appended correctly
     */
    if (assignment.Id == null) {
      List<RoundRobin__c> existingAssignments = [SELECT Id FROM RoundRobin__c WHERE Name = :assignment.Name];
      if (existingAssignments.isEmpty() == false) {
        assignment.Id = existingAssignments[0].Id;
      }
    }
    if (assignment.Id != null) {
      try {
        /**
         * if two separate threads are trying to round robin at the same time, the LastUpdated__c check above
         * isn't enough to ensure write-safety, and unfortunately FOR UPDATE is the only mutex Apex offers
         * as a write-safe guarantee. One downside (among many) is that FOR UPDATE frequently throws; another is
         * that another locking thread can release early - let's protect against both those eventualities
         */
        RoundRobin__c lockedAssignment = [SELECT Id, Name, LastUpdated__c FROM RoundRobin__c WHERE Id = :assignment.Id FOR UPDATE];
        if (lockedAssignment.LastUpdated__c >= assignment.LastUpdated__c) {
          // lock was released early, but the existing Index__c now almost certainly has stale values in it
          // re-round robin to get the now-correct values
          return false;
        }
        lockedAssignment.Index__c = assignment.Index__c;
        lockedAssignment.LastUpdated__c = assignment.LastUpdated__c;
        assignment = lockedAssignment;
        this.write(assignment);
        // purely for the map assignment, below
      } catch (DmlException ex) {
        return false;
      }
    } else {
      this.write(assignment);
    }

    CACHED_ASSIGNMENTS.put(assignment.Name, assignment);
    return true;
  }

  private void write(RoundRobin__c setting) {
    // field truncation with Database.DMLOptions doesn't work with custom settings
    final Integer customSettingNameMaxLength = 38;
    if (setting.Name.length() > customSettingNameMaxLength) {
      setting.Name = setting.Name.substring(0, customSettingNameMaxLength);
    }
    Database.upsert(setting); // NOPMD
  }
}
