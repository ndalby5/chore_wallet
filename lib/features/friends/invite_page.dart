import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_colors.dart';

class InvitePage extends StatefulWidget {
  final String token;

  const InvitePage({
    super.key,
    required this.token,
  });

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  bool _isLoading = true;
  bool _isAccepting = false;
  String? _senderName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_friend_invite_preview',
        params: {
          'invite_token': widget.token,
        },
      );

      final invite = Map<String, dynamic>.from(response as Map);

      if (!mounted) return;

      setState(() {
        _senderName = invite['sender_name']?.toString() ?? 'Someone';
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'This invite could not be opened.';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvite() async {
    setState(() {
      _isAccepting = true;
    });

    try {
      await Supabase.instance.client.rpc(
        'accept_friend_invite',
        params: {
          'invite_token': widget.token,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You and ${_senderName ?? 'your friend'} are now connected.',
          ),
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not accept the invite.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Friend invite'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_errorMessage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.link_off_outlined,
            size: 54,
            color: AppColors.subtitle,
          ),
          const SizedBox(height: 18),
          const Text(
            'Invite unavailable',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.subtitle,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(
            Icons.people_outline,
            size: 46,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '$_senderName wants to add you',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Accept the invite to assign tasks and track balances together.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: AppColors.subtitle,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: _isAccepting ? null : _acceptInvite,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: _isAccepting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Accept invite'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          },
          child: const Text('Not now'),
        ),
      ],
    );
  }
}