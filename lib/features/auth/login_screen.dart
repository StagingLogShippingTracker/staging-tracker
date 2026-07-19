import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(supabaseClientProvider).auth.signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/staging-shipping-logo.png',
                      width: 72,
                      height: 72,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.local_shipping,
                        size: 48,
                        color: SlstColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SLST',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kBrandFontFamily,
                      fontSize: 34,
                      height: 1.1,
                    ),
                  ),
                  const Text(
                    'STAGING LOG & SHIPPING TRACKER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: SlstColors.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sign in to create and edit staging/shipping records. Anonymous users remain read-only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: SlstColors.muted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _signIn(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: Text(_busy ? 'Signing in…' : 'Sign In'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final uri = Uri(
                        scheme: 'mailto',
                        path: AppConfig.accessRequestEmail,
                        queryParameters: {
                          'subject':
                              'Access Request: Staging Log & Shipping Tracker',
                          'body':
                              'Hello,\n\nI am requesting user access to create and edit entries on the Staging Log & Shipping Tracker.\n',
                        },
                      );
                      await launchUrl(uri);
                    },
                    child: const Text('Request Access'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
