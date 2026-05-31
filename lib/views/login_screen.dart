import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_providers.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _register = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storefront,
                          size: 58,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Smart Shop',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _register
                              ? 'Register new admin'
                              : 'Offline billing and inventory',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 18),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Login'),
                              icon: Icon(Icons.login),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Register'),
                              icon: Icon(Icons.person_add_alt),
                            ),
                          ],
                          selected: {_register},
                          onSelectionChanged: _loading
                              ? null
                              : (value) {
                                  setState(() {
                                    _register = value.first;
                                    _error = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 14),
                        if (_register) ...[
                          TextField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Admin name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            errorText: _error,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) =>
                              _register ? _registerAdmin() : _submit(),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _loading
                              ? null
                              : _register
                              ? _registerAdmin
                              : _submit,
                          icon: _loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _register
                                      ? Icons.person_add_alt
                                      : Icons.login,
                                ),
                          label: Text(_register ? 'Register admin' : 'Unlock'),
                        ),
                        if (!_register) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _loading ? null : _biometric,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Use biometric'),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Demo passwords: Admin@123, Editor@123, Seller@123',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          const SizedBox(height: 10),
                          Text(
                            'Password needs 8+ characters with alphabet, number and special character.',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter email');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Enter password');
      return;
    }
    setState(() => _loading = true);
    final ok = await ref
        .read(authProvider.notifier)
        .login(password, email: _email.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = ok ? null : 'Incorrect password';
      if (!ok) _password.clear();
    });
    if (ok) ref.invalidate(selectedShopProvider);
  }

  Future<void> _registerAdmin() async {
    setState(() => _loading = true);
    final error = await ref
        .read(authProvider.notifier)
        .registerAdmin(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
      if (error == null) {
        _password.clear();
      }
    });
    if (error == null) ref.invalidate(selectedShopProvider);
  }

  Future<void> _biometric() async {
    final ok = await AuthService().authenticateBiometric();
    if (ok) {
      await ref
          .read(authProvider.notifier)
          .login('Admin@123', email: 'admin@smartshop.local');
      ref.invalidate(selectedShopProvider);
    }
  }
}
