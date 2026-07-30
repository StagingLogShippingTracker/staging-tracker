import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_config.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../shared/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = email.isEmpty && password.isEmpty
            ? 'Enter your email and password.'
            : email.isEmpty
                ? 'Enter your email address.'
                : 'Enter your password.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(supabaseClientProvider).auth.signInWithPassword(
            email: email,
            password: password,
          );
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return 'Confirm your email before signing in. Check your inbox for the link.';
    }
    if (lower.contains('invalid login') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid email or password')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('missing email') ||
        lower.contains('validation_failed')) {
      return 'Enter a valid email and password.';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Could not reach the sign-in service. Check your connection and try again.';
    }
    // Strip AuthApiException(...) wrappers when present.
    final msg = RegExp(r'message:\s*([^,\)]+)').firstMatch(raw)?.group(1);
    if (msg != null && msg.trim().isNotEmpty) {
      return msg.trim();
    }
    return 'Sign in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: IndustrialTheme.darkBase,
      appBar: AppBar(
        backgroundColor: IndustrialTheme.darkHeader,
        title: const Text('Sign In'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLogo(height: 120)),
                    const SizedBox(height: 24),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in to SLST to create and edit staging or '
                              'shipping records. Signed-out users cannot view '
                              'or change operational data.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: IndustrialTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              label: 'Email',
                              textField: true,
                              child: TextField(
                                controller: _email,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'you@example.com',
                                  prefixIcon: Icon(Icons.alternate_email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                onTapOutside: (_) => FocusManager
                                    .instance.primaryFocus
                                    ?.unfocus(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Semantics(
                              label: 'Password',
                              textField: true,
                              obscured: true,
                              child: TextField(
                                controller: _password,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Password',
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
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => _signIn(),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _busy ? null : _signIn,
                              child:
                                  Text(_busy ? 'Signing in…' : 'Sign In'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final uri = Uri(
                                  scheme: 'mailto',
                                  path: AppConfig.accessRequestEmail,
                                  queryParameters: {
                                    'subject':
                                        'Access Request: SLST',
                                    'body':
                                        'Hello,\n\nI am requesting user access to create and edit entries on SLST.\n',
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
                    const BrandFooter(),
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
