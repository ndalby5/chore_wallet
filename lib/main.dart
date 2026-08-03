import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/navigation/app_router.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://oqvduvjghksjavyzkual.supabase.co',
    publishableKey: 'sb_publishable_OiTRo2YDMhmOvEAa-JktAQ_SMfEZHXF',
  );

  runApp(const PocketPotApp());
}

class PocketPotApp extends StatelessWidget {
  const PocketPotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PocketPot',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
      ),
      initialRoute: '/welcome',
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}