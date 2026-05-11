import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/hive_service.dart';
import '../main_navigation.dart';
import '../onboarding_page.dart';
import '../language_selection_page.dart';
import 'email_login_page.dart';

class AccountMethodPage extends ConsumerWidget {
  const AccountMethodPage({super.key});

  Future<void> _continueWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      final authService = AuthService();
      // force ถาม account ใหม่ตอน guest สร้าง account
      final success = await authService.signInWithGoogle(
        forceAccountSelection: true,
      );

      if (!success || !context.mounted) return;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final hiveService = ref.read(onboardingServiceProvider);
      final guestLevel = await hiveService.getGuestLanguageLevel();
      final guestVariant = await hiveService.getGuestEnglishVariant();
      final hasGuestData = guestLevel != null || guestVariant != null;

      final userData = await client
          .from('users')
          .select('id, language_level, onboarding_completed, display_name')
          .eq('id', userId)
          .maybeSingle();

      final isNewUser =
          userData == null || userData['onboarding_completed'] != true;

      if (!context.mounted) return;

      if (isNewUser) {
        //  New user
        String? finalLevel = guestLevel;
        String? finalVariant = guestVariant;

        if (!hasGuestData) {
          // ไม่มีข้อมูล guest → ถาม level/variant
          // navigate ไป LanguageSelectionPage แล้วรอผล
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const LanguageSelectionPage(
                isInitialSetup: true,
                returnAfterSelection: true,
                forceSelection: true,
              ),
            ),
          );
          if (!context.mounted || result != true) return;
          finalLevel = await hiveService.getGuestLanguageLevel();
          finalVariant = await hiveService.getGuestEnglishVariant();
        }

        // บันทึกข้อมูล
        await authService.updateUserPreferences(
          userId: userId,
          email: client.auth.currentUser?.email ?? '',
          languageLevel: finalLevel ?? 'B1',
          englishVariant: finalVariant ?? 'US',
        );

        // set onboarding_completed
        await client
            .from('users')
            .update({'onboarding_completed': true})
            .eq('id', userId);
      } else {
        // Existing user → ใช้ข้อมูลเดิมไว้เลย ไม่ overwrite
        // TODO: อาจเพิ่ม merge strategy ในอนาคตเมื่อมี feature คำศัพท์
        // if (hasGuestData) {
        //   await authService.updateUserPreferences(
        //     userId: userId,
        //     email: client.auth.currentUser?.email ?? '',
        //     languageLevel: guestLevel,
        //     englishVariant: guestVariant ?? 'US',
        //   );
        // }
      }

      if (!context.mounted) return;

      await hiveService.setOnboardingCompleted(true);
      await hiveService.setGuestMode(false);

      if (!context.mounted) return;

      // ถาม display name เฉพาะ new user เท่านั้น
      final hasDisplayName =
          client.auth.currentUser?.userMetadata?['display_name'] != null ||
          userData?['display_name'] != null;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainNavigationScreen(
            showDisplayNamePrompt: isNewUser && !hasDisplayName,
          ),
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
                            'If you already have an account, your current preferences will be applied.',
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
