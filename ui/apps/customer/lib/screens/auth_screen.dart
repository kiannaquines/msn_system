import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/customer_state.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  late final AnimationController _anim;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(sessionProvider.notifier);
    final ok = _register
        ? await controller.register(_name.text.trim(), _email.text.trim(), _password.text)
        : await controller.login(_email.text.trim(), _password.text);
    if (ok && mounted) context.go('/home');
  }

  void _toggleMode() {
    ref.read(sessionProvider.notifier).clearError();
    setState(() {
      _register = !_register;
    });
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionProvider);
    if (state.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF7C3AED),
      body: Column(
        children: [
          // ── Purple Hero Header ────────────────────────────────
          Expanded(
            flex: 2,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo mark
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 26),
                            Text(
                              'M&S',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Column(
                          key: ValueKey(_register),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _register ? 'Create account' : 'Welcome back',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _register
                                  ? 'Create your account to start ordering fresh food.'
                                  : 'Sign in to order and track your delivery.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── White Form Sheet ──────────────────────────────────
          Expanded(
            flex: 3,
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9F7FD),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Section label
                          Text(
                            _register ? 'ACCOUNT DETAILS' : 'SIGN IN',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7C3AED),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Name field (register only)
                          if (_register) ...[
                            _buildField(
                              controller: _name,
                              label: 'Full Name',
                              hint: 'e.g. Maria Santos',
                              icon: Icons.person_outline_rounded,
                              action: TextInputAction.next,
                              validator: (v) => v == null || v.trim().length < 2 ? 'Enter your name' : null,
                            ),
                            const SizedBox(height: 14),
                          ],

                          _buildField(
                            controller: _email,
                            label: 'Email Address',
                            hint: 'customer@mns.ph',
                            icon: Icons.alternate_email_rounded,
                            action: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                          ),
                          const SizedBox(height: 14),

                          // Password field
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: const Color(0xFF94A3B8),
                                ),
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
                                    child: Text(
                                      state.error!,
                                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Submit button
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: state.loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                disabledBackgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: state.loading
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : Text(
                                      _register ? 'Create account' : 'Sign in',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Toggle sign in / register
                          Center(
                            child: GestureDetector(
                              onTap: state.loading ? null : _toggleMode,
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                  children: [
                                    TextSpan(
                                      text: _register ? 'Already have an account? ' : 'New to M&S? ',
                                    ),
                                    TextSpan(
                                      text: _register ? 'Sign in' : 'Create an account',
                                      style: const TextStyle(
                                        color: Color(0xFF7C3AED),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Trust badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Text(
                                'Cash on Delivery · Verified Courier Network',
                                style: TextStyle(
                                  color: const Color(0xFF64748B).withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputAction action,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: action,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
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
      validator: validator,
    );
  }
}
