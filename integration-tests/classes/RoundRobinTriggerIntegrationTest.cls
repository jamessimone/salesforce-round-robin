@IsTest
private class RoundRobinTriggerIntegrationTest {
  @IsTest
  static void currentUserShouldNotTrumpOtherUsersBeforeInsert() {
    // default owner for records is the current user when not otherwise specified
    // but that requires special handling when the current user is also part of the
    // valid pool of assignable users
    User user = [
      SELECT Id, FirstName, LastName, Email, Alias, TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, ProfileId, LanguageLocaleKey
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    User newUser = user.clone();
    newUser.Username = 'another1' + System.now().getTime() + '@example.com';
    newUser.IsActive = true;
    newUser.Email = newUser.Username;
    insert newUser;

    insert new List<QuickText>{
      // should be assigned to new user
      new QuickText(Name = 'One', Message = 'One'),
      // should be assigned to current user
      new QuickText(Name = 'Two', Message = 'Two'),
      // queue is depleted: should be assigned to new user again
      new QuickText(Name = 'Three', Message = 'Three')
    };

    List<QuickText> updatedQuickTexts = [SELECT OwnerId, Owner.FirstName FROM QuickText];
    Integer ownerByNewUserCount = 0;
    Integer ownerdByMeCount = 0;
    for (QuickText updatedQuickText : updatedQuickTexts) {
      if (updatedQuickText.OwnerId == newUser.Id) {
        ownerByNewUserCount++;
      } else if (updatedQuickText.OwnerId == UserInfo.getUserId()) {
        ownerdByMeCount++;
      }
    }
    Assert.areEqual(2, ownerByNewUserCount);
    Assert.areEqual(1, ownerdByMeCount);
  }
}
