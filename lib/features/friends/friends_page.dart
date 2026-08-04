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
  bool _isCreatingInvite = false;

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

      // Temporary web link for development.
      // We will replace this with the final PocketPot domain later.
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
                : const Icon(Icons.person_add_alt_1_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
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
          Container(
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
                  onPressed:
                      _isCreatingInvite ? null : _shareInvite,
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Share invite'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}