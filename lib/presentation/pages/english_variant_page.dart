import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/galaxy_screen_background.dart';
import 'onboarding_page.dart';
import 'main_navigation.dart';
import '../../constants/app_defaults.dart';
import '../../data/services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../data/models/user_model.dart';
import '../providers/providers.dart';
import '../providers/auth_provider.dart' as auth;

class EnglishVariantPage extends ConsumerStatefulWidget {
  final bool isGuest;
  final bool isEditing;
  final bool isInitialSetup;
  final String? languageLevel;
  final bool forceSelection;
  final bool returnAfterSelection;
  final String? currentVariant;

  const EnglishVariantPage({
    super.key,
    this.isGuest = false,
    this.isEditing = false,
    this.isInitialSetup = false,
    this.languageLevel,
    this.forceSelection = false,
    this.returnAfterSelection = false,
    this.currentVariant,
  });

  @override
  ConsumerState<EnglishVariantPage> createState() => _EnglishVariantPageState();
}

class _EnglishVariantPageState extends ConsumerState<EnglishVariantPage> {
  String? _selectedVariant;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingGuestVariant();
    });
  }

  Future<void> _checkExistingGuestVariant() async {
    // For editing mode, use currentVariant if provided
    if (widget.isEditing) {
      if (widget.currentVariant != null && mounted) {
        setState(() {
          _selectedVariant = widget.currentVariant;
        });
      }
      return;
    }

    if (widget.forceSelection || widget.isInitialSetup) return;

    // Load from UserModel instead of SharedPreferences
    final currentUser = ref.read(userStateProvider).user;
    if (currentUser != null && mounted) {
      setState(() {
        _selectedVariant = currentUser.englishVariant;
      });
    }
  }

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: GalaxyScreenBackground(
        child: SafeArea(
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
                      if (!widget.isEditing)
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
                      if (!widget.isEditing)
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
                              widget.isEditing
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
                              widget.isEditing
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
                        child: !widget.isEditing
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
        ),
    );
  }

  Widget _buildVariantCard(BuildContext context, WidgetRef ref, EnglishVariant variant) {
    final bool isSelected = _selectedVariant == variant.code;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: variant.color, width: 2)
            : null,
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
                    color: variant.color.withValues(alpha: isSelected ? 0.3 : 0.15),
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

                // Arrow icon or Checkmark - consistent with language page
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? variant.color.withValues(alpha: 0.15)
                        : const Color(0xFFf3f4f6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: isSelected ? 20 : 16,
                    color: isSelected
                        ? variant.color
                        : const Color(0xFF9ca3af),
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

  /// Handles sync failure - local save already succeeded, just notify user
  void _handleSyncFailure(BuildContext context) {
    if (mounted) {
      SnackBarHelper.error(context, 'Failed to sync. Changes saved locally.');
      setState(() => _selectedVariant = null);
    }
  }

  /// Flow 1: User editing preferences from Profile page
  /// Uses shared updatePreferences method (works for both Guest and Cloud)
  Future<void> _handleEditingFlow(String code) async {
    final userNotifier = ref.read(userStateProvider.notifier);
    await userNotifier.updatePreferences({'languageVariant': code});
    debugPrint('✅ Updated english variant: $code');
    if (mounted) Navigator.pop(context);
  }

  /// Flow 2: Guest user completing onboarding
  /// - Saves preferences locally
  /// - Updates UserModel with selected preferences
  /// - Navigates to Home
  Future<void> _handleGuestFlow(WidgetRef ref) async {
    final preferenceService = ref.read(onboardingServiceProvider);
    await preferenceService.setGuestMode(true);
    await preferenceService.setOnboardingCompleted(true);

    // Update the UserModel with the selected preferences
    // This ensures the guest user has their selected preferences immediately
    final userNotifier = ref.read(userStateProvider.notifier);
    final currentUser = ref.read(userStateProvider).user;

    final selectedPreferences = {
      'defaultCefrLevel': widget.languageLevel,
      'languageVariant': _selectedVariant ?? AppDefaults.defaultEnglishVariant,
    };

    if (currentUser != null) {
      // User exists, update with selected preferences
      final updatedUser = currentUser.copyWith(preferences: selectedPreferences);
      await userNotifier.updateUser(updatedUser);
      debugPrint('✅ Updated UserModel with guest preferences: level=${widget.languageLevel}, variant=$_selectedVariant');
    } else {
      // User doesn't exist yet, create guest user WITH selected preferences
      debugPrint('⚠️ No UserModel found, creating guest with selected preferences');
      final guestUser = UserModel.createGuest().copyWith(preferences: selectedPreferences);
      await userNotifier.updateUser(guestUser);
      debugPrint('✅ Created and saved guest user with preferences: level=${widget.languageLevel}, variant=$_selectedVariant');
    }

    if (!mounted) return;
    SnackBarHelper.success(context, AlertMessages.welcomeToApp);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  /// Flow 3: New user after OTP/Google authentication (initial setup)
  /// - Saves all preferences to Supabase
  /// - Extracts display name from Google metadata or email
  /// - Navigates to Home
  Future<void> _handleInitialSetupFlow(String code, WidgetRef ref) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentSession?.user.id;
    final userEmail = client.auth.currentSession?.user.email;
    final preferenceService = ref.read(onboardingServiceProvider);

    // Get display name from Google metadata (if available), otherwise fallback to email
    final user = client.auth.currentUser;
    String? displayName = user?.userMetadata?['full_name']
                        ?? user?.userMetadata?['name'];

    // Fallback: extract name from email (e.g., john.smith@gmail.com → John Smith)
    if (displayName == null && userEmail != null) {
      final localPart = userEmail.split('@').first;
      displayName = localPart
          .split(RegExp(r'[._]'))
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
    }

    if (userId != null) {
      try {
        final authService = AuthService();
        await authService.updateUserPreferences(
          userId: userId,
          email: userEmail ?? '',
          displayName: displayName,
          languageLevel: widget.languageLevel ?? AppDefaults.defaultLanguageLevel,
          englishVariant: code,
          termsVersion: preferenceService.getCurrentTermsVersion(),
        );

        // Also mark onboarding as completed in database
        await client
            .from('users')
            .update({'onboarding_completed': true})
            .eq('id', userId);
      } catch (e) {
        if (mounted) {
          _handleSyncFailure(context);
        }
        return;
      }
    }

    await preferenceService.clearLocalPreferences();
    await preferenceService.setOnboardingCompleted(true);
    await preferenceService.setGuestMode(false);

    if (!mounted) return;
    SnackBarHelper.success(context, 'Welcome to Starmory!');
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  /// Flow 4: Return to previous screen (for language selection page)
  void _handleReturnAfterSelection() {
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Flow 5: Regular onboarding flow (logged-in user)
  /// - Updates language_level and english_variant in Supabase
  /// - Navigates to Home
  Future<void> _handleOnboardingFlow(String code, WidgetRef ref) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentSession?.user.id;
    final preferenceService = ref.read(onboardingServiceProvider);

    if (userId != null) {
      try {
        await client.auth.updateUser(
          UserAttributes(
            data: {
              'language_level': widget.languageLevel ?? AppDefaults.defaultLanguageLevel,
              'english_variant': code,
            },
          ),
        );
        // ⭐ IMPORTANT: Refresh session to get updated metadata
        await client.auth.refreshSession();
        await client.from('users').upsert({
          'id': userId,
          'language_level': widget.languageLevel ?? AppDefaults.defaultLanguageLevel,
          'english_variant': code,
          'onboarding_completed': true,
        });
      } catch (e) {
        if (mounted) {
          _handleSyncFailure(context);
        }
        return;
      }
    }

    await preferenceService.setOnboardingCompleted(true);
    await preferenceService.setGuestMode(false);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _selectVariant(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    setState(() {
      _selectedVariant = code;
    });

    // Route to appropriate flow based on widget flags
    if (widget.isEditing) {
      await _handleEditingFlow(code);
    } else if (widget.isGuest) {
      await _handleGuestFlow(ref);
    } else if (widget.isInitialSetup) {
      await _handleInitialSetupFlow(code, ref);
    } else if (widget.returnAfterSelection) {
      _handleReturnAfterSelection();
    } else {
      await _handleOnboardingFlow(code, ref);
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
