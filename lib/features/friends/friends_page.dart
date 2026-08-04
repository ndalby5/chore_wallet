import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/balance_summary.dart';
import '../../services/balance_service.dart';
import '../../theme/app_colors.dart';
import 'friend_detail_page.dart'; 

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final BalanceService _balanceService = BalanceService();
  final TextEditingController _searchController =
      TextEditingController();

  bool _isLoading = true;
  bool _isCreatingInvite = false;

  String? _errorMessage;

  List<Map<String, dynamic>> _friends = [];
  BalanceSummary _balanceSummary = const BalanceSummary.empty();

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {});
    });

    _loadPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      setState(() {
        _errorMessage = 'You need to sign in again.';
        _isLoading = false;
      });
      return;
    }

    try {
      final friendshipRows = await Supabase.instance.client
          .from('friendships')
          .select('user_one_id, user_two_id')
          .or(
            'user_one_id.eq.${currentUser.id},'
            'user_two_id.eq.${currentUser.id}',
          );

      final friendships =
          List<Map<String, dynamic>>.from(friendshipRows);

      final friendIds = friendships
          .map((friendship) {
            final userOneId =
                friendship['user_one_id']?.toString();

            final userTwoId =
                friendship['user_two_id']?.toString();

            return userOneId == currentUser.id
                ? userTwoId
                : userOneId;
          })
          .whereType<String>()
          .toList();

      List<Map<String, dynamic>> profiles = [];

      if (friendIds.isNotEmpty) {
        final profileRows = await Supabase.instance.client
            .from('profiles')
            .select('id, name')
            .inFilter('id', friendIds)
            .order('name');

        profiles = List<Map<String, dynamic>>.from(
          profileRows,
        );
      }

      final balanceSummary =
          await _balanceService.getBalanceSummary();

      final balancesByFriend = {
        for (final balance in balanceSummary.friendBalances)
          balance.friendId: balance.balancePence,
      };

      final friendsWithBalances = profiles.map((profile) {
        final friendId = profile['id']?.toString() ?? '';

        return <String, dynamic>{
          ...profile,
          'balance_pence': balancesByFriend[friendId] ?? 0,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _friends = friendsWithBalances;
        _balanceSummary = balanceSummary;
        _errorMessage = null;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } on BalanceServiceException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load your friends.';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _loadPage();
  }

  Future<void> _shareInvite() async {
    setState(() {
      _isCreatingInvite = true;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'create_friend_invite',
      );

      final invite = Map<String, dynamic>.from(
        response as Map,
      );

      final token = invite['token']?.toString();

      if (token == null || token.isEmpty) {
        throw Exception('No invite token was returned.');
      }

      final inviteLink =
          'http://localhost:5000/#/invite?token=$token';

      await SharePlus.instance.share(
        ShareParams(
          text:
              'Join me on PocketPot and connect as friends:\n'
              '$inviteLink',
          subject: 'PocketPot friend invite',
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not create the invite. $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingInvite = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredFriends {
    final search = _searchController.text.trim().toLowerCase();

    if (search.isEmpty) {
      return _friends;
    }

    return _friends.where((friend) {
      final name =
          friend['name']?.toString().toLowerCase() ?? '';

      return name.contains(search);
    }).toList();
  }

  List<Map<String, dynamic>> get _friendsWhoOweYou {
    return _filteredFriends.where((friend) {
      return _readPence(friend['balance_pence']) > 0;
    }).toList();
  }

  List<Map<String, dynamic>> get _friendsYouOwe {
    return _filteredFriends.where((friend) {
      return _readPence(friend['balance_pence']) < 0;
    }).toList();
  }

  List<Map<String, dynamic>> get _settledFriends {
    return _filteredFriends.where((friend) {
      return _readPence(friend['balance_pence']) == 0;
    }).toList();
  }

  int _readPence(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatMoney(int pence) {
    return '£${(pence.abs() / 100).toStringAsFixed(2)}';
  }

  String _formatOverallBalance(int pence) {
    if (pence > 0) {
      return '+${_formatMoney(pence)}';
    }

    if (pence < 0) {
      return '-${_formatMoney(pence)}';
    }

    return '£0.00';
  }

  String _friendInitial(String name) {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      return '?';
    }

    return trimmedName.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Friends',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            tooltip: 'Add friend',
            onPressed:
                _isCreatingInvite ? null : _shareInvite,
            icon: _isCreatingInvite
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.person_add_alt_1_outlined,
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(
            Icons.error_outline,
            size: 52,
            color: AppColors.danger,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _refreshPage,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search friends',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildBalanceCard(),
        const SizedBox(height: 30),
        if (_friends.isEmpty)
          _buildEmptyState()
        else ...[
          if (_friendsWhoOweYou.isNotEmpty) ...[
            _buildSectionTitle('Owes you'),
            const SizedBox(height: 12),
            _buildFriendsCard(
              _friendsWhoOweYou,
              balanceType: FriendBalanceType.owesYou,
            ),
            const SizedBox(height: 26),
          ],
          if (_friendsYouOwe.isNotEmpty) ...[
            _buildSectionTitle('You owe'),
            const SizedBox(height: 12),
            _buildFriendsCard(
              _friendsYouOwe,
              balanceType: FriendBalanceType.youOwe,
            ),
            const SizedBox(height: 26),
          ],
          if (_settledFriends.isNotEmpty) ...[
            _buildSectionTitle('Settled'),
            const SizedBox(height: 12),
            _buildFriendsCard(
              _settledFriends,
              balanceType: FriendBalanceType.settled,
            ),
          ],
          if (_filteredFriends.isEmpty)
            _buildNoSearchResults(),
        ],
      ],
    );
  }

  Widget _buildBalanceCard() {
    final overallBalance =
        _balanceSummary.overallBalancePence;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatOverallBalance(overallBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildBalanceBreakdown(
                  label: 'You are owed',
                  amount: _formatMoney(
                    _balanceSummary.owedToYouPence,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 42,
                color: Colors.white24,
              ),
              Expanded(
                child: _buildBalanceBreakdown(
                  label: 'You owe',
                  amount: _formatMoney(
                    _balanceSummary.youOwePence,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceBreakdown({
    required String label,
    required String amount,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildFriendsCard(
    List<Map<String, dynamic>> friends, {
    required FriendBalanceType balanceType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFEAE8F2),
        ),
      ),
      child: Column(
        children: List.generate(friends.length, (index) {
          final friend = friends[index];

          return Column(
            children: [
              _buildFriendRow(
                friend,
                balanceType: balanceType,
              ),
              if (index < friends.length - 1)
                const Divider(
                  height: 1,
                  indent: 72,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFriendRow(
    Map<String, dynamic> friend, {
    required FriendBalanceType balanceType,
  }) {
    final name = friend['name']?.toString() ?? 'Friend';
    final balancePence =
        _readPence(friend['balance_pence']);

    String balanceText;
    Color balanceColor;

    switch (balanceType) {
      case FriendBalanceType.owesYou:
        balanceText = _formatMoney(balancePence);
        balanceColor = AppColors.success;

      case FriendBalanceType.youOwe:
        balanceText = _formatMoney(balancePence);
        balanceColor = AppColors.danger;

      case FriendBalanceType.settled:
        balanceText = 'Settled';
        balanceColor = AppColors.subtitle;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      leading: CircleAvatar(
        backgroundColor:
            AppColors.primary.withValues(alpha: 0.12),
        child: Text(
          _friendInitial(name),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            balanceText,
            style: TextStyle(
              color: balanceColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        final friendId = friend['id']?.toString();

        if (friendId == null || friendId.isEmpty) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FriendDetailPage(
              friendId: friendId,
              friendName: name,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFEAE8F2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline,
            size: 42,
            color: AppColors.primary,
          ),
          const SizedBox(height: 14),
          const Text(
            'No friends yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Invite someone to start assigning tasks '
            'and tracking balances.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.subtitle,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed:
                _isCreatingInvite ? null : _shareInvite,
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Add Friend'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'No matching friends found.',
          style: TextStyle(
            color: AppColors.subtitle,
          ),
        ),
      ),
    );
  }
}

enum FriendBalanceType {
  owesYou,
  youOwe,
  settled,
}