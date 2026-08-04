class FriendBalance {
  final String friendId;
  final int balancePence;

  const FriendBalance({
    required this.friendId,
    required this.balancePence,
  });

  bool get owesYou => balancePence > 0;

  bool get youOwe => balancePence < 0;

  bool get isSettled => balancePence == 0;

  int get absoluteBalancePence => balancePence.abs();
}