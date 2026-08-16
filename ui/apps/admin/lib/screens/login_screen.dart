import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/admin_state.dart';
import 'shell_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).restore());
  }

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(adminProvider.notifier).login(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    if (state.authenticated && state.snapshot != null) return const ShellScreen();
    return Scaffold(body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Card(child: Padding(padding: const EdgeInsets.all(32), child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const CircleAvatar(radius: 34, child: Text('M&S', style: TextStyle(fontWeight: FontWeight.w900))),
      const SizedBox(height: 24),
      Text('Operations portal', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('Sign in with an administrator account.', textAlign: TextAlign.center),
      const SizedBox(height: 28),
      TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)), validator: (value) => value != null && value.contains('@') ? null : 'Enter a valid email'),
      const SizedBox(height: 14),
      TextFormField(controller: _password, obscureText: true, onFieldSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)), validator: (value) => value != null && value.length >= 8 ? null : 'Use at least 8 characters'),
      if (state.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 22),
      FilledButton(onPressed: state.loading ? null : _submit, child: state.loading ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in')),
    ]))))))));
  }
}
