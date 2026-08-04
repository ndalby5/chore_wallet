import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  bool _isLoadingFriends = true;
  bool _isCreatingInvite = false;

  String? _errorMessage;
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      setState(() {
        _errorMessage = 'You need to sign in again.';
        _isLoadingFriends = false;
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

      final friendIds = friendships.map((friendship) {
        final userOneId = friendship['user_one_id']?.toString();
        final userTwoId = friendship['user_two_id']?.toString();

        return userOneId == currentUser.id ? userTwoId : userOneId;
      }).whereType<String>().toList();

      if (friendIds.isEmpty) {
        if (!mounted) return;

        setState(() {
          _friends = [];
          _isLoadingFriends = false;
        });
        return;
      }

      final profileRows = await Supabase.instance.client
          .from('profiles')
          .select('id, name')
          .inFilter('id', friendIds)
          .order('name');

      if (!mounted) return;

      setState(() {
        _friends = List<Map<String, dynamic>>.from(profileRows);
        _isLoadingFriends = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoadingFriends = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Could not load your friends.';
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _shareInvite() async {
    setState(() {
      _isCreatingInvite = true;
    });

    try {
      final response = await Supabase.instance.client.rpc(
        'create_friend_invite',
      );

      final invite = Map<String, dynamic>.from(response as Map);
      final token = invite['token']?.toString();

      if (token == null || token.isEmpty) {
        throw Exception('No invite token was returned.');
      }

      final inviteLink =
          'http://localhost:5000/#/invite?token=$token';

      await SharePlus.instance.share(
        ShareParams(
          text:
              'Join me on PocketPot and connect as friends:\n$inviteLink',
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

  Future<void> _refreshFriends() async {
    setState(() {
      _isLoadingFriends = true;
      _errorMessage = null;
    });

    await _loadFriends();
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
            onPressed: _isCreatingInvite ? null : _shareInvite,
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
        onRefresh: _refreshFriends,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search friends',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '£0.00',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'You are all settled up',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Friends',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _buildFriendsContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsContent() {
    if (_isLoadingFriends) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 42,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _refreshFriends,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
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
              'Invite someone to start assigning tasks and tracking balances.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.subtitle,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isCreatingInvite ? null : _shareInvite,
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('Share invite'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: List.generate(_friends.length, (index) {
          final friend = _friends[index];
          final name = friend['name']?.toString() ?? 'Friend';

          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty
                        ? name.substring(0, 1).toUpperCase()
                        : '?',
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
                subtitle: const Text('Settled'),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () {
                  // Friend detail page will be added later.
                },
              ),
              if (index < _friends.length - 1)
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
}