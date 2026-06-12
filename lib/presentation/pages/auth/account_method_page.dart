import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/snackbar_helper.dart';
import '../../widgets/galaxy_screen_background.dart';
import '../main_navigation.dart';
import '../onboarding_page.dart';
import '../language_selection_page.dart';
import '../privacy_policy_page.dart';
import '../terms_of_service_page.dart';
import 'otp_verification_page.dart' show OtpVerificationPage;
import '../../../constants/app_defaults.dart';
import '../../../presentation/providers/providers.dart' show hiveServiceProvider, vocabularySyncServiceProvider, userStateProvider;
import '../../../presentation/providers/streak_provider.dart' show streakProvider;

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AccountMethodPage extends ConsumerStatefulWidget {
  const AccountMethodPage({super.key});

  @override
  ConsumerState<AccountMethodPage> createState() => _AccountMethodPageState();
}

class _AccountMethodPageState extends ConsumerState<AccountMethodPage> {
  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _isEmailLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle(BuildContext context) async {
    try {
      final preferenceService = ref.read(onboardingServiceProvider);
      await preferenceService.init();

      // ⭐ IMPORTANT: Read guest preferences BEFORE sign in
      // Otherwise, auth state change will convert guest → registered before we can read
      final currentUserBeforeAuth = ref.read(userStateProvider).user;
      final guestLevel = currentUserBeforeAuth?.languageLevel;
      final guestVariant = currentUserBeforeAuth?.englishVariant;

      // Check if user has non-default preferences (has guest data)
      final hasGuestData = currentUserBeforeAuth != null &&
          (currentUserBeforeAuth.languageLevel != AppDefaults.defaultLanguageLevel ||
           currentUserBeforeAuth.englishVariant != AppDefaults.defaultEnglishVariant);

      debugPrint('📝 Guest preferences captured BEFORE auth: level=$guestLevel, variant=$guestVariant, hasData=$hasGuestData');

      final authService = AuthService();
      // force ถาม account ใหม่ตอน guest สร้าง account
      final success = await authService.signInWithGoogle(
        forceAccountSelection: true,
      );

      if (!success) {
        if (context.mounted) {
          SnackBarHelper.error(context, AlertMessages.loginFailed);
        }
        return;
      }

      if (!context.mounted) return;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (context.mounted) {
          SnackBarHelper.error(context, AlertMessages.loginFailed);
        }
        return;
      }

      // Get display name from Google metadata (if available), otherwise fallback to email
      final user = client.auth.currentUser;
      final userEmail = user?.email;
      String? displayName = user?.userMetadata?['full_name']
                          ?? user?.userMetadata?['name'];

      // Fallback: extract name from email (e.g., john.smith@gmail.com → John Smith)
      if (displayName == null && userEmail != null) {
        final localPart = userEmail.split('@').first;
        // Convert john.smith or john_smith → John Smith
        displayName = localPart
            .split(RegExp(r'[._]'))
            .where((part) => part.isNotEmpty)
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ');
      }

      // Auto-accept terms
      await preferenceService.setTermsVersion(preferenceService.getCurrentTermsVersion());

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
          // EnglishVariantPage จะจัดการทุกอย่าง (บันทึกข้อมูล, navigate) เมื่อ isInitialSetup
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LanguageSelectionPage(
                isGuest: false,
                isInitialSetup: true,
                returnAfterSelection: false,
              ),
            ),
          );
          // Context will be unmounted here since EnglishVariantPage handles full navigation
          return;
        }

        // บันทึกข้อมูล (Step 18)
        try {
          await authService.updateUserPreferences(
            userId: userId,
            email: client.auth.currentUser?.email ?? '',
            displayName: displayName,
            languageLevel: finalLevel ?? AppDefaults.defaultLanguageLevel,
            englishVariant: finalVariant ?? AppDefaults.defaultEnglishVariant,
            termsVersion: preferenceService.getCurrentTermsVersion(),
          );

          // Upload guest vocabulary to new user's cloud storage
          final hiveService = ref.read(hiveServiceProvider);
          final vocabSyncService = ref.read(vocabularySyncServiceProvider);
          try {
            final localVocabs = await hiveService.getAllVocabulary();
            if (localVocabs.isNotEmpty) {
              final uploadedCount = await vocabSyncService.batchUpload(localVocabs);
              // Only clear local vocabularies after successful upload of ALL items
              if (uploadedCount == localVocabs.length) {
                await hiveService.clearAllVocabulary();
              } else {
                // Partial upload failed - keep local data for retry
                print('⚠️ [Google Login] Partial upload: $uploadedCount/${localVocabs.length}');
              }
            }
          } catch (e) {
            // Upload failed - local vocabularies preserved
            print('❌ [Google Login] Upload failed: $e');
          }

          // Migrate guest streak to cloud
          try {
            print('🔄 [Google Login] Migrating guest streak...');
            final streakNotifier = ref.read(streakProvider.notifier);
            final migrated = await streakNotifier.migrateGuestStreakToCloud();
            if (migrated) {
              print('✅ [Google Login] Streak migrated successfully');
            } else {
              print('ℹ️ [Google Login] No streak data to migrate');
            }
          } catch (e) {
            // Streak migration failed - continue with login
            print('⚠️ [Google Login] Streak migration failed: $e');
          }

          // set onboarding_completed
          await client
              .from('users')
              .update({'onboarding_completed': true})
              .eq('id', userId);
        } catch (e) {
          // E3: Service unavailable when saving preferences
          if (context.mounted) {
            SnackBarHelper.error(context, AlertMessages.serviceUnavailable);
          }
          return; // Stay on page, user can retry
        }
      } else {
        // Existing user → เช็คว่ามี guest data ไหม
        if (hasGuestData) {
          // แสดง dialog ถามว่าต้องการ merge ไหม
          if (!context.mounted) return;
          final shouldMerge = await _showMergeDialog(context, guestLevel, guestVariant);

          if (shouldMerge == true) {
            // User เลือก merge → อัปเดต preferences เป็นของ guest
            try {
              final hiveService = ref.read(hiveServiceProvider);
              final vocabSyncService = ref.read(vocabularySyncServiceProvider);
              await authService.mergeGuestPreferences(
                userId: userId,
                email: client.auth.currentUser?.email ?? '',
                languageLevel: guestLevel,
                englishVariant: guestVariant,
                hiveService: hiveService,
                vocabularySyncService: vocabSyncService,
              );

              // Refresh UserModel with merged preferences from Supabase
              final userNotifier = ref.read(userStateProvider.notifier);
              final currentUser = ref.read(userStateProvider).user;
              if (currentUser != null) {
                // Create updated user with merged preferences from Supabase metadata
                final supabaseUser = client.auth.currentUser;
                final mergedLevel = supabaseUser?.userMetadata?["language_level"] as String?;
                final mergedVariant = supabaseUser?.userMetadata?["english_variant"] as String?;

                final updatedUser = currentUser.copyWith(
                  preferences: {
                    ...currentUser.preferences,
                    "defaultCefrLevel": mergedLevel ?? currentUser.preferences["defaultCefrLevel"],
                    "languageVariant": mergedVariant ?? currentUser.preferences["languageVariant"],
                  },
                );
                await userNotifier.updateUser(updatedUser);
                print("✅ [Google Login] Refreshed UserModel with merged preferences: level=$mergedLevel, variant=$mergedVariant");
              }
            } catch (e) {
              // E3: Service unavailable when merging preferences
              if (context.mounted) {
                SnackBarHelper.error(context, AlertMessages.serviceUnavailable);
              }
              return; // Stay on page, user can retry
            }
          }

          // ถ้า shouldMerge == false → ใช้ข้อมูลเดิม preferences และ vocab
          // แต่ STREAK ยัง migrate ให้ทั้ง 2 กรณี (เพราะคือความพยายามล่าสุด)
          try {
            print('🔄 [Google Login] Migrating guest streak...');
            final streakNotifier = ref.read(streakProvider.notifier);
            final migrated = await streakNotifier.migrateGuestStreakToCloud();
            if (migrated) {
              print('✅ [Google Login] Streak migrated successfully (guest: $shouldMerge)');
            } else {
              print('ℹ️ [Google Login] No streak data to migrate');
            }
          } catch (e) {
            // Streak migration failed - continue with login
            print('⚠️ [Google Login] Streak migration failed: $e');
          }
        }
      }

      if (!context.mounted) return;

      await preferenceService.setOnboardingCompleted(true);
      await preferenceService.setGuestMode(false);

      // Auto sync local vocabularies to cloud (for existing users with unsynced data)
      // Skip for new users who just uploaded (already cleared)
      if (!isNewUser) {
        try {
          print('🔄 [Google Login] Starting auto sync...');
          final hiveService = ref.read(hiveServiceProvider);
          final vocabSyncService = ref.read(vocabularySyncServiceProvider);
          final localVocabs = await hiveService.getAllVocabulary();

          print('📦 [Google Login] Found ${localVocabs.length} local vocabularies');

          if (localVocabs.isNotEmpty) {
            // Use mergeWithCloud to avoid duplicates
            print('☁️ [Google Login] Merging with cloud...');
            final syncedVocabs = await vocabSyncService.mergeWithCloud(localVocabs);
            // Update local storage with merged vocabularies
            await hiveService.clearAllVocabulary();
            for (final vocab in syncedVocabs) {
              await hiveService.saveVocabulary(vocab);
            }
            print('✅ [Google Login] Sync complete! Total vocabularies: ${syncedVocabs.length}');
          } else {
            print('ℹ️ [Google Login] No local vocabularies to sync');
          }
        } catch (e) {
          print('❌ [Google Login] Sync failed: $e');
          // Sync failed - continue with login (local vocabularies still available)
        }
      } else {
        print('ℹ️ [Google Login] Skipping sync (new user)');
      }

      if (!context.mounted) return;

      // Show different message for existing vs new users
      if (!isNewUser) {
        SnackBarHelper.success(context, AlertMessages.welcomeBack);
      } else {
        SnackBarHelper.success(context, AlertMessages.welcomeToApp);
      }

      // Wait a bit so user can see the success message
      await Future.delayed(const Duration(milliseconds: 500));

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, AlertMessages.loginFailed);
      }
    }
  }

  Future<void> _continueWithEmail(BuildContext context) async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isEmailLoading = true);

    try {
      final email = _emailController.text.trim();

      // ⭐ IMPORTANT: Read guest preferences BEFORE send OTP
      // Capture early to ensure we have guest data even if state changes later
      final currentUser = ref.read(userStateProvider).user;
      final guestLevel = currentUser?.languageLevel;
      final guestVariant = currentUser?.englishVariant;

      debugPrint('📝 Guest preferences captured for email flow: level=$guestLevel, variant=$guestVariant');

      // Send OTP first, then navigate
      final authService = ref.read(authServiceProvider);
      await authService.sendOtp(email);

      if (!context.mounted) return;
      SnackBarHelper.success(context, 'OTP sent to $email');

      // Navigate to OTP page after successful send (with guest preferences)
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            email: email,
            displayName: null,
            languageLevel: guestLevel,
            englishVariant: guestVariant,
            isGuestCreatingAccount: true,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, AlertMessages.otpSendFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isEmailLoading = false);
      }
    }
  }

  Future<bool?> _showMergeDialog(
    BuildContext context,
    String? guestLevel,
    String? guestVariant,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFf8f9ff),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8b5cf6).withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Icon with glow effect
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFf472b6), // Soft pink
                      Color(0xFF60a5fa), // Soft blue
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFf472b6).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.merge_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Account already exists',
                style: GoogleFonts.lexend(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'This email already has an account.',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6b7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Guest preferences card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFf3f4f6),
                      const Color(0xFFe8f0ff).withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF8b5cf6).withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8b5cf6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: Color(0xFF8b5cf6),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Your guest preferences',
                          style: GoogleFonts.lexend(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8b5cf6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (guestLevel != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8b5cf6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Language Level: $guestLevel',
                                style: GoogleFonts.lexend(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF4b5563),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (guestVariant != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8b5cf6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'English Variant: $guestVariant',
                                style: GoogleFonts.lexend(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF4b5563),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Question
              Text(
                'Would you like to add your guest data to this account?',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6b7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9ca3af),
                          side: BorderSide(
                            color: const Color(0xFF9ca3af).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Keep old',
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF60a5fa),
                              Color(0xFFa78bfa),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFa78bfa).withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, true),
                            borderRadius: BorderRadius.circular(14),
                            child: const Center(
                              child: Text(
                                'Add guest data',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GalaxyScreenBackground(
        child: SafeArea(
          child: Stack(
                children: [
                  // Back button - outside card
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF1f2937)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  // Card content
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 80, bottom: 24, left: 24, right: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [

                    // Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFf472b6), // Soft pink
                            Color(0xFF60a5fa), // Soft blue
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFf472b6).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'Create an account',
                      style: GoogleFonts.lexend(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1f2937),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),

                    Text(
                      'Continue with your progress',
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF9ca3af),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Email input with continue button
                    Form(
                      key: _emailFormKey,
                      child: Column(
                        children: [
                          // Email input field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            style: GoogleFonts.lexend(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'your@email.com',
                              hintStyle: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF9ca3af),
                              ),
                              prefixIcon: const Icon(Icons.email_outlined, size: 20, color: Color(0xFF9ca3af)),
                              filled: true,
                              fillColor: const Color(0xFFf3f4f6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFc4b5fd), width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFef4444), width: 1),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFef4444), width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                            ),
                            onFieldSubmitted: (_) => _continueWithEmail(context),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return AlertMessages.emailRequired;
                              }
                              if (!SnackBarHelper.isValidEmail(value)) {
                                return AlertMessages.invalidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Email Continue button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF60a5fa), // soft blue
                                    Color(0xFF818cf8), // soft indigo
                                    Color(0xFFa78bfa), // soft violet
                                    Color(0xFFc084fc), // soft purple
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFa78bfa).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isEmailLoading ? null : () => _continueWithEmail(context),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Center(
                                    child: _isEmailLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            'Continue with Email',
                                            style: GoogleFonts.lexend(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // OR divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFe5e7eb),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'OR',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9ca3af),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFe5e7eb),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Google Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _continueWithGoogle(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8b5cf6),
                          side: const BorderSide(color: Color(0xFFe5e7eb), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        icon: SvgPicture.network(
                          'https://thesvg.org/icons/google/default.svg',
                          width: 20,
                          height: 20,
                        ),
                        label: Text(
                          'Continue with Google',
                          style: GoogleFonts.lexend(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1f2937),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

              // Terms notice
              Text.rich(
                TextSpan(
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9ca3af),
                  ),
                  children: [
                    const TextSpan(text: 'By signing up, you agree to our '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () {
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                            );
                          }
                        },
                        child: Text(
                          'Terms',
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFa5b4fc),
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' & '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () {
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                            );
                          }
                        },
                        child: Text(
                          'Privacy Policy',
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFa5b4fc),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
                    ],
                  ),
                ),
              ],
            ),
          ),
            ),
        ],
      ),
    ),
      ),
    );
  }
}
