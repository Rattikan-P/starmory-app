import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_page.dart';
import 'otp_verification_page.dart';

class LoginMethodPage extends ConsumerWidget {
  final String? email;
  final String? displayName;
  final String? languageLevel;
  final String? englishVariant;
  final bool isRegistration;

  const LoginMethodPage({
    super.key,
    this.email,
    this.displayName,
    this.languageLevel,
    this.englishVariant,
    this.isRegistration = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Icon(
                    Icons.login_rounded,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    isRegistration ? 'Create your account' : 'Welcome Back',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    isRegistration
                        ? 'Enter your email to get started'
                        : 'Continue your language journey',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Email OTP Card
                  _MethodCard(
                    icon: Icons.email_rounded,
                    title: 'Email',
                    subtitle: 'Sign in with email OTP',
                    description: 'We\'ll send a code to your email',
                    isPrimary: true,
                    onTap: () => _goToEmailOtp(context),
                  ),
                  const SizedBox(height: 16),

                  // Google Card (Coming Soon)
                  _MethodCard(
                    icon: Icons.g_mobiledata_rounded,
                    title: 'Continue with Google',
                    subtitle: 'Quick & easy sign in',
                    description: 'Coming Soon',
                    isPrimary: false,
                    isComingSoon: true,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Google Sign In coming soon!')),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Back button
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goToEmailOtp(BuildContext context) {
    // If email is already provided, go directly to OTP
    if (email != null && email!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            email: email!,
            displayName: displayName,
            languageLevel: languageLevel,
            englishVariant: englishVariant,
          ),
        ),
      );
    } else {
      // Otherwise go to login page first to get email
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(
            displayName: displayName,
            languageLevel: languageLevel,
            englishVariant: englishVariant,
            isRegistration: isRegistration,
          ),
        ),
      );
    }
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final bool isPrimary;
  final bool isComingSoon;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
    this.isPrimary = false,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: isComingSoon ? null : onTap,
      child: Opacity(
        opacity: isComingSoon ? 0.6 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: isPrimary
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
              width: isPrimary ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: isPrimary
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isPrimary
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow or Badge
              if (isComingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Soon',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
