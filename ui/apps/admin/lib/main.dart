import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mns_design_system/design_system.dart';

import 'screens/login_screen.dart';

void main() => runApp(const ProviderScope(child: AdminApp()));

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'M&S Operations',
        debugShowCheckedModeBanner: false,
        theme: MnsTheme.light().copyWith(cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))))),
        home: const LoginScreen(),
      );
}
