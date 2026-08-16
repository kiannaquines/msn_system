import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/admin_state.dart';
import 'shell_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  late final AnimationController _anim;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
    Future.microtask(() => ref.read(adminProvider.notifier).restore());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(adminProvider.notifier).login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    if (state.authenticated && state.snapshot != null) return const ShellScreen();

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // ── Left: Dark Purple Brand Panel ────────────────
            Expanded(
              flex: 5,
              child: _DesktopBrandPanel(),
            ),
            // ── Right: White Form Panel ───────────────────────
            Expanded(
              flex: 4,
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideIn,
                  child: Container(
                    color: const Color(0xFFF9F7FD),
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(48),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: _buildForm(state),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile: hero stack + sheet ────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFF7C3AED),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                          Text('M&S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Operations\nPortal',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: Colors.white, letterSpacing: -0.8, height: 1.1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'M&S Delivery Command Console',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                    .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic)),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9F7FD),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: _buildForm(state),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AdminState state) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          const Text(
            'ADMINISTRATOR ACCESS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7C3AED),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sign in with your administrator credentials.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),

          // Email
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Administrator Email',
              hintText: 'admin@mns.ph',
              prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
              ),
            ),
            validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email address',
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _password,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Account Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: const Color(0xFF94A3B8),
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
              ),
            ),
            validator: (v) => v != null && v.length >= 8 ? null : 'Use at least 8 characters',
          ),

          // Error
          if (state.error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(state.error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: state.loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                disabledBackgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: state.loading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.arrow_forward_rounded, size: 20),
              label: state.loading
                  ? const SizedBox.shrink()
                  : const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop brand panel widget ──────────────────────────────────────────────
class _DesktopBrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                ),
                child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('M&S System', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                  Text('Operations Portal', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Hero text
          Text(
            'High-Velocity\nDelivery Command\nConsole.',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 36,
              letterSpacing: -1,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Complete operational control over fleet dispatches, order lifecycles, catalog management, and COD settlements.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 36),

          _FeatureRow(Icons.radar_rounded, 'Real-time GPS fleet telemetry & dispatch radar'),
          const SizedBox(height: 14),
          _FeatureRow(Icons.verified_user_rounded, 'Role-based access & strict audit trails'),
          const SizedBox(height: 14),
          _FeatureRow(Icons.receipt_long_rounded, 'Live COD tracking with idempotency safeguards'),

          const Spacer(),

          // Trust badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.white70, size: 15),
                const SizedBox(width: 8),
                Text(
                  'Vercel Serverless · Supabase PostgreSQL Secured',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
