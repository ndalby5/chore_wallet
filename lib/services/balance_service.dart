import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/balance_summary.dart';
import '../models/friend_balance.dart';

class BalanceService {
  BalanceService({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<BalanceSummary> getBalanceSummary() async {
    final currentUser = _client.auth.currentUser;

    if (currentUser == null) {
      throw const BalanceServiceException(
        'You need to sign in again.',
      );
    }

    try {
      final rows = await _client
          .from('transactions')
          .select(
            'user_id, friend_id, amount_pence, type',
          )
          .or(
            'user_id.eq.${currentUser.id},'
            'friend_id.eq.${currentUser.id}',
          );

      final transactions =
          List<Map<String, dynamic>>.from(rows);

      final balancesByFriend = <String, int>{};

      for (final transaction in transactions) {
        final receiverId =
            transaction['user_id']?.toString();

        final otherPersonId =
            transaction['friend_id']?.toString();

        final amountPence = _readPence(
          transaction['amount_pence'],
        );

        if (receiverId == null ||
            otherPersonId == null ||
            amountPence == 0) {
          continue;
        }

        if (receiverId == currentUser.id) {
          // The current user earned or received this money,
          // so the friend owes the current user.
          balancesByFriend.update(
            otherPersonId,
            (existing) => existing + amountPence,
            ifAbsent: () => amountPence,
          );
        } else if (otherPersonId == currentUser.id) {
          // The friend earned or received this money,
          // so the current user owes the friend.
          balancesByFriend.update(
            receiverId,
            (existing) => existing - amountPence,
            ifAbsent: () => -amountPence,
          );
        }
      }

      final friendBalances = balancesByFriend.entries
          .map(
            (entry) => FriendBalance(
              friendId: entry.key,
              balancePence: entry.value,
            ),
          )
          .toList()
        ..sort(
          (first, second) => second.balancePence
              .compareTo(first.balancePence),
        );

      var owedToYouPence = 0;
      var youOwePence = 0;

      for (final balance in friendBalances) {
        if (balance.balancePence > 0) {
          owedToYouPence += balance.balancePence;
        } else if (balance.balancePence < 0) {
          youOwePence += balance.balancePence.abs();
        }
      }

      return BalanceSummary(
        owedToYouPence: owedToYouPence,
        youOwePence: youOwePence,
        friendBalances: friendBalances,
      );
    } on PostgrestException catch (error) {
      throw BalanceServiceException(error.message);
    } catch (error) {
      if (error is BalanceServiceException) {
        rethrow;
      }

      throw const BalanceServiceException(
        'Could not calculate your balances.',
      );
    }
  }

  Future<int> getBalanceWithFriend(
    String friendId,
  ) async {
    final summary = await getBalanceSummary();

    for (final balance in summary.friendBalances) {
      if (balance.friendId == friendId) {
        return balance.balancePence;
      }
    }

    return 0;
  }

  int _readPence(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class BalanceServiceException implements Exception {
  final String message;

  const BalanceServiceException(this.message);

  @override
  String toString() => message;
}