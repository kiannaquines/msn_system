import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mns_design_system/design_system.dart';
import 'package:mns_rider/src/screens/home_screen.dart';
import 'package:mns_rider/src/screens/login_screen.dart';
import 'package:mns_rider/src/state/rider_controller.dart';

class RiderApp extends ConsumerWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(riderControllerProvider);
    return MaterialApp(
      title: 'M&S Rider',
      debugShowCheckedModeBanner: false,
      theme: MnsTheme.light(),
      home: state.isRestoring
          ? const _LaunchScreen()
          : state.isAuthenticated
              ? const RiderHomeScreen()
              : const RiderLoginScreen(),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delivery_dining, size: 72, color: MnsColors.orange),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
}
