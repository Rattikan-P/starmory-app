import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_page.dart';
import 'main_navigation.dart';
import '../../constants/app_defaults.dart';

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
      color: Color(0xFF60a5fa), // Blue
    ),
    EnglishVariant(
      code: 'UK',
      name: 'British English',
      flag: '🇬🇧',
      description: 'United Kingdom',
      color: Color(0xFFa78bfa), // Purple
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE8F4FD),
                    Color(0xFFF5EEF8),
                    Color(0xFFFDF4E8),
                  ],
                ),
              ),
            ),
          ),

          // Galaxy blobs
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFC4B5FD).withValues(alpha: 0.5),
                    const Color(0x00C4B5FD),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF93C5FD).withValues(alpha: 0.5),
                    const Color(0x0093C5FD),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      // Back button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Color(0xFF1f2937), size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Spacer(),
                      // Progress bar - hide when editing
                      if (!isEditing)
                      Flexible(
                        child: SizedBox(
                          width: 200,
                          height: 6,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Stack(
                              children: [
                                Container(
                                  color: const Color(0xFFc4b5fd).withValues(alpha: 0.3),
                                ),
                                FractionallySizedBox(
                                  widthFactor: 1.0, // 100% for step 2 of 2
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF8b7cf6), Color(0xFF7c6ff5)],
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8b7cf6).withValues(alpha: 0.4),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Skip button
                      if (!isEditing)
                        TextButton(
                          onPressed: () => _skip(context, ref),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF8b5cf6),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.lexend(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 48, height: 48),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),

                            // Title
                            Text(
                              isEditing
                                  ? 'Change your preference'
                                  : 'Which English do you prefer?',
                              style: GoogleFonts.lexend(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1f2937),
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),

                            // Subtitle
                            Text(
                              isEditing
                                  ? 'Choose English variant'
                                  : 'This helps us create your learning experience',
                              style: GoogleFonts.lexend(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF6b7280),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            // Variant cards - consistent with language page
                            ...variants.map((variant) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildVariantCard(context, ref, variant),
                              );
                            }),

                            const SizedBox(height: 80), // Extra space for bottom note
                          ],
                        ),
                      ),
                      // Bottom note - fixed at bottom
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: !isEditing
                            ? Text(
                                "Don't worry, you can change this anytime",
                                style: GoogleFonts.lexend(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF9ca3af),
                                ),
                                textAlign: TextAlign.center,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantCard(BuildContext context, WidgetRef ref, EnglishVariant variant) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectVariant(context, ref, variant.code),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Flag with colored background - consistent with language page
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: variant.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      variant.flag,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variant.name,
                        style: GoogleFonts.lexend(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1f2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        variant.description,
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6b7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow icon - consistent
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFf3f4f6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Color(0xFF9ca3af),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _skip(BuildContext context, WidgetRef ref) {
    _selectVariant(context, ref, AppDefaults.defaultEnglishVariant);
  }

  Future<void> _selectVariant(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    final preferenceService = ref.read(onboardingServiceProvider);
    await preferenceService.setGuestEnglishVariant(code);

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
        Navigator.of(context).pop(true);
      }
      return;
    }

    if (isGuest) {
      await preferenceService.setGuestMode(true);
      await preferenceService.setOnboardingCompleted(true);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } else {
      final client = Supabase.instance.client;
      final userId = client.auth.currentSession?.user.id;
      if (userId != null) {
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'language_level': languageLevel ?? AppDefaults.defaultLanguageLevel,
              'english_variant': code,
            },
          ),
        );
        await client.from('users').upsert({
          'id': userId,
          'language_level': languageLevel ?? AppDefaults.defaultLanguageLevel,
          'english_variant': code,
          'onboarding_completed': true,
        });
      }

      await preferenceService.setOnboardingCompleted(true);
      await preferenceService.setGuestMode(false);

      if (context.mounted) {
        // Pop back to root and then push home screen to prevent flashing
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const MainNavigationScreen(),
          ),
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
  final Color color;

  const EnglishVariant({
    required this.code,
    required this.name,
    required this.flag,
    required this.description,
    required this.color,
  });
}
