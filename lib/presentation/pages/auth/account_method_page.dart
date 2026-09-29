import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/merge_service.dart';
import '../../../utils/snackbar_helper.dart';
import '../../widgets/tokenized_notice_dialogs.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/bottom_sheet_chrome.dart';
import '../main_navigation.dart';
import '../onboarding_page.dart';
import '../language_selection_page.dart';
import 'otp_verification_page.dart' show OtpVerificationPage;
import '../../../constants/app_defaults.dart';
import '../../../constants/design_tokens.dart';
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

class AccountMethodPage extends ConsumerStatefulWidget {
  const AccountMethodPage({super.key});

  @override
  ConsumerState<AccountMethodPage> createState() => _AccountMethodPageState();

  /// Show the create account bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AccountMethodPage(),
    );
  }
}

class _AccountMethodPageState extends ConsumerState<AccountMethodPage> {
  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  OverlayEntry? _googleLoadingEntry;

  @override
  void dispose() {
    _googleLoadingEntry?.remove();
    _googleLoadingEntry?.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showGoogleLoadingOverlay(BuildContext context) {
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.white,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: DesignTokens.brandColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please wait...',
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
      ),
    );
    _googleLoadingEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _hideGoogleLoadingOverlay() {
    final entry = _googleLoadingEntry;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
    _googleLoadingEntry = null;
  }

