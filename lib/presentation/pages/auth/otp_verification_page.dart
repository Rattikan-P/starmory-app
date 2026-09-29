import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../constants/design_tokens.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/merge_service.dart';
import '../../../utils/snackbar_helper.dart';
import '../../widgets/tokenized_notice_dialogs.dart';
import '../../../presentation/widgets/otp_keypad.dart';
import '../language_selection_page.dart';
import '../main_navigation.dart';
import '../onboarding_page.dart' show onboardingServiceProvider;
import '../../../constants/app_defaults.dart';
import '../../../presentation/providers/providers.dart'
    show
        hiveServiceProvider,
        vocabularySyncServiceProvider,
        userStateProvider,
        badgeStateProvider,
        scrapbookStateProvider,
        vocabularyStateProvider;
import '../../../presentation/providers/streak_provider.dart'
    show streakProvider;
import '../../../presentation/utils/reward_unlock_helper.dart'
    show pendingRewardCheckProvider;

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class OtpVerificationPage extends ConsumerStatefulWidget {
  final String email;
  final String? displayName;
  final String? languageLevel;
  final String? englishVariant;
  final Map<String, dynamic>? guestStreakSnapshot;
  final bool isGuestCreatingAccount;

  const OtpVerificationPage({
    super.key,
    required this.email,
    this.displayName,
    this.languageLevel,
    this.englishVariant,
    this.guestStreakSnapshot,
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
        SnackBarHelper.success(context, AlertMessages.otpSent,
            showAboveKeyboard: true);
        _startCountdown();
        // Reset failed attempts when requesting new OTP
        setState(() => _failedAttempts = 0);
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.error(context, AlertMessages.otpSendFailed,
            showAboveKeyboard: true);
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();

    setState(() => _isLoading = true);
    var syncIncomplete = false;
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

      bool? shouldMerge;
      if (!isNewUser) {
        // Existing user → เช็คว่ามี guest data ไหม
        final hasGuestData = widget.languageLevel != null ||
            widget.englishVariant != null ||
            (widget.guestStreakSnapshot?['currentStreak'] as int? ?? 0) > 0 ||
            (widget.guestStreakSnapshot?['longestStreak'] as int? ?? 0) > 0 ||
            (widget.guestStreakSnapshot?['shields'] as int? ?? 0) > 0 ||
            widget.guestStreakSnapshot?['lastStreakActivityDate'] != null ||
            widget.guestStreakSnapshot?['streakStateUpdatedAt'] != null ||
            (widget.guestStreakSnapshot?['badges'] as List?)?.isNotEmpty ==
                true;
        if (hasGuestData && widget.isGuestCreatingAccount) {
          // แสดง dialog ถามว่าต้องการ merge ไหม
          if (!mounted) return;
          shouldMerge = await _showMergeDialog(context);

          if (shouldMerge == true) {
            // User เลือก merge → ใช้ MergeService เพื่อ merge ข้อมูล
            try {
              print('🔄 [OTP Login] Starting merge with MergeService...');

              final client = Supabase.instance.client;

              // 1. Collect guest data
              final hiveService = ref.read(hiveServiceProvider);
              final guestStreakData = ref.read(streakProvider);
              final guestSnapshot = widget.guestStreakSnapshot;
              final localVocabs = await hiveService.getAllVocabulary();

              final guestData = <String, dynamic>{
                'currentStreak': guestSnapshot != null
                    ? guestSnapshot['currentStreak'] ?? 0
                    : guestStreakData?.currentStreak ?? 0,
                'longestStreak': guestSnapshot != null
                    ? guestSnapshot['longestStreak'] ?? 0
                    : guestStreakData?.longestStreak ?? 0,
                'lastStreakActivityDate': guestSnapshot != null
                    ? guestSnapshot['lastStreakActivityDate']
                    : guestStreakData?.lastActivityDate?.toIso8601String(),
                'streakStateUpdatedAt': guestSnapshot != null
                    ? guestSnapshot['streakStateUpdatedAt']
                    : guestStreakData?.streakStateUpdatedAt?.toIso8601String(),
                'shields': guestSnapshot != null
                    ? guestSnapshot['shields'] ?? 0
                    : guestStreakData?.shieldsAvailable ?? 0,
                'badges': widget.guestStreakSnapshot?['badges'] ?? <String>[],
                'vocabulary': localVocabs,
              };

              print(
                  '📦 [OTP Login] Guest data: streak=${guestData['currentStreak']}, lastActivity=${guestData['lastStreakActivityDate']}, stateUpdatedAt=${guestData['streakStateUpdatedAt']}, vocab=${localVocabs.length}');

              // 2. Get server data from Supabase
              final serverUserData = await client
                  .from('users')
                  .select(
                      'id, current_streak, longest_streak, shields_available, last_activity_date, streak_state_updated_at')
                  .eq('id', user!.id)
                  .maybeSingle();

              final serverData = serverUserData != null
                  ? <String, dynamic>{
                      'current_streak': serverUserData['current_streak'] ?? 0,
                      'longest_streak': serverUserData['longest_streak'] ?? 0,
                      'shields_available':
                          serverUserData['shields_available'] ?? 0,
                      'last_activity_date':
                          serverUserData['last_activity_date']?.toString(),
                      'streak_state_updated_at':
                          serverUserData['streak_state_updated_at']?.toString(),
                      'badges':
                          client.auth.currentUser?.userMetadata?['badges'] ??
                              <String>[],
                    }
                  : null;

              print(
                  '☁️ [OTP Login] Server data: ${serverData != null ? "found" : "not found"}');

              // 3. Use MergeService to calculate merged result
              final mergeService = MergeService();
              final mergeResult = await mergeService.mergeUserData(
                guestData,
                serverData,
              );

              print('✅ [OTP Login] Merge result: ${mergeResult.summary}');
              print(
                  '🔎 [OTP Login] Streak merge values: guest=${guestData['currentStreak']} @ ${guestData['streakStateUpdatedAt'] ?? guestData['lastStreakActivityDate']}, server=${serverData?['current_streak']} @ ${serverData?['streak_state_updated_at'] ?? serverData?['last_activity_date']}, merged=${mergeResult.mergedData['current_streak']} @ ${mergeResult.mergedData['streak_state_updated_at'] ?? mergeResult.mergedData['last_activity_date']}');

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
                final syncedVocabs =
                    await vocabSyncService.mergeWithCloud(localVocabs);
                // Clear local and save merged result
                await hiveService.clearAllVocabulary();
                for (final vocab in syncedVocabs) {
                  await hiveService.saveVocabulary(vocab);
                }
                print(
                    '✅ [OTP Login] Vocabulary synced and saved locally: ${syncedVocabs.length} total');
              }

              // 4b2. Upload guest scrapbooks to cloud
              try {
                print('☁️ [OTP Login] Syncing guest scrapbooks to cloud...');
                await ref
                    .read(scrapbookStateProvider.notifier)
                    .syncGuestScrapbooksToCloud();
                print('✅ [OTP Login] Guest scrapbooks synced to cloud');
              } catch (e) {
                syncIncomplete = true;
                print(
                    '⚠️ [OTP Login] Failed to sync guest scrapbooks to cloud: $e');
              }

              // 4c. Update merged streak to cloud
              final mergedStreak =
                  mergeResult.mergedData['current_streak'] as int? ?? 0;
              final mergedLongest =
                  mergeResult.mergedData['longest_streak'] as int? ?? 0;
              final mergedShields =
                  mergeResult.mergedData['shields_available'] as int? ?? 0;
              final mergedBadgesValue = mergeResult.mergedData['badges'];
              final mergedBadges = mergedBadgesValue is Set
                  ? mergedBadgesValue.cast<String>().toList()
                  : mergedBadgesValue is List
                      ? mergedBadgesValue.cast<String>()
                      : <String>[];
              final mergedLastActivity =
                  mergeResult.mergedData['last_activity_date'];
              final lastActivityDate = mergedLastActivity is DateTime
                  ? mergedLastActivity.toIso8601String().split('T').first
                  : mergedLastActivity is String
                      ? mergedLastActivity.split('T').first
                      : null;
              final mergedStateUpdated =
                  mergeResult.mergedData['streak_state_updated_at'];
              final stateUpdatedAt = mergedStateUpdated is DateTime
                  ? mergedStateUpdated.toUtc().toIso8601String()
                  : mergedStateUpdated is String
                      ? DateTime.tryParse(mergedStateUpdated)
                          ?.toUtc()
                          .toIso8601String()
                      : null;

              print(
                  '📊 [OTP Login] Writing merged streak to cloud: current=$mergedStreak, longest=$mergedLongest');

              await client.from('users').update({
                'current_streak': mergedStreak,
                'longest_streak': mergedLongest,
                'shields_available': mergedShields,
                'last_activity_date': lastActivityDate,
                if (stateUpdatedAt != null)
                  'streak_state_updated_at': stateUpdatedAt,
              }).eq('id', user.id);
              await client.auth.updateUser(
                UserAttributes(data: {'badges': mergedBadges}),
              );

              print('✅ [OTP Login] Streak merged and updated to cloud');

              // Refresh local streak state from cloud after merge
              final streakNotifier = ref.read(streakProvider.notifier);
              await streakNotifier.refresh();
              print('✅ [OTP Login] Streak refreshed from cloud after merge');

              final mergedUser = ref.read(userStateProvider).user;
              if (mergedUser != null) {
                await ref.read(userStateProvider.notifier).updateUser(
                      mergedUser.copyWith(
                        badges: mergedBadges,
                        preferences: {
                          ...mergedUser.preferences,
                          'badges': mergedBadges,
                        },
                      ),
                    );
              }
            } catch (e) {
              // E3: Service unavailable when merging preferences
              print('❌ [OTP Login] Merge failed: $e');
              setState(() => _isLoading = false);
              if (mounted) {
                showSupabaseRequestErrorDialog(context);
              }
              return; // Stay on page
            }
          } else {
            // User chose "No" / "Keep my account" → Clear local guest data
            ref.read(pendingRewardCheckProvider.notifier).state = false;
            ref.read(badgeStateProvider.notifier).clearPendingUnlocks();
            print(
                'ℹ️ [OTP Login] User chose to keep original server data - clearing guest data');
            try {
              final hiveService = ref.read(hiveServiceProvider);
              await hiveService.clearAllVocabulary();
              await hiveService.clearAllScrapbooks();
              await ref.read(scrapbookStateProvider.notifier).clear();
            } catch (e) {
              syncIncomplete = true;
              print('⚠️ [OTP Login] Failed to clear local guest data: $e');
            }
          }

          // Sync UserModel with Supabase preferences (both merge and keep old cases)
          try {
            final userNotifier = ref.read(userStateProvider.notifier);
            final currentUser = ref.read(userStateProvider).user;
            if (currentUser != null) {
              final supabaseUser = Supabase.instance.client.auth.currentUser;
              final cloudLevel =
                  supabaseUser?.userMetadata?['language_level'] as String?;
              final cloudVariant =
                  supabaseUser?.userMetadata?['english_variant'] as String?;

              final updatedUser = currentUser.copyWith(
                preferences: {
                  ...currentUser.preferences,
                  'defaultCefrLevel':
                      cloudLevel ?? currentUser.preferences['defaultCefrLevel'],
                  'languageVariant': cloudVariant ??
                      currentUser.preferences['languageVariant'],
                },
              );
              await userNotifier.updateUser(updatedUser);
              print(
                  '✅ [OTP Login] Synced UserModel with cloud preferences: level=$cloudLevel, variant=$cloudVariant (merged: $shouldMerge)');
            }
          } catch (e) {
            syncIncomplete = true;
            print('⚠️ [OTP Login] Failed to sync UserModel: $e');
          }
        }
      } else if (isNewUser && user != null) {
        // New user flow
        final hasExplicitData = widget.languageLevel != null ||
            widget.englishVariant != null ||
            (widget.guestStreakSnapshot?['currentStreak'] as int? ?? 0) > 0 ||
            (widget.guestStreakSnapshot?['longestStreak'] as int? ?? 0) > 0 ||
            (widget.guestStreakSnapshot?['shields'] as int? ?? 0) > 0 ||
            widget.guestStreakSnapshot?['lastStreakActivityDate'] != null ||
            widget.guestStreakSnapshot?['streakStateUpdatedAt'] != null ||
            (widget.guestStreakSnapshot?['badges'] as List?)?.isNotEmpty ==
                true;

        if (hasExplicitData) {
          // มีข้อมูลจาก guest creating account → ใช้เลย
          try {
            await preferenceService.clearLocalPreferences();
            await authService.updateUserPreferences(
              userId: user.id,
              email: widget.email,
              displayName: widget.displayName ?? _getDisplayNameFromEmail(),
              languageLevel:
                  widget.languageLevel ?? AppDefaults.defaultLanguageLevel,
              englishVariant:
                  widget.englishVariant ?? AppDefaults.defaultEnglishVariant,
              termsVersion: preferenceService.getCurrentTermsVersion(),
            );

            // Upload guest vocabulary to new user's cloud storage
            final hiveService = ref.read(hiveServiceProvider);
            final vocabSyncService = ref.read(vocabularySyncServiceProvider);
            try {
              final localVocabs = await hiveService.getAllVocabulary();
              if (localVocabs.isNotEmpty) {
                final uploadedCount =
                    await vocabSyncService.batchUpload(localVocabs);
                // Only clear local vocabularies after successful upload of ALL items
                if (uploadedCount == localVocabs.length) {
                  await hiveService.clearAllVocabulary();
                } else {
                  // Partial upload failed - keep local data for retry
                  syncIncomplete = true;
                  print(
                      '⚠️ [OTP Login] Partial upload: $uploadedCount/${localVocabs.length}');
                }
              }
            } catch (e) {
              // Upload failed - local vocabularies preserved
              syncIncomplete = true;
              print('❌ [OTP Login] Upload failed: $e');
            }

            // Upload guest scrapbooks to cloud
            try {
              print('🔄 [OTP Login] Uploading guest scrapbooks to cloud...');
              await ref
                  .read(scrapbookStateProvider.notifier)
                  .syncGuestScrapbooksToCloud();
              print('✅ [OTP Login] Guest scrapbooks uploaded to cloud');
            } catch (e) {
              syncIncomplete = true;
              print('⚠️ [OTP Login] Guest scrapbooks upload failed: $e');
            }

            // Migrate guest streak to cloud
            try {
              print('🔄 [OTP Login] Migrating guest streak...');
              final streakNotifier = ref.read(streakProvider.notifier);
              final migrated = await streakNotifier.migrateGuestStreakToCloud(
                guestStreakSnapshot: widget.guestStreakSnapshot,
              );
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
              syncIncomplete = true;
              print('⚠️ [OTP Login] Streak migration failed: $e');
            }
          } catch (e) {
            // E3: Service unavailable when saving preferences
            setState(() => _isLoading = false);
            if (mounted) {
              showSupabaseRequestErrorDialog(context);
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
            .update({'onboarding_completed': true}).eq('id', user.id);
      }

      // Post-auth data sync & state refresh
      if (shouldMerge == false) {
        // User explicitly chose NOT to merge guest data -> load cloud-only data
        try {
          print('☁️ [OTP Login] Loading cloud-only data (no guest merge)...');
          final hiveService = ref.read(hiveServiceProvider);
          final vocabSyncService = ref.read(vocabularySyncServiceProvider);

          // Clear any leftover local guest data
          await hiveService.clearAllVocabulary();
          await hiveService.clearAllScrapbooks();
          await ref.read(scrapbookStateProvider.notifier).clear();

          // Fetch cloud-only vocabularies and save to Hive
          final cloudVocabs = await vocabSyncService.fetchFromCloud();
          for (final vocab in cloudVocabs) {
            await hiveService.saveVocabulary(vocab);
          }

          await ref.read(vocabularyStateProvider.notifier).refresh();
          await ref.read(scrapbookStateProvider.notifier).refresh();
          await ref.read(streakProvider.notifier).refresh();
          print('✅ [OTP Login] Cloud-only data loaded successfully');
        } catch (e) {
          syncIncomplete = true;
          print('⚠️ [OTP Login] Failed to load cloud-only data: $e');
        }
      } else {
        // New user or Combine chosen or Existing user logging in -> sync & refresh
        try {
          print('🔄 [OTP Login] Refreshing user data state from cloud...');
          await ref.read(vocabularyStateProvider.notifier).syncFromCloud();
          await ref.read(scrapbookStateProvider.notifier).refresh();
          await ref.read(streakProvider.notifier).refresh();
          print('✅ [OTP Login] User data state synced and refreshed');
        } catch (e) {
          syncIncomplete = true;
          print('⚠️ [OTP Login] Failed to sync/refresh user data state: $e');
        }
      }

      if (!mounted) return;

      // Show different message for existing vs new users
      if (syncIncomplete) {
        SnackBarHelper.warning(
          context,
          'Account connected, but some progress may not have synced yet.',
          duration: const Duration(seconds: 5),
          showAboveKeyboard: true,
        );
      } else if (!isNewUser) {
        SnackBarHelper.success(context, AlertMessages.welcomeBack,
            showAboveKeyboard: true);
      } else {
        SnackBarHelper.success(context, AlertMessages.welcomeToApp,
            showAboveKeyboard: true);
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
            SnackBarHelper.error(context, AlertMessages.otpInvalid,
                showAboveKeyboard: true);
            _clearOtp();
          }
        } else {
          // Service unavailable, network error, or other errors
          // Don't increment failed attempts for service errors
          showSupabaseRequestErrorDialog(context);
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: DesignTokens.dialogWarning.withValues(alpha: 0.16),
                blurRadius: 28,
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
                decoration: const BoxDecoration(
                  color: DesignTokens.dialogWarningTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: DesignTokens.dialogWarning,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Too many attempts',
                style: GoogleFonts.lexend(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF221F33),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                'You\'ve tried 3 times. Would you like a new code?',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF221F33),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Reset attempts and let user try again
                          setState(() => _failedAttempts = 0);
                          _clearOtp();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9CA3AF),
                          side: BorderSide(
                            color: const Color(0xFFE8E0FF),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'Try again',
                          style: GoogleFonts.lexend(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          // Reset attempts, clear input, and request new OTP
                          setState(() => _failedAttempts = 0);
                          _clearOtp();
                          await _resendOtp();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.dialogWarning,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'New code',
                          style: GoogleFonts.lexend(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
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

  Future<bool?> _showMergeDialog(BuildContext context) {
    return showTokenizedChoiceDialog(
      context,
      title: 'Account already exists',
      message: 'This email already has an account.',
      question: 'Merge your guest progress with this account?',
      icon: Icons.merge_rounded,
      primaryLabel: 'Combine my\ndata',
      secondaryLabel: 'Keep my\naccount',
      primaryMultiline: true,
      secondaryMultiline: true,
      content: TokenizedGuestPreferencesCard(
        languageLevel: widget.languageLevel,
        englishVariant: widget.englishVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildOtpReferenceLayout();

  Widget _buildOtpReferenceLayout() {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF3F4F6),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 58),
                        Image.asset(
                          'assets/images/otp_mascot.png',
                          width: 104,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Check your email',
                          style: GoogleFonts.lexend(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF25252B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'We sent a 6-digit code to',
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            color: const Color(0xFF929299),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          widget.email,
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF8953F6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 5),
                              child: SizedBox(
                                width: 40,
                                height: 42,
                                child: IgnorePointer(
                                  child: TextField(
                                    controller: _otpControllers[index],
                                    focusNode: _focusNodes[index],
                                    keyboardType: TextInputType.number,
                                    readOnly: true,
                                    showCursor: false,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.lexend(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF25252B),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(1),
                                    ],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      contentPadding: EdgeInsets.zero,
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFDDD6FE)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFDDD6FE)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF8953F6),
                                          width: 1.4,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Didn't receive?",
                              style: GoogleFonts.lexend(
                                fontSize: 14,
                                color: const Color(0xFF929299),
                              ),
                            ),
                            TextButton(
                              onPressed: _countdown == 0 && !_isResending
                                  ? _resendOtp
                                  : null,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.only(left: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: _isResending
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF8953F6),
                                      ),
                                    )
                                  : Text(
                                      _countdown > 0
                                          ? 'Resend in $_countdown s'
                                          : 'Resend',
                                      style: GoogleFonts.lexend(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF8953F6),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
                OtpKeypad(
                  enabled: !_isLoading,
                  onNumberPressed: _onNumberPressed,
                  onBackspacePressed: _onBackspacePressed,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFF8953F6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please wait...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: DesignTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
