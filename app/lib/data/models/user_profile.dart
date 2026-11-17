class UserProfile {
  const UserProfile({
    required this.username,
    required this.handle,
    required this.avatarUrl,
    this.dailyMinutesGoal = 120,
    this.dailyMinutesListened = 74,
  });

  final String username;
  final String handle;
  final String avatarUrl;
  final int dailyMinutesGoal;
  final int dailyMinutesListened;
}
