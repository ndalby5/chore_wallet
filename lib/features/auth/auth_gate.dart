import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation/app_shell.dart';
import 'welcome_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
      onError: (_) {
        // Keep the current screen if a temporary refresh error occurs.
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session =
        Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return const AppShell();
    }

    return const WelcomePage();
  }
}