import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_page.dart';
import 'main_navigation.dart';
import '../../constants/app_defaults.dart';
import '../../data/services/auth_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../data/models/user_model.dart';
import '../providers/providers.dart';

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 64,
                    height: 36,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF34343B), size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                  if (!widget.isEditing)
                    SizedBox(
                      width: 72,
                      height: 6,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Stack(
                            children: [
                              Container(
                                color: const Color(0xFFc4b5fd)
                                    .withValues(alpha: 0.3),
                              ),
                              FractionallySizedBox(
                                widthFactor: 1.0, // 100% for step 2 of 2
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8b7cf6),
                                        Color(0xFF7c6ff5)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF8b7cf6)
                                            .withValues(alpha: 0.4),
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
                  SizedBox(
                    width: 64,
                    height: 36,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: widget.isEditing
                          ? const SizedBox.shrink()
                          : TextButton(
                              onPressed: () => _skip(context, ref),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF8b5cf6),
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Skip',
                                style: GoogleFonts.lexend(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Content
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        Image.asset(
                          'assets/images/mascots/variant_mascot.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          widget.isEditing
                              ? 'Change your preference'
                              : 'Which English do you prefer?',
                          style: GoogleFonts.lexend(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1f2937),
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),

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
                        const SizedBox(height: 28),

                        // Variant cards - consistent with language page
                        ...variants.map((variant) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildVariantCard(context, ref, variant),
                          );
                        }),

                        const SizedBox(
                            height: 80), // Extra space for bottom note
                      ],
                    ),
                  ),
                  // Bottom note - fixed at bottom
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: !widget.isEditing
                        ? Text(
                            "Don't worry, you can change this anytime",
                            style: GoogleFonts.lexend(
                              fontSize: 11,
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
    );
  }

  Widget _buildVariantCard(
      BuildContext context, WidgetRef ref, EnglishVariant variant) {
    final bool isSelected = _selectedVariant == variant.code;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(
                color: variant.color.withValues(alpha: 0.8), width: 1.5)
            : Border.all(color: const Color(0xFFF0F0F4), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectVariant(context, ref, variant.code),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: [
                // Flag with colored background - consistent with language page
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: variant.color.withValues(
                        alpha: isSelected ? 0.3 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      variant.flag,
                      style: const TextStyle(fontSize: 25),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variant.name,
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1f2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        variant.description,
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6b7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // Continue arrow
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? variant.color.withValues(alpha: 0.16)
                        : const Color(0xFFF1F2F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_rounded
                        : Icons.chevron_right_rounded,
                    size: 20,
                    color: isSelected
                        ? variant.color
                        : const Color(0xFF9CA3AF),
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
    try {
      final userNotifier = ref.read(userStateProvider.notifier);
      await userNotifier.updatePreferences({'languageVariant': code});
      debugPrint('✅ Updated english variant: $code');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Failed to update english variant: $e');
      if (mounted) {
        SnackBarHelper.error(
            context, 'Failed to update preference. Please try again.');
      }
    }
  }

  /// Flow 2: Guest user completing onboarding
  /// - Saves preferences locally
  /// - Updates UserModel with selected preferences
  /// - Navigates to Home
  Future<void> _handleGuestFlow(WidgetRef ref) async {
    final preferenceService = ref.read(onboardingServiceProvider);
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
      final updatedUser =
          currentUser.copyWith(preferences: selectedPreferences);
      await userNotifier.updateUser(updatedUser);
      debugPrint(
          '✅ Updated UserModel with guest preferences: level=${widget.languageLevel}, variant=$_selectedVariant');
    } else {
      // User doesn't exist yet, create guest user WITH selected preferences
      debugPrint(
          '⚠️ No UserModel found, creating guest with selected preferences');
      final guestUser =
          UserModel.createGuest().copyWith(preferences: selectedPreferences);
      await userNotifier.updateUser(guestUser);
      // Save initial quota backup for device-based trial
      final hiveService = ref.read(hiveServiceProvider);
      await hiveService.saveGuestQuotaBackup(guestUser.quotaManager);
      debugPrint(
          '✅ Created and saved guest user with preferences: level=${widget.languageLevel}, variant=$_selectedVariant');
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
    String? displayName =
        user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];

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
          languageLevel:
              widget.languageLevel ?? AppDefaults.defaultLanguageLevel,
          englishVariant: code,
          termsVersion: preferenceService.getCurrentTermsVersion(),
        );

        // Also mark onboarding as completed in database
        await client
            .from('users')
            .update({'onboarding_completed': true}).eq('id', userId);
      } catch (e) {
        if (mounted) {
          _handleSyncFailure(context);
        }
        return;
      }
    }

    await preferenceService.clearLocalPreferences();
    await preferenceService.setOnboardingCompleted(true);
    // Note: setGuestMode removed - UserModel.isGuest reflects actual auth state

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
              'language_level':
                  widget.languageLevel ?? AppDefaults.defaultLanguageLevel,
              'english_variant': code,
            },
          ),
        );
        // ⭐ IMPORTANT: Refresh session to get updated metadata
        await client.auth.refreshSession();
        await client.from('users').upsert({
          'id': userId,
          'language_level':
              widget.languageLevel ?? AppDefaults.defaultLanguageLevel,
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
    // Note: setGuestMode removed - UserModel.isGuest reflects actual auth state

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
