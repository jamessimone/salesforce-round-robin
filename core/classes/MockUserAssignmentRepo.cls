@IsTest
public class MockUserAssignmentRepo implements RoundRobinAssigner.IAssignmentRepo {
    @TestVisible
    private static List<User> STUB_USERS;
    private final List<User> users;

    public MockUserAssignmentRepo() {
        this.users = STUB_USERS;
    }

    public MockUserAssignmentRepo(List<User> users) {
      this.users = users;
    }

    public List<Id> getAssignmentIds(String assignmentType) {
      List<Id> assignmentIds = new List<Id>();
      for (User user : this.users) {
        assignmentIds.add(user.Id);
      }
      return assignmentIds;
    }
  }
