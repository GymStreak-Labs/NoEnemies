import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'router/app_router.dart';
import 'services/subscription_service.dart';
import 'theme/app_theme.dart';

class NoEnemiesApp extends StatelessWidget {
  const NoEnemiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final subscriptionService = context.watch<SubscriptionService>();

    return MaterialApp.router(
      title: 'No Enemies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router(userProvider, subscriptionService),
    );
  }
}
