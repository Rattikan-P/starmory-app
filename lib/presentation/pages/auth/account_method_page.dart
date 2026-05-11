import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/hive_service.dart';
import '../main_navigation.dart';
import '../onboarding_page.dart';
import 'email_login_page.dart';

class AccountMethodPage extends ConsumerWidget {
  const AccountMethodPage({super.key});

  Future<void> _continueWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      final authService = AuthService();
      final success = await authService.signInWithGoogle();

      if (!success || !context.mounted) return;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final hiveService = ref.read(onboardingServiceProvider);
      final guestLevel = await hiveService.getGuestLanguageLevel();
      final guestVariant = await hiveService.getGuestEnglishVariant();
      final hasGuestData = guestLevel != null || guestVariant != null;

      // เช็คจาก users table โดยตรง
      final userData = await client
          .from('users')
          .select('id, language_level, display_name')
          .eq('id', userId)
          .maybeSingle();

      // มี language_level = existing user ที่ setup แล้ว
      final isExistingUser =
          userData != null && userData['language_level'] != null;

      if (!context.mounted) return;

      if (isExistingUser && hasGuestData) {
        // มี account แล้ว และมีข้อมูล guest → ถาม dialog
        final useGuestData = await _showDataChoiceDialog(context);
        if (useGuestData == null) {
          // กด Cancel → sign out แล้วกลับ
          await client.auth.signOut();
          return;
        }
        if (useGuestData == true && context.mounted) {
          await authService.updateUserPreferences(
            userId: userId,
            email: client.auth.currentUser?.email ?? '',
            languageLevel: guestLevel,
            englishVariant: guestVariant ?? 'US',
          );
        }
      } else if (!isExistingUser && hasGuestData) {
        // user ใหม่ มีข้อมูล guest → บันทึกข้อมูล guest ลง Supabase
        await authService.updateUserPreferences(
          userId: userId,
          email: client.auth.currentUser?.email ?? '',
          languageLevel: guestLevel,
          englishVariant: guestVariant ?? 'US',
        );
      }

      if (!context.mounted) return;

      await hiveService.setOnboardingCompleted(true);
      await hiveService.setGuestMode(false);

      if (!context.mounted) return;

      // เช็ค display name เฉพาะ user ใหม่เท่านั้น
      final hasDisplayName =
          client.auth.currentUser?.userMetadata?['display_name'] != null ||
          (userData?['display_name'] != null);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              MainNavigationScreen(showDisplayNamePrompt: !hasDisplayName),
        ),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<bool?> _showDataChoiceDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Found your existing account!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'We found an account with this email. Would you like to keep your old settings or update with your latest guest preferences?',
            ),
            SizedBox(height: 12),
            Text(
              '⚠️ Note: Updating will overwrite your old settings.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          // ✅ เพิ่มปุ่ม Cancel
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Old'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use Guest Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.person_add_rounded,
                    size: 60,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Create an account',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Your guest preferences will be saved',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'If you already have an account, we\'ll ask which data to keep.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  OutlinedButton.icon(
                    onPressed: () => _continueWithGoogle(context, ref),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.g_mobiledata, size: 20),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 12),

                  FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EmailLoginPage(
                            isGuestCreatingAccount: true,
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Continue with Email'),
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
