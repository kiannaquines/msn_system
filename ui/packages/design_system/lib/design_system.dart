import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

export 'package:google_fonts/google_fonts.dart';

abstract final class MnsColors {
  static const navy = Color(0xFF1E142F);
  static const slate = Color(0xFF281D3D);
  static const lightSlate = Color(0xFF3B2D5A);
  static const primary = Color(0xFFA87FF0);
  static const orange = Color(0xFFFF6B24);
  static const lavender = Color(0xFFB89CE5);
  static const pink = Color(0xFFF2A3C2);
  static const sky = Color(0xFF8CD8F5);
  static const amber = Color(0xFFF59E0B);
  static const cream = Color(0xFFFAF8FF);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
}

abstract final class MnsGradients {
  /// Solid Primary
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF7C3AED)],
  );

  /// Solid Lavender / Purple
  static const LinearGradient lavenderDream = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF7C3AED)],
  );

  /// Solid Slate / Midnight
  static const LinearGradient midnight = LinearGradient(
    colors: [Color(0xFF1E142F), Color(0xFF1E142F)],
  );

  /// Solid Emerald
  static const LinearGradient emerald = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF10B981)],
  );

  /// Solid Amber
  static const LinearGradient golden = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF59E0B)],
  );

  /// Solid Royal Violet
  static const LinearGradient royal = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF7C3AED)],
  );

  /// Solid Crimson
  static const LinearGradient crimson = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFDC2626)],
  );

  /// Solid Canvas Background
  static const LinearGradient background = LinearGradient(
    colors: [Color(0xFFF9F7FD), Color(0xFFF9F7FD)],
  );

  /// Solid Card Surface
  static const LinearGradient card = LinearGradient(
    colors: [Colors.white, Colors.white],
  );

  /// Solid Warm Card Surface
  static const LinearGradient cardWarm = LinearGradient(
    colors: [Color(0xFFFAF5FF), Color(0xFFFAF5FF)],
  );
}

abstract final class MnsTheme {
  static ThemeData light() {
    final baseTheme = ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      fontFamilyFallback: const ['Google Sans', 'Plus Jakarta Sans', 'Product Sans', 'sans-serif'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7C3AED),
        primary: const Color(0xFF7C3AED),
        secondary: const Color(0xFF1E142F),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF9F7FD),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF7C3AED),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5DEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5DEEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme),
      primaryTextTheme: GoogleFonts.plusJakartaSansTextTheme(baseTheme.primaryTextTheme),
    );
  }
}

class MnsGradientButton extends StatelessWidget {
  const MnsGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = MnsGradients.primary,
    this.color = const Color(0xFF7C3AED),
    this.height = 52,
    this.borderRadius = 16,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Gradient gradient;
  final Color color;
  final double height;
  final double borderRadius;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isEnabled ? color : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: isEnabled ? onPressed : null,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

class MnsGradientCard extends StatelessWidget {
  const MnsGradientCard({
    super.key,
    required this.child,
    this.gradient = MnsGradients.card,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 20,
    this.borderColor = const Color(0xFFE5DEEE),
    this.onTap,
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class MnsPage extends StatelessWidget {
  const MnsPage({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF9F7FD),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E142F),
          elevation: 0,
          scrolledUnderElevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFE5DEEE)),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1E142F))),
          actions: actions,
        ),
        body: Container(
          color: const Color(0xFFF9F7FD),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(padding: const EdgeInsets.all(20), child: child),
              ),
            ),
          ),
        ),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.gradient,
    this.textColor = Colors.white,
  });

  final String label;
  final Gradient? gradient;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: gradient ?? MnsGradients.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB89CE5).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 11),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFB89CE5),
                    Color(0xFFF2A3C2),
                    Color(0xFF8CD8F5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB89CE5).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
}
