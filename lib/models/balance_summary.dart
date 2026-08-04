import 'friend_balance.dart';

class BalanceSummary {
  final int owedToYouPence;
  final int youOwePence;
  final List<FriendBalance> friendBalances;

  const BalanceSummary({
    required this.owedToYouPence,
    required this.youOwePence,
    required this.friendBalances,
  });

  int get overallBalancePence => owedToYouPence - youOwePence;

  const BalanceSummary.empty()
      : owedToYouPence = 0,
        youOwePence = 0,
        friendBalances = const [];
}