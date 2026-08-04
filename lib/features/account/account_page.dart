import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!context.mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sign out. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.account_circle,
                size: 100,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 16),
              Text(
                Supabase.instance.client.auth.currentUser?.email ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}