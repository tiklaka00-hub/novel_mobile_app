import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.onContinue});

  final Future<void> Function(String method, {String? email}) onContinue;

  Future<void> _openEmailPrompt(BuildContext context) async {
    final controller = TextEditingController();
    final email = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continue with Email',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Enter your email to open the app with a local session.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'your@email.com'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
    if (email == null || email.isEmpty || !context.mounted) {
      return;
    }
    await onContinue('email', email: email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDF9F3), Color(0xFFEAF5F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 64),
                        Text(
                          'Inkitt',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: 54,
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w700,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Discover Millions of Free Books',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppTheme.muted),
                        ),
                        const SizedBox(height: 52),
                        _LoginButton(
                          icon: Icons.g_mobiledata_rounded,
                          label: 'Continue with Google',
                          onPressed: () => onContinue('google'),
                        ),
                        const SizedBox(height: 12),
                        _LoginButton(
                          icon: Icons.email_outlined,
                          label: 'Continue with Email',
                          onPressed: () => _openEmailPrompt(context),
                        ),
                        const SizedBox(height: 12),
                        _LoginButton(
                          icon: Icons.person_outline,
                          label: 'Continue without sign in',
                          onPressed: () => onContinue('guest'),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'By continuing you agree to our Terms of Service and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.ink,
          side: const BorderSide(color: AppTheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: const Color(0xFF525252)),
        ),
      ),
    );
  }
}
