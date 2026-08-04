import 'package:flutter/material.dart';

import '../../features/auth/login_page.dart';
import '../../features/auth/signup_page.dart';
import '../../features/auth/welcome_page.dart';
import 'app_shell.dart';
import '../../features/friends/invite_page.dart'; 

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/welcome');  
    
    switch (uri.path) {
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

      case '/invite':
        final token = uri.queryParameters['token'];

        if (token == null || token.isEmpty) {
          return MaterialPageRoute(
            builder: (_) => const WelcomePage(),
          );
        }

        return MaterialPageRoute(
          builder: (_) => InvitePage(token: token),
        );  

      default:
        return MaterialPageRoute(
          builder: (_) => const WelcomePage(),
        );
    }
  }
}
