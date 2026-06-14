import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/merge_service.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../presentation/widgets/otp_keypad.dart';
import '../../widgets/galaxy_screen_background.dart';
import '../language_selection_page.dart';
import '../main_navigation.dart';
import '../onboarding_page.dart' show onboardingServiceProvider;
import '../../../constants/app_defaults.dart';
import '../../../presentation/providers/providers.dart' show hiveServiceProvider, vocabularySyncServiceProvider, userStateProvider;
import '../../../presentation/providers/streak_provider.dart' show streakProvider;

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class OtpVerificationPage extends ConsumerStatefulWidget {
  final String email;
  final String? displayName;
  final String? languageLevel;
  final String? englishVariant;
  final bool isGuestCreatingAccount;

  const OtpVerificationPage({
    super.key,
    required this.email,
    this.displayName,
    this.languageLevel,
    this.englishVariant,
    this.isGuestCreatingAccount = false,
  });

  @override
  ConsumerState<OtpVerificationPage> createState() =>
      _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  // Extract display name from email (fallback)
  String? _getDisplayNameFromEmail() {
    if (widget.displayName != null) return widget.displayName;

    // Extract from email (e.g., john.smith@gmail.com → John Smith)
    final localPart = widget.email.split('@').first;
    return localPart
        .split(RegExp(r'[._]'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _countdown = 60;
  Timer? _countdownTimer;
  int _failedAttempts = 0; // Track failed OTP attempts

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Focus first OTP field after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_countdown > 0) return;

    setState(() => _isResending = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendOtp(widget.email);
      if (mounted) {
        SnackBarHelper.success(context, AlertMessages.otpSent, showAboveKeyboard: true);
        _startCountdown();
        // Reset failed attempts when requesting new OTP
        setState(() => _failedAttempts = 0);
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.error(context, AlertMessages.otpSendFailed, showAboveKeyboard: true);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.verifyOtp(
        email: widget.email,
        token: otp,
        displayName: widget.displayName,
        languageLevel: widget.languageLevel,
        englishVariant: widget.englishVariant,
      );

      final response = result['response'] as AuthResponse;
      final isNewUser = result['isNewUser'] as bool;
      final user = response.user;

      if (!mounted) return;

      final preferenceService = ref.read(onboardingServiceProvider);

      if (!isNewUser) {
        // Existing user → เช็คว่ามี guest data ไหม
        final hasGuestData = widget.languageLevel != null || widget.englishVariant != null;

        if (hasGuestData && widget.isGuestCreatingAccount) {
          // แสดง dialog ถามว่าต้องการ merge ไหม
          if (!mounted) return;
          final shouldMerge = await _showMergeDialog(context);

          if (shouldMerge == true) {
            // User เลือก merge → ใช้ MergeService เพื่อ merge ข้อมูล
            try {
              print('🔄 [OTP Login] Starting merge with MergeService...');

              final client = Supabase.instance.client;

              // 1. Collect guest data
              final hiveService = ref.read(hiveServiceProvider);
              final guestStreakData = ref.read(streakProvider);
              final localVocabs = await hiveService.getAllVocabulary();

              final guestData = <String, dynamic>{
                'currentStreak': guestStreakData?.currentStreak ?? 0,
                'longestStreak': guestStreakData?.longestStreak ?? 0,
                'lastStreakActivityDate': guestStreakData?.lastActivityDate?.toIso8601String(),
                'vocabulary': localVocabs,
              };

              print('📦 [OTP Login] Guest data: streak=${guestStreakData?.currentStreak ?? 0}, vocab=${localVocabs.length}');

              // 2. Get server data from Supabase
              final serverUserData = await client
                  .from('users')
                  .select('id, current_streak, longest_streak, last_activity_date')
                  .eq('id', user!.id)
                  .maybeSingle();

              final serverData = serverUserData != null ? <String, dynamic>{
                'currentStreak': serverUserData['current_streak'] ?? 0,
                'longestStreak': serverUserData['longest_streak'] ?? 0,
                'lastStreakActivityDate': serverUserData['last_activity_date']?.toString(),
              } : null;

              print('☁️ [OTP Login] Server data: ${serverData != null ? "found" : "not found"}');

              // 3. Use MergeService to calculate merged result
              final mergeService = MergeService();
              final mergeResult = await mergeService.mergeUserData(
                guestData,
                serverData,
              );

              print('✅ [OTP Login] Merge result: ${mergeResult.summary}');

              // 4. Apply merged data back to services

              // 4a. Update merged preferences to Supabase
              await authService.updateUserPreferences(
                userId: user.id,
                email: widget.email,
                displayName: widget.displayName ?? _getDisplayNameFromEmail(),
                languageLevel: widget.languageLevel,
                englishVariant: widget.englishVariant,
                termsVersion: preferenceService.getCurrentTermsVersion(),
              );

              // 4b. Upload guest vocabulary to cloud (deduplicated via mergeWithCloud)
              final vocabSyncService = ref.read(vocabularySyncServiceProvider);
              if (localVocabs.isNotEmpty) {
                print('☁️ [OTP Login] Merging vocabulary to cloud...');
                final syncedVocabs = await vocabSyncService.mergeWithCloud(localVocabs);
                // Clear local after successful sync
                await hiveService.clearAllVocabulary();
                print('✅ [OTP Login] Vocabulary synced: ${syncedVocabs.length} total');
              }

              // 4c. Update merged streak to cloud
              final mergedStreak = mergeResult.mergedData['currentStreak'] as int? ?? 0;
              final mergedLongest = mergeResult.mergedData['longestStreak'] as int? ?? 0;
              final mergedLastActivity = mergeResult.mergedData['lastStreakActivityDate'] as String?;

              print('📊 [OTP Login] Writing merged streak to cloud: current=$mergedStreak, longest=$mergedLongest');

              await client.from('users').update({
                'current_streak': mergedStreak,
                'longest_streak': mergedLongest,
                if (mergedLastActivity != null) 'last_activity_date': mergedLastActivity,
              }).eq('id', user.id);

              print('✅ [OTP Login] Streak merged and updated to cloud');

              // Refresh local streak state from cloud after merge
              final streakNotifier = ref.read(streakProvider.notifier);
              await streakNotifier.refresh();
              print('✅ [OTP Login] Streak refreshed from cloud after merge');
            } catch (e) {
              // E3: Service unavailable when merging preferences
              print('❌ [OTP Login] Merge failed: $e');
              setState(() => _isLoading = false);
              if (mounted) {
                SnackBarHelper.error(context, AlertMessages.serviceUnavailable, showAboveKeyboard: true);
              }
              return; // Stay on page
            }
          } else {
            // User chose "No" → Keep original server data, don't migrate anything
            print('ℹ️ [OTP Login] User chose to keep original data - skipping merge');
          }

          // Sync UserModel with Supabase preferences (both merge and keep old cases)
          try {
            final userNotifier = ref.read(userStateProvider.notifier);
            final currentUser = ref.read(userStateProvider).user;
            if (currentUser != null) {
              final supabaseUser = Supabase.instance.client.auth.currentUser;
              final cloudLevel = supabaseUser?.userMetadata?['language_level'] as String?;
              final cloudVariant = supabaseUser?.userMetadata?['english_variant'] as String?;

              final updatedUser = currentUser.copyWith(
                preferences: {
                  ...currentUser.preferences,
                  'defaultCefrLevel': cloudLevel ?? currentUser.preferences['defaultCefrLevel'],
                  'languageVariant': cloudVariant ?? currentUser.preferences['languageVariant'],
                },
              );
              await userNotifier.updateUser(updatedUser);
              print('✅ [OTP Login] Synced UserModel with cloud preferences: level=$cloudLevel, variant=$cloudVariant (merged: $shouldMerge)');
            }
          } catch (e) {
            print('⚠️ [OTP Login] Failed to sync UserModel: $e');
          }
        }
      } else if (isNewUser && user != null) {
        // New user flow
        final hasExplicitData = widget.languageLevel != null || widget.englishVariant != null;

        if (hasExplicitData) {
          // มีข้อมูลจาก guest creating account → ใช้เลย
          try {
            await preferenceService.clearLocalPreferences();
            await authService.updateUserPreferences(
              userId: user.id,
              email: widget.email,
              displayName: widget.displayName ?? _getDisplayNameFromEmail(),
              languageLevel: widget.languageLevel ?? AppDefaults.defaultLanguageLevel,
              englishVariant: widget.englishVariant ?? AppDefaults.defaultEnglishVariant,
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
                  print('⚠️ [OTP Login] Partial upload: $uploadedCount/${localVocabs.length}');
                }
              }
            } catch (e) {
              // Upload failed - local vocabularies preserved
              print('❌ [OTP Login] Upload failed: $e');
            }

            // Migrate guest streak to cloud
            try {
              print('🔄 [OTP Login] Migrating guest streak...');
              final streakNotifier = ref.read(streakProvider.notifier);
              final migrated = await streakNotifier.migrateGuestStreakToCloud();
              if (migrated) {
                print('✅ [OTP Login] Streak migrated successfully');
                // Refresh local state from cloud after migration
                await streakNotifier.refresh();
                print('✅ [OTP Login] Streak refreshed from cloud');
              } else {
                print('ℹ️ [OTP Login] No streak data to migrate');
              }
            } catch (e) {
              // Streak migration failed - continue with login
              print('⚠️ [OTP Login] Streak migration failed: $e');
            }
          } catch (e) {
            // E3: Service unavailable when saving preferences
            setState(() => _isLoading = false);
            if (mounted) {
              SnackBarHelper.error(context, AlertMessages.serviceUnavailable, showAboveKeyboard: true);
            }
            return; // Stay on page
          }
        } else {
          // Login จาก onboarding หรือไม่มีข้อมูล → ถาม level/variant
          // EnglishVariantPage จะจัดการทุกอย่างเมื่อ isInitialSetup
          if (!mounted) return;
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
      }

      if (!mounted) return;

      // Mark onboarding as completed
      await preferenceService.setOnboardingCompleted(true);
      // Note: setGuestMode removed - UserModel.isGuest reflects actual auth state

      // Update database
      if (user != null) {
        await Supabase.instance.client
            .from('users')
            .update({'onboarding_completed': true})
            .eq('id', user.id);
      }

      // Auto sync local vocabularies to cloud (for existing users with unsynced data)
      // Skip for new users who just uploaded (already cleared)
      if (!isNewUser) {
        try {
          print('🔄 [OTP Login] Starting auto sync...');
          final hiveService = ref.read(hiveServiceProvider);
          final vocabSyncService = ref.read(vocabularySyncServiceProvider);
          final localVocabs = await hiveService.getAllVocabulary();

          print('📦 [OTP Login] Found ${localVocabs.length} local vocabularies');

          if (localVocabs.isNotEmpty) {
            // Use mergeWithCloud to avoid duplicates
            print('☁️ [OTP Login] Merging with cloud...');
            final syncedVocabs = await vocabSyncService.mergeWithCloud(localVocabs);
            // Update local storage with merged vocabularies
            await hiveService.clearAllVocabulary();
            for (final vocab in syncedVocabs) {
              await hiveService.saveVocabulary(vocab);
            }
            print('✅ [OTP Login] Sync complete! Total vocabularies: ${syncedVocabs.length}');
          } else {
            print('ℹ️ [OTP Login] No local vocabularies to sync');
          }
        } catch (e) {
          print('❌ [OTP Login] Sync failed: $e');
          // Sync failed - continue with login (local vocabularies still available)
        }
      } else {
        print('ℹ️ [OTP Login] Skipping sync (new user)');
      }

      if (!mounted) return;

      // Show different message for existing vs new users
      if (!isNewUser) {
        SnackBarHelper.success(context, AlertMessages.welcomeBack, showAboveKeyboard: true);
      } else {
        SnackBarHelper.success(context, AlertMessages.welcomeToApp, showAboveKeyboard: true);
      }

      // Reset failed attempts on success
      setState(() => _failedAttempts = 0);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      // This catch is for OTP verification errors only
      if (mounted) {
        // Check if it's a Supabase exception with status code
        final isOtpInvalid = e.toString().contains('403') ||
                          e.toString().contains('Invalid OTP') ||
                          e.toString().contains('expired');

        if (isOtpInvalid) {
          // Invalid or expired OTP
          setState(() => _failedAttempts++);

          if (_failedAttempts >= 3) {
            // Show dialog suggesting new OTP after 3 failed attempts
            _showAttemptLimitDialog(context);
          } else {
            // Show normal error message for first 2 attempts
            SnackBarHelper.error(context, AlertMessages.otpInvalid, showAboveKeyboard: true);
            _clearOtp();
          }
        } else {
          // Service unavailable, network error, or other errors
          // Don't increment failed attempts for service errors
          SnackBarHelper.error(context, AlertMessages.serviceUnavailable, showAboveKeyboard: true);
          _clearOtp();
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Show dialog when user reaches 3 failed OTP attempts
  void _showAttemptLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFf8f9ff),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8b5cf6).withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFfbbf24),
                      Color(0xFFf59e0b),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Too many attempts',
                style: GoogleFonts.lexend(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'You\'ve tried 3 times. Would you like a new code?',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
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
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Reset attempts and let user try again
                          setState(() => _failedAttempts = 0);
                          _clearOtp();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9ca3af),
                          side: BorderSide(
                            color: const Color(0xFF9ca3af).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Try again',
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
                      height: 48,
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
                          borderRadius: BorderRadius.circular(12),
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
                            onTap: () async {
                              Navigator.pop(context);
                              // Reset attempts, clear input, and request new OTP
                              setState(() => _failedAttempts = 0);
                              _clearOtp();
                              await _resendOtp();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: const Center(
                              child: Text(
                                'New code',
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
    );
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Removed: auto-move to previous field on delete
    // Let user navigate manually to avoid accidental replacement

    // Auto verify when all 6 digits are entered
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length == 6 && !_isLoading) {
      _verifyOtp();
    }
  }

  void _clearOtp() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  /// Handle number press from custom keypad
  void _onNumberPressed(int number) {
    // Find first empty field
    for (int i = 0; i < 6; i++) {
      if (_otpControllers[i].text.isEmpty) {
        _otpControllers[i].text = number.toString();
        // Move to next field
        if (i < 5) {
          _focusNodes[i + 1].requestFocus();
        }
        // Trigger OTP changed logic
        _onOtpChanged(i, number.toString());
        return;
      }
    }
    // All fields are filled, ignore (or could vibrate to indicate full)
  }

  /// Handle backspace press from custom keypad
  void _onBackspacePressed() {
    // Find which field is currently focused
    int focusedIndex = -1;
    for (int i = 0; i < 6; i++) {
      if (_focusNodes[i].hasFocus) {
        focusedIndex = i;
        break;
      }
    }

    // If no field is focused, find the last filled field
    if (focusedIndex == -1) {
      for (int i = 5; i >= 0; i--) {
        if (_otpControllers[i].text.isNotEmpty) {
          focusedIndex = i;
          break;
        }
      }
    }

    // If still nothing, do nothing
    if (focusedIndex == -1) {
      // Focus first field as default
      _focusNodes[0].requestFocus();
      return;
    }

    // If current focused field has text, clear it
    if (_otpControllers[focusedIndex].text.isNotEmpty) {
      _otpControllers[focusedIndex].clear();
      // Don't move focus, stay on same field
    } else {
      // Current field is empty, find previous filled field
      int previousFilled = -1;
      for (int i = focusedIndex - 1; i >= 0; i--) {
        if (_otpControllers[i].text.isNotEmpty) {
          previousFilled = i;
          break;
        }
      }

      if (previousFilled != -1) {
        // Found previous filled field, clear it and move focus there
        _otpControllers[previousFilled].clear();
        _focusNodes[previousFilled].requestFocus();
      } else {
        // No previous filled field, just move focus to first empty
        for (int i = 0; i < 6; i++) {
          if (_otpControllers[i].text.isEmpty) {
            _focusNodes[i].requestFocus();
            break;
          }
        }
      }
    }
  }

  Future<bool?> _showMergeDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // We handle dismiss manually
      builder: (context) => PopScope(
        canPop: false, // Handle back button manually
        onPopInvokedWithResult: (didPop, result) async {
          // Return false (No) when back is pressed
          if (context.mounted && !didPop) {
            Navigator.of(context).pop(false);
          }
        },
        child: GestureDetector(
          onTap: () => Navigator.pop(context, false), // Tap outside = No
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
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
                        if (widget.languageLevel != null)
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
                                    'Language Level: ${widget.languageLevel}',
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
                        if (widget.englishVariant != null)
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
                                    'English Variant: ${widget.englishVariant}',
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
                    'Merge your guest progress with this account?',
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
                              'Keep my account',
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
                                    'Combine my data',
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
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          GalaxyScreenBackground(
            child: SafeArea(
              child: Column(
                children: [
                  // Fixed card content - not scrollable
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 60, bottom: 16, left: 24, right: 24),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(20),
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
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [

                          // Icon
                          Center(
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF60a5fa),
                                    Color(0xFFa78bfa),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFa78bfa).withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.email_outlined,
                                size: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Title
                          Text(
                            'Check your email',
                            style: GoogleFonts.lexend(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1f2937),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),

                          // Subtitle
                          Text(
                            'We sent a 6-digit code to',
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6b7280),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.email,
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8b5cf6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // OTP Fields
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: SizedBox(
                                  width: 40,
                                  height: 52,
                                  child: IgnorePointer(
                                    child: TextField(
                                      controller: _otpControllers[index],
                                      focusNode: _focusNodes[index],
                                      keyboardType: TextInputType.number,
                                      readOnly: true,
                                      showCursor: true,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.lexend(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1f2937),
                                        height: 1.0,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(1),
                                      ],
                                      decoration: InputDecoration(
                                        counterText: '',
                                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                        filled: true,
                                        fillColor: const Color(0xFFF3F4F6),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFa78bfa),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) =>
                                          _onOtpChanged(index, value),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 24),

                          // Resend Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive? ",
                                style: GoogleFonts.lexend(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF6b7280),
                                ),
                              ),
                              TextButton(
                                onPressed: _countdown == 0 && !_isResending
                                    ? _resendOtp
                                    : null,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: _isResending
                                    ? const SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF8b5cf6),
                                        ),
                                      )
                                    : Text(
                                        _countdown > 0
                                            ? 'Resend in $_countdown s'
                                            : 'Resend',
                                        style: GoogleFonts.lexend(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF8b5cf6),
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
              ),
              // Custom Numeric Keypad - Inside card
              OtpKeypad(
                enabled: !_isLoading,
                onNumberPressed: _onNumberPressed,
                onBackspacePressed: _onBackspacePressed,
              ),
            ],
          ),
        ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.8),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFa78bfa),
                ),
              ),
            ),
          // Back button - positioned at the end for highest z-index
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              bottom: false,
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
          ),
        ],
      ),
    );
  }
}
