import 'package:flutter/material.dart';

import '../../features/auth/login_page.dart';
import '../../features/auth/signup_page.dart';
import '../../features/auth/welcome_page.dart';
import 'app_shell.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/welcome':
        return MaterialPageRoute(
          builder: (_) => const WelcomePage(),
        );

      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
        );

      case '/signup':
        return MaterialPageRoute(
          builder: (_) => const SignupPage(),
        );

      case '/home':
        return MaterialPageRoute(
          builder: (_) => const AppShell(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const WelcomePage(),
        );
    }
  }
}