  Future<void> _continueWithGoogle(BuildContext context) async {
    if (_isGoogleLoading || _isEmailLoading) return;
    setState(() => _isGoogleLoading = true);
    var syncIncomplete = false;

    try {
      _showGoogleLoadingOverlay(context);
      final preferenceService = ref.read(onboardingServiceProvider);
      await preferenceService.init();

      // ⭐ IMPORTANT: Read guest preferences BEFORE sign in
      // Otherwise, auth state change will convert guest → registered before we can read
      final currentUserBeforeAuth = ref.read(userStateProvider).user;
      final guestLevel = currentUserBeforeAuth?.languageLevel;
      final guestVariant = currentUserBeforeAuth?.englishVariant;
      final guestStreakSnapshot = currentUserBeforeAuth == null
          ? null
          : <String, dynamic>{
              'currentStreak': currentUserBeforeAuth.currentStreak,
              'longestStreak': currentUserBeforeAuth.longestStreak,
              'shields': currentUserBeforeAuth.shields,
              'lastStreakActivityDate': currentUserBeforeAuth
                  .lastStreakActivityDate
                  ?.toIso8601String(),
              'streakStateUpdatedAt':
                  currentUserBeforeAuth.streakStateUpdatedAt?.toIso8601String(),
              'badges': currentUserBeforeAuth.badges,
            };

      // Check if user has non-default preferences (has guest data)
      final hasGuestData = currentUserBeforeAuth != null &&
          (currentUserBeforeAuth.languageLevel !=
                  AppDefaults.defaultLanguageLevel ||
              currentUserBeforeAuth.englishVariant !=
                  AppDefaults.defaultEnglishVariant ||
              currentUserBeforeAuth.currentStreak > 0 ||
              currentUserBeforeAuth.longestStreak > 0 ||
              currentUserBeforeAuth.shields > 0 ||
              currentUserBeforeAuth.lastStreakActivityDate != null ||
              currentUserBeforeAuth.streakStateUpdatedAt != null ||
              currentUserBeforeAuth.badges.isNotEmpty);

      debugPrint(
          '📝 Guest preferences captured BEFORE auth: level=$guestLevel, variant=$guestVariant, hasData=$hasGuestData');

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
      String? displayName =
          user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];

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
      await preferenceService
          .setTermsVersion(preferenceService.getCurrentTermsVersion());

      final userData = await client
          .from('users')
          .select('id, language_level, onboarding_completed, display_name')
          .eq('id', userId)
          .maybeSingle();

      final isNewUser =
          userData == null || userData['onboarding_completed'] != true;

      if (!context.mounted) return;

      bool? shouldMerge;

      if (isNewUser) {
        //  New user
        String? finalLevel = guestLevel;
        String? finalVariant = guestVariant;

        if (!hasGuestData) {
          // ไม่มีข้อมูล guest → ถาม level/variant
          // Close bottom sheet first, then navigate
          _hideGoogleLoadingOverlay();
          if (context.mounted) {
            Navigator.of(context).pop(); // Close bottom sheet
          }
          // LanguageSelectionPage จะจัดการทุกอย่าง (บันทึกข้อมูล, navigate) เมื่อ isInitialSetup
          if (context.mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LanguageSelectionPage(
                  isGuest: false,
                  isInitialSetup: true,
                  returnAfterSelection: false,
                ),
              ),
            );
          }
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
              final uploadedCount =
                  await vocabSyncService.batchUpload(localVocabs);
              // Only clear local vocabularies after successful upload of ALL items
              if (uploadedCount == localVocabs.length) {
                await hiveService.clearAllVocabulary();
              } else {
                // Partial upload failed - keep local data for retry
                syncIncomplete = true;
                print(
                    '⚠️ [Google Login] Partial upload: $uploadedCount/${localVocabs.length}');
              }
            }
          } catch (e) {
            // Upload failed - local vocabularies preserved
            syncIncomplete = true;
            print('❌ [Google Login] Upload failed: $e');
          }

          // Upload guest scrapbooks to cloud
          try {
            print('🔄 [Google Login] Uploading guest scrapbooks to cloud...');
            await ref
                .read(scrapbookStateProvider.notifier)
                .syncGuestScrapbooksToCloud();
            print('✅ [Google Login] Guest scrapbooks uploaded to cloud');
          } catch (e) {
            syncIncomplete = true;
            print('⚠️ [Google Login] Guest scrapbooks upload failed: $e');
          }

          // Migrate guest streak to cloud
          try {
            print('🔄 [Google Login] Migrating guest streak...');
            final streakNotifier = ref.read(streakProvider.notifier);
            final migrated = await streakNotifier.migrateGuestStreakToCloud(
              guestStreakSnapshot: guestStreakSnapshot,
            );
            if (migrated) {
              print('✅ [Google Login] Streak migrated successfully');
              // Refresh local state from cloud after migration
              await streakNotifier.refresh();
              print('✅ [Google Login] Streak refreshed from cloud');
            } else {
              print('ℹ️ [Google Login] No streak data to migrate');
            }
          } catch (e) {
            // Streak migration failed - continue with login
            syncIncomplete = true;
            print('⚠️ [Google Login] Streak migration failed: $e');
          }

          // set onboarding_completed
          await client
              .from('users')
              .update({'onboarding_completed': true}).eq('id', userId);
        } catch (e) {
          // E3: Service unavailable when saving preferences
          if (context.mounted) {
            _hideGoogleLoadingOverlay();
            showSupabaseRequestErrorDialog(context);
          }
          return; // Stay on page, user can retry
        }
      } else {
        // Existing user → เช็คว่ามี guest data ไหม
        if (hasGuestData) {
          // แสดง dialog ถามว่าต้องการ merge ไหม
          if (!context.mounted) return;
          _hideGoogleLoadingOverlay();
          shouldMerge =
              await _showMergeDialog(context, guestLevel, guestVariant);
          if (!context.mounted) return;
          _showGoogleLoadingOverlay(context);

          if (shouldMerge == true) {
            // User เลือก merge → ใช้ MergeService เพื่อ merge ข้อมูล
            try {
              print('🔄 [Google Login] Starting merge with MergeService...');

              // 1. Collect guest data
              final hiveService = ref.read(hiveServiceProvider);
              final guestStreakData = ref.read(streakProvider);
              final guestSnapshot = guestStreakSnapshot;
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
                'badges': guestStreakSnapshot?['badges'] ??
                    currentUserBeforeAuth.badges ??
                    <String>[],
                'vocabulary': localVocabs,
              };

              print(
                  '📦 [Google Login] Guest data: streak=${guestData['currentStreak']}, lastActivity=${guestData['lastStreakActivityDate']}, stateUpdatedAt=${guestData['streakStateUpdatedAt']}, vocab=${localVocabs.length}');

              // 2. Get server data from Supabase
              final serverUserData = await client
                  .from('users')
                  .select(
                      'id, current_streak, longest_streak, shields_available, last_activity_date, streak_state_updated_at')
                  .eq('id', userId)
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
                  '☁️ [Google Login] Server data: ${serverData != null ? "found" : "not found"}');

              // 3. Use MergeService to calculate merged result
              final mergeService = MergeService();
              final mergeResult = await mergeService.mergeUserData(
                guestData,
                serverData,
              );

              print('✅ [Google Login] Merge result: ${mergeResult.summary}');
              print(
                  '🔎 [Google Login] Streak merge values: guest=${guestData['currentStreak']} @ ${guestData['streakStateUpdatedAt'] ?? guestData['lastStreakActivityDate']}, server=${serverData?['current_streak']} @ ${serverData?['streak_state_updated_at'] ?? serverData?['last_activity_date']}, merged=${mergeResult.mergedData['current_streak']} @ ${mergeResult.mergedData['streak_state_updated_at'] ?? mergeResult.mergedData['last_activity_date']}');

              // 4. Apply merged data back to services

              // 4a. Update merged preferences to Supabase
              await authService.updateUserPreferences(
                userId: userId,
                email: client.auth.currentUser?.email ?? '',
                displayName: displayName,
                languageLevel:
                    guestLevel, // For existing users, server wins in merge config, but we merge guest choice on dialog click
                englishVariant: guestVariant,
                termsVersion: preferenceService.getCurrentTermsVersion(),
              );

              // 4b. Upload guest vocabulary to cloud (deduplicated via mergeWithCloud)
              final vocabSyncService = ref.read(vocabularySyncServiceProvider);
              if (localVocabs.isNotEmpty) {
                print('☁️ [Google Login] Merging vocabulary to cloud...');
                final syncedVocabs =
                    await vocabSyncService.mergeWithCloud(localVocabs);
                // Clear local and save merged result
                await hiveService.clearAllVocabulary();
                for (final vocab in syncedVocabs) {
                  await hiveService.saveVocabulary(vocab);
                }
                print(
                    '✅ [Google Login] Vocabulary synced and saved locally: ${syncedVocabs.length} total');
              }

              // 4b2. Upload guest scrapbooks to cloud
              try {
                print('☁️ [Google Login] Syncing guest scrapbooks to cloud...');
                await ref
                    .read(scrapbookStateProvider.notifier)
                    .syncGuestScrapbooksToCloud();
                print('✅ [Google Login] Guest scrapbooks synced to cloud');
              } catch (e) {
                syncIncomplete = true;
                print(
                    '⚠️ [Google Login] Failed to sync guest scrapbooks to cloud: $e');
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
                  '📊 [Google Login] Writing merged streak to cloud: current=$mergedStreak, longest=$mergedLongest');

              await client.from('users').update({
                'current_streak': mergedStreak,
                'longest_streak': mergedLongest,
                'shields_available': mergedShields,
                'last_activity_date': lastActivityDate,
                if (stateUpdatedAt != null)
                  'streak_state_updated_at': stateUpdatedAt,
              }).eq('id', userId);
              await client.auth.updateUser(
                UserAttributes(data: {'badges': mergedBadges}),
              );

              print('✅ [Google Login] Streak merged and updated to cloud');

              // Refresh local streak state from cloud after merge
              final streakNotifier = ref.read(streakProvider.notifier);
              await streakNotifier.refresh();
              print('✅ [Google Login] Streak refreshed from cloud after merge');

              // Refresh UserModel with merged preferences from Supabase
              final userNotifier = ref.read(userStateProvider.notifier);
              final currentUser = ref.read(userStateProvider).user;
              if (currentUser != null) {
                final supabaseUser = client.auth.currentUser;
                final mergedLevel =
                    supabaseUser?.userMetadata?["language_level"] as String?;
                final mergedVariant =
                    supabaseUser?.userMetadata?["english_variant"] as String?;

                final updatedUser = currentUser.copyWith(
                  currentStreak: mergedStreak,
                  longestStreak: mergedLongest,
                  shields: mergedShields,
                  badges: mergedBadges,
                  lastStreakActivityDate: lastActivityDate == null
                      ? currentUser.lastStreakActivityDate
                      : DateTime.tryParse(lastActivityDate),
                  clearLastStreakActivityDate: lastActivityDate == null,
                  streakStateUpdatedAt: mergedStateUpdated is DateTime
                      ? mergedStateUpdated
                      : mergedStateUpdated is String
                          ? DateTime.tryParse(mergedStateUpdated)
                          : currentUser.streakStateUpdatedAt,
                  preferences: {
                    ...currentUser.preferences,
                    'badges': mergedBadges,
                    "defaultCefrLevel": mergedLevel ??
                        currentUser.preferences["defaultCefrLevel"],
                    "languageVariant": mergedVariant ??
                        currentUser.preferences["languageVariant"],
                  },
                );
                await userNotifier.updateUser(updatedUser);
                print(
                    "✅ [Google Login] Refreshed UserModel with merged preferences: level=$mergedLevel, variant=$mergedVariant");
              }
            } catch (e) {
              // E3: Service unavailable when merging preferences
              print('❌ [Google Login] Merge failed: $e');
              if (context.mounted) {
                _hideGoogleLoadingOverlay();
                showSupabaseRequestErrorDialog(context);
              }
              return; // Stay on page, user can retry
            }
          } else {
            // User chose "No" / "Keep my account" → Clear local guest data
            ref.read(pendingRewardCheckProvider.notifier).state = false;
            ref.read(badgeStateProvider.notifier).clearPendingUnlocks();
            print(
                'ℹ️ [Google Login] User chose to keep original server data - clearing guest data');
            try {
              final hiveService = ref.read(hiveServiceProvider);
              await hiveService.clearAllVocabulary();
              await hiveService.clearAllScrapbooks();
              await ref.read(scrapbookStateProvider.notifier).clear();
            } catch (e) {
              syncIncomplete = true;
              print('⚠️ [Google Login] Failed to clear local guest data: $e');
            }
          }
        }
      }

      if (!context.mounted) return;

      await preferenceService.setOnboardingCompleted(true);
      // Note: setGuestMode removed - UserModel.isGuest reflects actual auth state

      // Post-auth data sync & state refresh
      if (shouldMerge == false) {
        // User explicitly chose NOT to merge guest data -> load cloud-only data
        try {
          print(
              '☁️ [Google Login] Loading cloud-only data (no guest merge)...');
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
          print('✅ [Google Login] Cloud-only data loaded successfully');
        } catch (e) {
          syncIncomplete = true;
          print('⚠️ [Google Login] Failed to load cloud-only data: $e');
        }
      } else {
        // New user or Combine chosen or Existing user logging in -> sync & refresh
        try {
          print('🔄 [Google Login] Refreshing user data state from cloud...');
          await ref.read(vocabularyStateProvider.notifier).syncFromCloud();
          await ref.read(scrapbookStateProvider.notifier).refresh();
          await ref.read(streakProvider.notifier).refresh();
          print('✅ [Google Login] User data state synced and refreshed');
        } catch (e) {
          syncIncomplete = true;
          print('⚠️ [Google Login] Failed to sync/refresh user data state: $e');
        }
      }

      if (!context.mounted) return;

      // Show different message for existing vs new users
      if (syncIncomplete) {
        SnackBarHelper.warning(
          context,
          'Account connected, but some progress may not have synced yet.',
          duration: const Duration(seconds: 5),
        );
      } else if (!isNewUser) {
        SnackBarHelper.success(context, AlertMessages.welcomeBack);
      } else {
        SnackBarHelper.success(context, AlertMessages.welcomeToApp);
      }

      // Wait a bit so user can see the success message
      await Future.delayed(const Duration(milliseconds: 500));

      if (!context.mounted) return;

      // Navigate using rootNavigator (same as onboarding)
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, AlertMessages.loginFailed);
      }
    } finally {
      _hideGoogleLoadingOverlay();
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _continueWithEmail(BuildContext context) async {
    if (_isGoogleLoading || _isEmailLoading) return;
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isEmailLoading = true);

    try {
      final email = _emailController.text.trim();

      // ⭐ IMPORTANT: Read guest preferences BEFORE send OTP
      // Capture early to ensure we have guest data even if state changes later
      final currentUser = ref.read(userStateProvider).user;
      final guestLevel = currentUser?.languageLevel;
      final guestVariant = currentUser?.englishVariant;
      final guestStreakSnapshot = currentUser == null
          ? null
          : <String, dynamic>{
              'currentStreak': currentUser.currentStreak,
              'longestStreak': currentUser.longestStreak,
              'shields': currentUser.shields,
              'lastStreakActivityDate':
                  currentUser.lastStreakActivityDate?.toIso8601String(),
              'streakStateUpdatedAt':
                  currentUser.streakStateUpdatedAt?.toIso8601String(),
              'badges': currentUser.badges,
            };

      debugPrint(
          '📝 Guest preferences captured for email flow: level=$guestLevel, variant=$guestVariant');

      // Send OTP first, then navigate
      final authService = ref.read(authServiceProvider);
      await authService.sendOtp(email);

      if (!context.mounted) return;
      SnackBarHelper.success(context, 'OTP sent to $email');

      // Close bottom sheet before navigating
      if (context.mounted) {
        Navigator.of(context).pop(); // Close bottom sheet
      }

      // Navigate to OTP page after successful send (with guest preferences)
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationPage(
              email: email,
              displayName: null,
              languageLevel: guestLevel,
              englishVariant: guestVariant,
              guestStreakSnapshot: guestStreakSnapshot,
              isGuestCreatingAccount: true,
            ),
          ),
        );
      }
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
  ) {
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
        languageLevel: guestLevel,
        englishVariant: guestVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: !_isGoogleLoading,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 20 + keyboardHeight,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              const AppBottomSheetDragHandle(),
              const SizedBox(height: 18),

              // Header
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text(
                    'Create an account',
                    style: GoogleFonts.lexend(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              Text(
                'Continue with your progress',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: DesignTokens.textMuted,
                ),
              ),
              const SizedBox(height: 18),

              // Reusable AuthForm
              AuthForm(
                onGoogleTap: () => _continueWithGoogle(context),
                onEmailTap: () => _continueWithEmail(context),
                emailController: _emailController,
                emailFormKey: _emailFormKey,
                isEmailLoading: _isEmailLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
