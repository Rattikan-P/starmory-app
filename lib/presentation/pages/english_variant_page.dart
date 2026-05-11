import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_page.dart';
import 'main_navigation.dart';

class EnglishVariantPage extends ConsumerWidget {
  final bool isGuest;
  final bool isEditing;
  final bool isInitialSetup;
  final String? languageLevel;
  final bool forceSelection;
  final bool returnAfterSelection;

  const EnglishVariantPage({
    super.key,
    this.isGuest = false,
    this.isEditing = false,
    this.isInitialSetup = false,
    this.languageLevel,
    this.forceSelection = false,
    this.returnAfterSelection = false,
  });

  static const List<EnglishVariant> variants = [
    EnglishVariant(
      code: 'US',
      name: 'American English',
      flag: '🇺🇸',
      description: 'United States',
    ),
    EnglishVariant(
      code: 'UK',
      name: 'British English',
      flag: '🇬🇧',
      description: 'United Kingdom',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: isEditing
            ? null
            : [
                TextButton(
                  onPressed: () => _skip(context, ref),
                  child: const Text('Skip'),
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing
                        ? 'Change your preference'
                        : 'Select your preference',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEditing
                        ? 'Choose English variant'
                        : 'Which English do you prefer?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: variants.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final variant = variants[index];
                  return Card(
                    elevation: 0,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      leading: Text(
                        variant.flag,
                        style: const TextStyle(fontSize: 32),
                      ),
                      title: Text(
                        variant.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(variant.description),
                      onTap: () => _selectVariant(context, ref, variant.code),
                    ),
                  );
                },
              ),
            ),

            if (!isEditing)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You can change this later in settings',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _skip(BuildContext context, WidgetRef ref) {
    _selectVariant(context, ref, 'US');
  }

  Future<void> _selectVariant(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    final hiveService = ref.read(onboardingServiceProvider);
    await hiveService.setGuestEnglishVariant(code);

    if (isEditing) {
      if (!isGuest) {
        final client = Supabase.instance.client;
        final userId = client.auth.currentSession?.user.id;
        if (userId != null) {
          await client.auth.updateUser(
            UserAttributes(data: {'english_variant': code}),
          );
          await client
              .from('users')
              .update({'english_variant': code})
              .eq('id', userId);
        }
      }
      if (context.mounted) Navigator.pop(context);
      return;
    }

    if (returnAfterSelection) {
      if (context.mounted) {
        Navigator.of(context).pop(true); // pop กลับไป LanguageSelectionPage
      }
      return;
    }

    if (isGuest) {
      await hiveService.setGuestMode(true);
      await hiveService.setOnboardingCompleted(true);
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } else {
      // ✅ ทั้ง Google และ Email
      final client = Supabase.instance.client;
      final userId = client.auth.currentSession?.user.id;
      if (userId != null) {
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'language_level': languageLevel ?? 'B1',
              'english_variant': code,
            },
          ),
        );
        await client.from('users').upsert({
          'id': userId,
          'language_level': languageLevel ?? 'B1',
          'english_variant': code,
          'onboarding_completed': true,
        });
      }

      // ✅ บอกว่า onboarding เสร็จแล้ว
      await hiveService.setOnboardingCompleted(true);
      await hiveService.setGuestMode(false);

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                const MainNavigationScreen(showDisplayNamePrompt: true),
          ),
          (route) => false,
        );
      }
    }
  }
}

class EnglishVariant {
  final String code;
  final String name;
  final String flag;
  final String description;

  const EnglishVariant({
    required this.code,
    required this.name,
    required this.flag,
    required this.description,
  });
}
