import 'package:flutter/material.dart';

abstract final class MnsColors {
  static const navy = Color(0xFF10152A);
  static const orange = Color(0xFFFF6B24);
  static const cream = Color(0xFFFFF8F1);
  static const success = Color(0xFF16845B);
}

abstract final class MnsTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: MnsColors.orange, primary: MnsColors.orange, secondary: MnsColors.navy, surface: Colors.white),
        scaffoldBackgroundColor: MnsColors.cream,
        appBarTheme: const AppBarTheme(backgroundColor: MnsColors.navy, foregroundColor: Colors.white, centerTitle: false),
        cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      );
}

class MnsPage extends StatelessWidget {
  const MnsPage({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1180), child: Padding(padding: const EdgeInsets.all(20), child: child)))),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.color = MnsColors.orange});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 52, color: MnsColors.orange), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center)]));
}

