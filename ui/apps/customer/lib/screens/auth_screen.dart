import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/customer_state.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(sessionProvider.notifier);
    final ok = _register
        ? await controller.register(_name.text, _email.text, _password.text)
        : await controller.login(_email.text, _password.text);
    if (ok && mounted) context.go('/home');
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Color(0xFF154734), shape: BoxShape.circle),
                      child: const Text('M&S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                    ),
                    const SizedBox(height: 28),
                    Text(_register ? 'Create your account' : 'Welcome back', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_register ? 'Fresh favorites are a few taps away.' : 'Sign in to order and track your delivery.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54)),
                    const SizedBox(height: 32),
                    if (_register) ...[
                      TextFormField(controller: _name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)), validator: (value) => value == null || value.trim().length < 2 ? 'Enter your name' : null),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)), validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email'),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
                      validator: (value) => value != null && value.length >= 8 ? null : 'Use at least 8 characters',
                    ),
                    if (state.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                    const SizedBox(height: 22),
                    FilledButton(onPressed: state.loading ? null : _submit, child: state.loading ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_register ? 'Create account' : 'Sign in')),
                    TextButton(onPressed: state.loading ? null : () => setState(() => _register = !_register), child: Text(_register ? 'Already have an account? Sign in' : 'New to M&S? Create an account')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
