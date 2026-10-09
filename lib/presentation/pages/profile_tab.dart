import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/utils/safe_image_picker.dart';
import '../../core/utils/image_picker_error_message.dart';
import '../../constants/app_defaults.dart';
import '../../constants/design_tokens.dart';
import '../../utils/snackbar_helper.dart';
import '../providers/auth_provider.dart' as auth;
import '../providers/providers.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/profile_repository.dart';
import 'onboarding_page.dart';
import 'language_selection_page.dart';
import 'english_variant_page.dart';
import 'auth/account_method_page.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';
import '../widgets/permission_required_dialog.dart';
import '../widgets/tokenized_notice_dialogs.dart';
import '../widgets/start_over_dialog_details.dart';
import '../widgets/streak_info_dialogs.dart';
import '../widgets/common/profile_widgets.dart';
import '../widgets/badges_section.dart';
import '../widgets/app_loading_widgets.dart';
import '../../core/services/notification_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ProfileRepository provider
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    authService: ref.watch(authServiceProvider),
    hiveService: ref.watch(hiveServiceProvider),
    vocabSyncService: ref.watch(vocabularySyncServiceProvider),
    streakService: ref.watch(streakServiceProvider),
    appStateService: ref.watch(appStateServiceProvider),
    supabaseClient: Supabase.instance.client,
  );
});

BoxDecoration _profileSectionDecoration() => BoxDecoration(
      color: DesignTokens.surfacePrimary,
      borderRadius: BorderRadius.circular(DesignTokens.radiusCircular),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );

BoxDecoration _profileBackgroundDecoration() => const BoxDecoration(
      gradient: DesignTokens.pageHeaderGradient,
    );

Future<bool> _showProfileConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  required String confirmLabel,
  Widget? iconWidget,
  Widget? content,
  TextAlign messageTextAlign = TextAlign.center,
  double contentBottomSpacing = DesignTokens.dialogActionsSpacing,
  Color accentColor = DesignTokens.dialogWarning,
  Color? accentTint,
  bool primaryOutlined = false,
  bool barrierDismissible = true,
}) async {
  var confirmed = false;
  await showTokenizedActionDialog(
    context,
    title: title,
    message: message,
    icon: icon,
    iconWidget: iconWidget,
    content: content,
    messageTextAlign: messageTextAlign,
    contentBottomSpacing: contentBottomSpacing,
    primaryLabel: confirmLabel,
    onPrimary: () => confirmed = true,
    secondaryLabel: 'Cancel',
    onSecondary: () => confirmed = false,
    accentColor: accentColor,
    accentTint: accentTint,
    primaryOutlined: primaryOutlined,
    barrierDismissible: barrierDismissible,
  );
  return confirmed;
}

class _ProfileHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ProfileHeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF3F4F6),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: DesignTokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _isGuestMode = false;
  bool _isCheckingGuest = true;

  @override
  void initState() {
    super.initState();
    _checkGuestMode();

    // ฟัง auth state เมื่อ logout จะ reload ทันที
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _checkGuestMode();
      }
    });
  }

  Future<void> _checkGuestMode() async {
    // Check if user is guest from UserModel (single source of truth)
    final user = ref.read(userStateProvider).user;
    if (mounted) {
      setState(() {
        _isGuestMode = user?.isGuest ?? true; // Default to guest if no user
        _isCheckingGuest = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(auth.currentUserProvider);

    if (_isCheckingGuest) {
      return const Scaffold(body: Center(child: StarLoadingIndicator()));
    }

    return Scaffold(
      body: user == null
          ? _NotLoggedInView(isGuestMode: _isGuestMode)
          : _LoggedInView(user: user),
    );
  }
}

// ==================== STREAK SECTION ====================

class _StreakSection extends ConsumerWidget {
  const _StreakSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakData = ref.watch(streakProvider);
    final currentStreak = streakData?.currentStreak ?? 0;
    final shields = streakData?.shieldsAvailable ?? 0;

    final consecutiveDays = streakData?.consecutiveDays ?? 0;

    // Calculate days until next shield
    final daysUntilShield = consecutiveDays == 0 ? 7 : 7 - consecutiveDays;

    // Get motivation message based on streak
    String getMotivationMessage() {
      if (currentStreak == 0) return 'Start your streak today!';
      if (currentStreak == 1) return 'Great start! Keep going!';
      if (currentStreak < 7) return "You're doing great!";
      if (currentStreak < 30) return 'You\'re on fire! 🔥';
      return 'Amazing! Legendary streak! 🏆';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: _profileSectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: DesignTokens.brandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'STREAK',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6),
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                // Shield badge
                GestureDetector(
                  onTap: () => showShieldInfoDialog(context, shields),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FaIcon(FontAwesomeIcons.shieldHalved,
                            size: 18, color: Color(0xFFFF7A51)),
                        const SizedBox(width: 2),
                        Text(
                          '$shields',
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF221F33),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main content: Streak number and motivation message
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => showStreakInfoDialog(context, currentStreak),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    // Big streak number with fire icon
                    Icon(
                      Icons.local_fire_department,
                      size: 36,
                      color: currentStreak == 0
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFFFF6B6B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$currentStreak',
                      style: GoogleFonts.lexend(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: currentStreak == 0
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF1f2937),
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentStreak == 1 ? 'day' : 'days',
                            style: GoogleFonts.lexend(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            getMotivationMessage(),
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Shield progress text
                          Text(
                            daysUntilShield == 0
                                ? 'Shield earned! 🎉'
                                : '$daysUntilShield ${daysUntilShield == 1 ? 'day' : 'days'} to next shield',
                            style: GoogleFonts.lexend(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                // Background
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5E7EB),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                // Progress
                                FractionallySizedBox(
                                  widthFactor: consecutiveDays / 7,
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF7A51),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== PREFERENCES SECTION ====================
class _PreferencesSection extends ConsumerStatefulWidget {
  final String languageLevel;
  final String englishVariant;
  final bool isGuest;
  final VoidCallback? onPreferenceChanged;

  const _PreferencesSection({
    required this.languageLevel,
    required this.englishVariant,
    required this.isGuest,
    this.onPreferenceChanged,
  });

  @override
  ConsumerState<_PreferencesSection> createState() =>
      _PreferencesSectionState();
}

class _PreferencesSectionState extends ConsumerState<_PreferencesSection> {
  late String _currentLevel;
  late String _currentVariant;
  bool _notificationEnabled = false;
  String _reminderTime = '20:00';

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.languageLevel;
    _currentVariant = widget.englishVariant;
    final currentUser = ref.read(userStateProvider).user;
    if (currentUser != null) {
      _notificationEnabled =
          currentUser.preferences['notificationEnabled'] as bool? ?? false;
      _reminderTime =
          currentUser.preferences['reviewReminderTime'] as String? ?? '20:00';
    }
    _reloadFromSource();
  }

  @override
  void didUpdateWidget(_PreferencesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageLevel != widget.languageLevel ||
        oldWidget.englishVariant != widget.englishVariant) {
      setState(() {
        _currentLevel = widget.languageLevel;
        _currentVariant = widget.englishVariant;
      });
    }
  }

  Future<void> _reloadFromSource() async {
    final currentUser = ref.read(userStateProvider).user;
    if (currentUser != null && mounted) {
      setState(() {
        _currentLevel = currentUser.languageLevel;
        _currentVariant = currentUser.englishVariant;
        _notificationEnabled =
            currentUser.preferences['notificationEnabled'] as bool? ?? false;
        _reminderTime =
            currentUser.preferences['reviewReminderTime'] as String? ?? '20:00';
      });
    }
  }

  String get variantName =>
      _currentVariant == 'UK' ? 'British English' : 'American English';
  String get variantFlag => _currentVariant == 'UK' ? '🇬🇧' : '🇺🇸';

  String _formatDisplayTime(String time24) {
    try {
      final parts = time24.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final h = hour % 12 == 0 ? 12 : hour % 12;
      final m = minute.toString().padLeft(2, '0');
      return '$h:$m $period';
    } catch (_) {
      return time24;
    }
  }

  Future<void> _toggleNotification(bool enabled) async {
    if (enabled && !kIsWeb) {
      // Check if permission is already granted before requesting
      final alreadyGranted = await NotificationService.instance.isPermissionGranted();
      if (!alreadyGranted) {
        final granted = await NotificationService.instance.requestPermission();
        if (!granted) {
          if (mounted) {
            showPermissionRequiredDialog(context, 'Notification');
          }
          return;
        }
      }
    }

    setState(() {
      _notificationEnabled = enabled;
    });

    final userNotifier = ref.read(userStateProvider.notifier);
    await userNotifier.updatePreferences({
      'notificationEnabled': enabled,
    });

    if (enabled) {
      final parts = _reminderTime.split(':');
      final hour = int.tryParse(parts[0]) ?? 20;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      final reviewService = ref.read(reviewServiceProvider);
      final streak = ref.read(streakProvider)?.currentStreak ??
          ref.read(userStateProvider).user?.currentStreak ??
          ref.read(currentStreakProvider);

      await NotificationService.instance.scheduleDailyReminder(
        hour: hour,
        minute: minute,
        reviewService: reviewService,
        currentStreak: streak ?? 0,
      );
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }

    widget.onPreferenceChanged?.call();
  }

  Future<void> _pickReminderTime() async {
    final parts = _reminderTime.split(':');
    final initialHour = int.tryParse(parts[0]) ?? 20;
    final initialMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

    // Track selected time inside the dialog
    DateTime pickerTime = DateTime(2000, 1, 1, initialHour, initialMinute);

    const accentColor = DesignTokens.brandColor;
    const accentTint = DesignTokens.dialogBrandTint;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.dialogRadius),
          ),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.dialogInsetHorizontal,
            vertical: DesignTokens.dialogInsetVertical,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.dialogPaddingHorizontal,
              vertical: DesignTokens.dialogPaddingVertical,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: DesignTokens.dialogIconSize,
                  height: DesignTokens.dialogIconSize,
                  decoration: const BoxDecoration(
                    color: accentTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: accentColor,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.dialogIconTitleSpacing),
                // Title
                Text(
                  'Reminder Time',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: DesignTokens.dialogTitleFontSize,
                    fontWeight: DesignTokens.weightSemiBold,
                    color: DesignTokens.dialogTitleColor,
                  ),
                ),
                const SizedBox(height: DesignTokens.dialogCompactTitleBodySpacing),
                Text(
                  'Choose when to receive your daily vocab reminder.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: DesignTokens.dialogBodyFontSize,
                    height: DesignTokens.dialogBodyLineHeight,
                    fontWeight: FontWeight.w400,
                    color: DesignTokens.dialogSupportingTextColor,
                  ),
                ),
                const SizedBox(height: DesignTokens.dialogTitleBodySpacing),
                // Cupertino scroll wheel
                SizedBox(
                  height: 160,
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: DesignTokens.textPrimary,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: pickerTime,
                      use24hFormat: false,
                      onDateTimeChanged: (dt) {
                        setDialogState(() => pickerTime = dt);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.dialogActionsSpacing),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: DesignTokens.dialogButtonHeight,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DesignTokens.dialogDisabledActionColor,
                            side: const BorderSide(
                              color: DesignTokens.dialogDisabledActionBorderColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DesignTokens.dialogButtonRadius,
                              ),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.lexend(
                              fontSize: DesignTokens.dialogButtonFontSize,
                              fontWeight: DesignTokens.weightBold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: DesignTokens.dialogButtonHeight,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, pickerTime),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DesignTokens.dialogButtonRadius,
                              ),
                            ),
                          ),
                          child: Text(
                            'Confirm',
                            style: GoogleFonts.lexend(
                              fontSize: DesignTokens.dialogButtonFontSize,
                              fontWeight: DesignTokens.weightBold,
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

    if (picked != null) {
      final newTimeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _reminderTime = newTimeStr;
      });

      final userNotifier = ref.read(userStateProvider.notifier);
      await userNotifier.updatePreferences({
        'reviewReminderTime': newTimeStr,
      });

      if (_notificationEnabled) {
        final reviewService = ref.read(reviewServiceProvider);
        final streak = ref.read(streakProvider)?.currentStreak ??
            ref.read(userStateProvider).user?.currentStreak ??
            ref.read(currentStreakProvider);

        await NotificationService.instance.scheduleDailyReminder(
          hour: picked.hour,
          minute: picked.minute,
          reviewService: reviewService,
          currentStreak: streak ?? 0,
        );
      }

      widget.onPreferenceChanged?.call();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: _profileSectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: DesignTokens.brandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'YOUR PREFERENCES',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Language Level
          ProfileCompactItem(
            icon: Icons.school_outlined,
            title: 'Language Level',
            value: _currentLevel,
            showDivider: true,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LanguageSelectionPage(
                    isGuest: widget.isGuest,
                    isEditing: true,
                    isInitialSetup: false,
                    currentLevel: _currentLevel,
                  ),
                ),
              );
              widget.onPreferenceChanged?.call();
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),

          // English Variant
          ProfileCompactItem(
            icon: Icons.public,
            iconText: variantFlag,
            title: 'English Variant',
            value: variantName,
            showDivider: true,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EnglishVariantPage(
                    isGuest: widget.isGuest,
                    isEditing: true,
                    isInitialSetup: false,
                    currentVariant: _currentVariant,
                  ),
                ),
              );
              widget.onPreferenceChanged?.call();
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),

          // Daily Learning Reminder Toggle
          ProfileSwitchItem(
            icon: Icons.notifications_active_outlined,
            title: 'Daily Reminder',
            subtitle: 'Get glanceable daily vocab & streak updates',
            value: _notificationEnabled,
            onChanged: _toggleNotification,
            showDivider: _notificationEnabled,
            iconBgColor: DesignTokens.dialogBrandTint,
          ),

          // Reminder Time (Visible when enabled)
          if (_notificationEnabled)
            ProfileCompactItem(
              icon: Icons.access_time_rounded,
              title: 'Reminder Time',
              value: _formatDisplayTime(_reminderTime),
              showDivider: false,
              onTap: _pickReminderTime,
              iconBgColor: DesignTokens.dialogBrandTint,
            ),
        ],
      ),
    );
  }
}

// ==================== GUEST DATA SECTION ====================
class _GuestDataSection extends ConsumerWidget {
  const _GuestDataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: _profileSectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: DesignTokens.brandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'DATA (Guest Mode)',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Start Over
          ProfileCompactItem(
            icon: Icons.refresh,
            title: 'Start Over',
            subtitle: 'Reset learning progress (keep settings)',
            showDivider: true,
            onTap: () async {
              final confirmed = await _showProfileConfirmation(
                context,
                title: 'Start Over',
                message: 'This will reset your learning progress.',
                icon: Icons.restart_alt_rounded,
                confirmLabel: 'Start Over',
                content: const StartOverDialogDetails(),
                contentBottomSpacing: DesignTokens.spacingMedium,
                accentColor: DesignTokens.dialogDanger,
                accentTint: DesignTokens.dialogDangerTint,
                primaryOutlined: true,
              );

              if (confirmed == true && context.mounted) {
                final repository = ref.read(profileRepositoryProvider);
                final result = await repository.startOver(UserType.guest);

                if (context.mounted) {
                  if (result.success && result.data != null) {
                    // Update user state with fresh guest user
                    await ref
                        .read(userStateProvider.notifier)
                        .updateUser(result.data!);
                    // Refresh streak to update UI after reset
                    await ref.read(streakProvider.notifier).refresh();
                    SnackBarHelper.success(context, 'Learning progress reset');
                  } else if (result.error?.contains('Streak reset failed') ==
                      true) {
                    SnackBarHelper.warning(context,
                        result.error ?? 'Reset failed. Please try again.');
                  } else {
                    SnackBarHelper.error(
                        context,
                        result.error ??
                            'Failed to reset progress. Please try again.');
                  }
                }
              }
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),

          // Export Vocabulary
          ProfileCompactItem(
            icon: Icons.download_outlined,
            title: 'Export Vocabulary',
            subtitle: 'Download your vocabulary list',
            showDivider: false,
            onTap: () async {
              print('🔘 Export Vocabulary button pressed');
              final repository = ref.read(profileRepositoryProvider);
              final result = await repository.exportVocabulary(UserType.guest);

              if (context.mounted) {
                if (result.success) {
                  SnackBarHelper.success(
                      context, 'Vocabulary exported (${result.data} words)');
                } else if (result.error != 'Export cancelled.') {
                  SnackBarHelper.info(
                      context, result.error ?? 'No vocabulary to export yet');
                }
              }
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),
        ],
      ),
    );
  }
}

// ==================== DATA MANAGEMENT SECTION ====================
class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: _profileSectionDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: DesignTokens.brandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'DATA',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Start Over
          ProfileCompactItem(
            icon: Icons.refresh,
            title: 'Start Over',
            subtitle: 'Reset learning progress (keep settings)',
            showDivider: true,
            onTap: () async {
              final confirmed = await _showProfileConfirmation(
                context,
                title: 'Start Over',
                message: 'This will reset your learning progress.',
                icon: Icons.restart_alt_rounded,
                confirmLabel: 'Start Over',
                content: const StartOverDialogDetails(),
                contentBottomSpacing: DesignTokens.spacingMedium,
                accentColor: DesignTokens.dialogDanger,
                accentTint: DesignTokens.dialogDangerTint,
                primaryOutlined: true,
              );

              if (confirmed == true && context.mounted) {
                final repository = ref.read(profileRepositoryProvider);
                final result = await repository.startOver(UserType.registered);

                if (context.mounted) {
                  if (result.success && result.data != null) {
                    // Update user state with updated user
                    await ref
                        .read(userStateProvider.notifier)
                        .updateUser(result.data!);
                    // Refresh streak to update UI after reset
                    await ref.read(streakProvider.notifier).refresh();
                    SnackBarHelper.success(context, 'Learning progress reset');
                  } else if (result.error?.contains('Streak reset failed') ==
                          true ||
                      result.error?.contains('Cloud sync') == true) {
                    SnackBarHelper.warning(context,
                        result.error ?? 'Reset failed. Please try again.');
                  } else {
                    SnackBarHelper.error(
                        context,
                        result.error ??
                            'Failed to reset progress. Please try again.');
                  }
                }
              }
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),

          // Export Vocabulary
          ProfileCompactItem(
            icon: Icons.download_outlined,
            title: 'Export Vocabulary',
            subtitle: 'Download your vocabulary list',
            showDivider: true,
            onTap: () async {
              print('🔘 Export Vocabulary button pressed (registered)');
              final repository = ref.read(profileRepositoryProvider);
              final result =
                  await repository.exportVocabulary(UserType.registered);

              if (context.mounted) {
                if (result.success) {
                  SnackBarHelper.success(
                      context, 'Vocabulary exported (${result.data} words)');
                } else if (result.error != 'Export cancelled.') {
                  SnackBarHelper.info(
                      context, result.error ?? 'No vocabulary to export yet');
                }
              }
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),

          // Clear Cache
          ProfileCompactItem(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Cache',
            subtitle: 'Free up storage space',
            showDivider: false,
            onTap: () async {
              final repository = ref.read(profileRepositoryProvider);
              final result = await repository.clearCache();

              if (context.mounted) {
                if (result.success) {
                  SnackBarHelper.success(context, 'Cache cleared successfully');
                } else {
                  SnackBarHelper.error(
                      context, result.error ?? 'Failed to clear cache');
                }
              }
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),
        ],
      ),
    );
  }
}

// ==================== ACCOUNT SECTION ====================
class _AccountSection extends ConsumerWidget {
  final VoidCallback onDeleteAccount;

  const _AccountSection({required this.onDeleteAccount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  'ACCOUNT',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Delete Account
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDeleteAccount,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_forever,
                        size: 20,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete Account',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Permanently delete your account',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: Colors.red.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ABOUT SECTION ====================
class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCircular),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: DesignTokens.brandColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'ABOUT',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // About App
          ProfileCompactItem(
            icon: Icons.info_outline,
            title: 'About App',
            subtitle: 'App information',
            showDivider: true,
            onTap: () {
              _showAboutDialog(context);
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),

          // Privacy Policy
          ProfileCompactItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            showDivider: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),

          // Terms of Service
          ProfileCompactItem(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'Rules and guidelines',
            showDivider: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
              );
            },
            iconBgColor: DesignTokens.dialogBrandTint,
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => _AboutDialog());
  }
}

// ==================== ABOUT DIALOG ====================
class _AboutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.dialogRadius),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.dialogInsetHorizontal,
        vertical: DesignTokens.dialogInsetVertical,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.dialogPaddingHorizontal,
          vertical: DesignTokens.dialogPaddingVertical,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/mascots/about_mascot.png',
                width: 112,
                height: 112,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text(
                'Starmory',
                style: GoogleFonts.cormorantUnicase(
                  fontSize: 26,
                  fontWeight: DesignTokens.weightBold,
                  color: DesignTokens.dialogTitleColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: DesignTokens.dialogInfoTint, width: 1.5),
                ),
                child: Text(
                  'Version 1.0.0',
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: DesignTokens.weightSemiBold,
                    color: DesignTokens.dialogInfo,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Starmory helps you learn English vocabulary by turning your personal photos into meaningful learning memories.',
                textAlign: TextAlign.left,
                style: GoogleFonts.lexend(
                  fontSize: 15,
                  height: 1.55,
                  color: DesignTokens.dialogTitleColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Stickers designed by Magnific from Flaticon',
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                  fontSize: 11,
                  color: DesignTokens.dialogSupportingTextColor,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: DesignTokens.dialogButtonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: DesignTokens.dialogInfo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.dialogButtonRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.lexend(
                      fontSize: DesignTokens.dialogButtonFontSize,
                      fontWeight: DesignTokens.weightSemiBold,
                    ),
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

// ==================== NOT LOGGED IN VIEW ====================
class _NotLoggedInView extends ConsumerStatefulWidget {
  final bool isGuestMode;

  const _NotLoggedInView({required this.isGuestMode});

  @override
  ConsumerState<_NotLoggedInView> createState() => _NotLoggedInViewState();
}

class _NotLoggedInViewState extends ConsumerState<_NotLoggedInView> {
  String? _guestLanguageLevel;
  String? _guestEnglishVariant;

  @override
  void initState() {
    super.initState();
    if (widget.isGuestMode) {
      _loadGuestPreferences();
    }
  }

  Future<void> _loadGuestPreferences() async {
    // Load from UserModel instead of SharedPreferences
    final currentUser = ref.read(userStateProvider).user;
    if (currentUser != null && mounted) {
      setState(() {
        _guestLanguageLevel = currentUser.languageLevel;
        _guestEnglishVariant = currentUser.englishVariant;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _profileBackgroundDecoration(),
        child: Column(
          children: [
            // Guest Header
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  children: [
                    // Top bar with back button and Guest badge
                    Row(
                      children: [
                        _ProfileHeaderIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Back',
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        // Guest User badge (moved here)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE2D1F9,
                            ).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFF8B5CF6,
                              ).withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Color(0xFF1f2937),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Guest User',
                                style: TextStyle(
                                  color: Color(0xFF1f2937),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spacingSmall),

                    // Register Prompt Card
                    Container(
                      width: double.infinity,
                      height: 172,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_sync_outlined,
                            size: 32,
                            color: const Color(0xFF8B5CF6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Save your progress',
                            style: GoogleFonts.lexend(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1f2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Continue your journey anywhere',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(
                                0xFF1f2937,
                              ).withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          // Match the purple CTA style used on Home.
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B5CF6),
                                    Color(0xFF7C3AED),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7C3AED,
                                    ).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    AccountMethodPage.show(context);
                                  },
                                  borderRadius: BorderRadius.circular(30),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.person_add,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Create Account',
                                        style: GoogleFonts.lexend(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacingBase),
                  ],
                ),
              ),
            ),

            // All Sections
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 40),
                  child: Column(
                    children: [
                      // Streak Section
                      const _StreakSection(),
                      const SizedBox(height: 8),

                      // Badges Section
                      const BadgesSection(),
                      const SizedBox(height: 8),

                      // Preferences Section
                      _PreferencesSection(
                        languageLevel: _guestLanguageLevel ??
                            AppDefaults.defaultLanguageLevel,
                        englishVariant: _guestEnglishVariant ??
                            AppDefaults.defaultEnglishVariant,
                        isGuest: true,
                        onPreferenceChanged: _loadGuestPreferences,
                      ),

                      // Guest Data Section
                      const _GuestDataSection(),

                      // About Section
                      const _AboutSection(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== LOGGED IN VIEW ====================
class _LoggedInView extends ConsumerStatefulWidget {
  final User user;

  const _LoggedInView({required this.user});

  @override
  ConsumerState<_LoggedInView> createState() => _LoggedInViewState();
}

class _LoggedInViewState extends ConsumerState<_LoggedInView> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final authService = ref.read(authServiceProvider);
    final data = await authService.fetchUserData(widget.user.id);
    if (mounted) {
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fallback to metadata if data not loaded yet
    final displayName = _userData?['display_name'] ??
        widget.user.userMetadata?['display_name'] ??
        'User';
    final email = widget.user.email ?? '';
    final languageLevel = _userData?['language_level'] ??
        widget.user.userMetadata?['language_level'] ??
        AppDefaults.defaultLanguageLevel;
    final englishVariant = _userData?['english_variant'] ??
        widget.user.userMetadata?['english_variant'] ??
        AppDefaults.defaultEnglishVariant;

    // Get avatar URL from database or Google (fallback)
    final rawAvatarUrl = _userData?['avatar_url'] ??
        widget.user.userMetadata?['avatar_url'] ??
        widget.user.userMetadata?['picture'];

    final avatarUrl = rawAvatarUrl != null
        ? '$rawAvatarUrl?t=${DateTime.now().millisecondsSinceEpoch}'
        : null;

    if (_isLoading) {
      return const Scaffold(body: Center(child: StarLoadingIndicator()));
    }

    return Scaffold(
      body: Container(
        decoration: _profileBackgroundDecoration(),
        child: Column(
          children: [
            // Profile Header
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  children: [
                    // Top bar with back and logout buttons
                    Row(
                      children: [
                        _ProfileHeaderIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          tooltip: 'Back',
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _ProfileHeaderIconButton(
                          icon: Icons.logout_rounded,
                          tooltip: 'Log out',
                          onPressed: () => _showLogoutDialog(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.spacingSmall),
                    // Account identity card
                    Container(
                      width: double.infinity,
                      height: 172,
                      padding: const EdgeInsets.all(DesignTokens.spacingLarge),
                      decoration: BoxDecoration(
                        color: DesignTokens.surfacePrimary,
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusXLarge),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _showAvatarPicker(
                              context,
                              displayName,
                              avatarUrl,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: const Color(0xFFF1EDFF),
                                  backgroundImage: avatarUrl != null
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl == null
                                      ? Text(
                                          displayName
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: GoogleFonts.lexend(
                                            fontSize: 27,
                                            fontWeight: DesignTokens.weightBold,
                                            color: DesignTokens.dialogBrand,
                                          ),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: DesignTokens.dialogBrand,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacingMedium),
                          GestureDetector(
                            onTap: () => _showDisplayNameDialog(
                              context,
                              ref,
                              displayName,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width - 112,
                                  ),
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.lexend(
                                      fontSize: 18,
                                      fontWeight: DesignTokens.weightSemiBold,
                                      color: DesignTokens.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: DesignTokens.spacingSmall,
                                ),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 15,
                                  color: DesignTokens.textMuted,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacingBase),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              color: DesignTokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacingBase),
                  ],
                ),
              ),
            ),

            // All Sections
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 40),
                  child: Column(
                    children: [
                      // Streak Section
                      const _StreakSection(),
                      const SizedBox(height: 8),

                      // Badges Section
                      const BadgesSection(),
                      const SizedBox(height: 8),

                      // Preferences Section
                      _PreferencesSection(
                        languageLevel: languageLevel,
                        englishVariant: englishVariant,
                        isGuest: false,
                        onPreferenceChanged: _fetchUserData,
                      ),

                      // Data Section
                      const _DataSection(),

                      // About Section
                      const _AboutSection(),

                      // Account Section (moved to bottom for safety)
                      _AccountSection(
                        onDeleteAccount: () =>
                            _showDeleteAccountDialog(context, ref),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDisplayNameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentDisplayName,
  ) async {
    final controller = TextEditingController(text: currentDisplayName);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _DisplayNameDialog(controller: controller, formKey: formKey),
    );

    if (result == true && formKey.currentState?.validate() == true) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty && newName != currentDisplayName) {
        final repository = ref.read(profileRepositoryProvider);
        final updateResult = await repository.updateDisplayName(newName);

        if (context.mounted) {
          if (updateResult.success) {
            SnackBarHelper.success(context, AlertMessages.changesSaved);
            // Refresh userState so home page shows updated name
            await ref
                .read(userStateProvider.notifier)
                .refreshUserFromSupabase();
            _fetchUserData();
          } else {
            SnackBarHelper.error(
                context, updateResult.error ?? AlertMessages.saveFailed);
          }
        }
      }
    }
  }

  Future<void> _showAvatarPicker(
    BuildContext context,
    String displayName,
    String? currentAvatarUrl,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _AvatarPickerDialog(
        currentAvatarUrl: currentAvatarUrl,
        displayName: displayName,
      ),
    );

    if (result == null && !context.mounted) return;

    try {
      if (result == 'remove') {
        await _removeAvatar(context);
      } else if (result == 'camera' || result == 'gallery') {
        final ImageSource source =
            result == 'camera' ? ImageSource.camera : ImageSource.gallery;
        await _pickAndUploadAvatar(context, source);
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, 'Failed to update profile photo');
      }
    }
  }

  Future<void> _pickAndUploadAvatar(
    BuildContext context,
    ImageSource source,
  ) async {
    if (SafeImagePicker.isPicking) return;
    try {
      // Request permissions before opening camera/gallery
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (context.mounted) {
            _showPermissionDialog(context, 'Camera');
          }
          return;
        }
      } else if (source == ImageSource.gallery) {
        final photoStatus = await Permission.photos.request();
        if (!photoStatus.isGranted) {
          if (context.mounted) {
            _showPermissionDialog(context, 'Photo Library');
          }
          return;
        }
      }

      final pickedFile = await SafeImagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      if (!context.mounted) return;

      // Validate file format - only JPEG and PNG supported
      final pathLower = pickedFile.path.toLowerCase();
      if (pathLower.endsWith('.gif') ||
          pathLower.endsWith('.webp') ||
          pathLower.endsWith('.bmp') ||
          pickedFile.mimeType == 'image/gif' ||
          pickedFile.mimeType == 'image/webp' ||
          pickedFile.mimeType == 'image/bmp') {
        if (context.mounted) {
          _showUnsupportedFormatDialog(context);
        }
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: StarLoadingIndicator(size: 48),
        ),
      );

      final imageFile = File(pickedFile.path);
      final repository = ref.read(profileRepositoryProvider);
      final result = await repository.uploadProfilePhoto(imageFile, source);

      if (context.mounted) {
        Navigator.of(context).pop();
        if (result.success) {
          SnackBarHelper.success(context, AlertMessages.changesSaved);
          _fetchUserData();
          // Wait for database update to complete, then refresh userState
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await ref
                .read(userStateProvider.notifier)
                .refreshUserFromSupabase();
          }
        } else {
          SnackBarHelper.error(
              context, result.error ?? AlertMessages.saveFailed);
        }
      }
    } on PlatformException catch (e) {
      if (e.code == 'already_active') return;
      if (context.mounted) {
        final error = e.message ?? e;
        showTokenizedErrorDialog(
          context,
          title: 'Error',
          message: ImagePickerErrorMessage.failedToPick(error),
          icon: Icons.photo_library_outlined,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showTokenizedErrorDialog(
          context,
          title: 'Error',
          message: ImagePickerErrorMessage.failedToPick(e),
          icon: Icons.photo_library_outlined,
        );
      }
    }
  }

  Future<void> _removeAvatar(BuildContext context) async {
    final repository = ref.read(profileRepositoryProvider);
    final result = await repository.removeProfilePhoto();

    if (context.mounted) {
      if (result.success) {
        SnackBarHelper.success(context, AlertMessages.changesSaved);
        _fetchUserData();
        // Wait for database update to complete, then refresh userState
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          await ref.read(userStateProvider.notifier).refreshUserFromSupabase();
        }
      } else {
        SnackBarHelper.error(context, result.error ?? AlertMessages.saveFailed);
      }
    }
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showProfileConfirmation(
      context,
      title: 'Logout',
      message: 'Are you sure you want to log out?',
      icon: Icons.logout_rounded,
      iconWidget: Image.asset(
        'assets/images/mascots/logout_mascot.png',
        width: 75,
        height: 75,
      ),
      confirmLabel: 'Logout',
      accentColor: DesignTokens.dialogBrand,
      accentTint: DesignTokens.dialogBrandTint,
      primaryOutlined: true,
      barrierDismissible: false,
    );
    if (confirmed == true && context.mounted) {
      try {
        final client = Supabase.instance.client;
        final preferenceService = ref.read(onboardingServiceProvider);
        final hiveService = ref.read(hiveServiceProvider);
        final navigator = Navigator.of(context);

        // ⭐ CRITICAL: Get GUEST QUOTA BACKUP (persists across login/logout)
        final guestQuotaBackup = await hiveService.getGuestQuotaBackup();

        // ⭐ Clear ALL local data (vocabulary, scrapbooks, word cards, user stats, preferences, photos, streak)
        await Future.wait([
          hiveService.clearAllVocabulary(),
          hiveService.clearAllScrapbooks(),
          hiveService.clearAllWordCards(),
          hiveService.clearUserStats(),
          preferenceService.clearLocalPreferences(),
          preferenceService.setOnboardingCompleted(false),
        ]);

        // Reset in-memory provider states
        ref.read(vocabularyStateProvider.notifier).clear();
        ref.read(scrapbookStateProvider.notifier).clear();
        ref.read(streakProvider.notifier).clearLocalState();
        ref.invalidate(reviewStateProvider);

        // Clear cache (photos, temporary files)
        await preferenceService.clearCache();

        // ⭐ CREATE GUEST WITH PRESERVED QUOTA FROM BACKUP
        // Device-based trial: quota persists in backup regardless of login state
        final guestUser = UserModel.createGuest();
        final guestUserToSet = guestQuotaBackup != null
            ? guestUser.copyWith(quotaManager: guestQuotaBackup)
            : guestUser;

        await hiveService.saveUser(guestUserToSet);
        if (guestQuotaBackup == null) {
          await hiveService.saveGuestQuotaBackup(guestUser.quotaManager);
        }
        ref.read(userStateProvider.notifier).updateUser(guestUserToSet);

        // Sign out from Supabase LAST
        await client.auth.signOut();

        // Navigate to Onboarding page
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const OnboardingPage(skipToAuth: true),
          ),
          (route) => false,
        );
      } catch (e) {
        if (context.mounted) {
          SnackBarHelper.error(context, AlertMessages.logoutFailed);
        }
      }
    }
  }

  Future<void> _showDeleteAccountDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Capture services and the root navigator before the destructive operation.
    final authService = ref.read(authServiceProvider);
    final preferenceService = ref.read(onboardingServiceProvider);
    final hiveService = ref.read(hiveServiceProvider);
    final streakNotifier = ref.read(streakProvider.notifier);
    final navigator = Navigator.of(context, rootNavigator: true);

    final confirmed = await _showProfileConfirmation(
      context,
      title: 'Delete Account',
      message:
          'This action cannot be undone and all your data will be permanently lost.',
      icon: Icons.delete_forever_rounded,
      confirmLabel: 'Delete',
      iconWidget: Image.asset(
        'assets/images/mascots/delete_acc_mascot.png',
        width: 65,
        height: 65,
        fit: BoxFit.contain,
      ),
      content: const _DeleteAccountWarning(),
      messageTextAlign: TextAlign.left,
      contentBottomSpacing: DesignTokens.spacingSmall,
      accentColor: DesignTokens.dialogDanger,
      accentTint: DesignTokens.dialogDangerTint,
      primaryOutlined: true,
      barrierDismissible: false,
    );
    if (confirmed == true) {
      try {
        print('🗑️ Starting account deletion...');

        // ⭐ CRITICAL: Get GUEST QUOTA BACKUP (persists across login/logout/delete)
        // This is the device-based trial quota that survives account deletion
        final guestQuotaBackup = await hiveService.getGuestQuotaBackup();

        // ⭐ Clear ALL local data (vocabulary, scrapbooks, word cards, user stats, preferences, photos, streak)
        await Future.wait([
          hiveService.clearAllVocabulary(),
          hiveService.clearAllScrapbooks(),
          hiveService.clearAllWordCards(),
          hiveService.clearUserStats(),
          preferenceService.clearLocalPreferences(),
          preferenceService.setOnboardingCompleted(false),
        ]);

        // Reset in-memory provider states
        ref.read(vocabularyStateProvider.notifier).clear();
        ref.read(scrapbookStateProvider.notifier).clear();
        streakNotifier.clearLocalState();
        ref.invalidate(reviewStateProvider);

        // Clear cache (photos, temporary files)
        await preferenceService.clearCache();

        // ⭐ CREATE GUEST WITH PRESERVED QUOTA FROM BACKUP
        // Device-based trial: quota persists in backup regardless of account status
        final guestUser = UserModel.createGuest();
        final guestUserToSet = guestQuotaBackup != null
            ? guestUser.copyWith(quotaManager: guestQuotaBackup)
            : guestUser;

        await hiveService.saveUser(guestUserToSet);
        if (guestQuotaBackup == null) {
          await hiveService.saveGuestQuotaBackup(guestUser.quotaManager);
        }
        ref.read(userStateProvider.notifier).updateUser(guestUserToSet);

        print('✅ All user data cleared, quota preserved');

        // Delete account (includes signOut → logout → will use preserved guest in Hive)
        await authService.deleteAccount();
        print('✅ Account deleted');

        // Navigate to Onboarding using captured navigator
        print('🚪 Navigating to onboarding...');
        // Use captured navigator (with rootNavigator) to ensure navigation works
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const OnboardingPage(skipToAuth: true)),
          (route) => false,
        );
      } catch (e) {
        print('❌ Delete account error: $e');

        // Stay on profile page so user can try again (consistent with logout failure)
        if (context.mounted) {
          SnackBarHelper.error(context, AlertMessages.deleteAccountFailed);
        }
      }
    }
  }

  void _showPermissionDialog(BuildContext context, String type) {
    showPermissionRequiredDialog(context, type);
  }

  void _showUnsupportedFormatDialog(BuildContext context) {
    showUnsupportedFormatDialog(context);
  }
}

// ==================== DISPLAY NAME DIALOG ====================
class _DeleteAccountWarning extends StatelessWidget {
  const _DeleteAccountWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DesignTokens.dialogDangerTint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_rounded,
            size: 18,
            color: DesignTokens.dialogDanger,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Are you sure you want to delete your account?',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogBodyFontSize,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.dialogDanger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisplayNameDialog extends StatefulWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;

  const _DisplayNameDialog({required this.controller, required this.formKey});

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
  @override
  void initState() {
    super.initState();
    // Select all text after dialog opens for easy editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final text = widget.controller.text;
      if (text.isNotEmpty) {
        widget.controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: text.length,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.dialogRadius),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.dialogInsetHorizontal,
        vertical: DesignTokens.dialogInsetVertical,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.dialogPaddingHorizontal,
          vertical: DesignTokens.dialogPaddingVertical,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: DesignTokens.dialogIconSize + 10,
                height: DesignTokens.dialogIconSize + 10,
                decoration: const BoxDecoration(
                  color: DesignTokens.dialogBrandTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_square,
                  color: DesignTokens.dialogBrand,
                  size: 38,
                ),
              ),
              const SizedBox(height: DesignTokens.dialogIconTitleSpacing),
              Text(
                'Edit Display Name',
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.dialogTitleFontSize,
                  fontWeight: DesignTokens.weightSemiBold,
                  color: DesignTokens.dialogTitleColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.dialogTitleBodySpacing),
              Text(
                'Enter your new display name',
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.dialogBodyFontSize,
                  color: DesignTokens.dialogSupportingTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Form(
                key: widget.formKey,
                child: TextFormField(
                  controller: widget.controller,
                  autofocus: true,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  onTap: () {
                    final text = widget.controller.text;
                    if (text.isNotEmpty) {
                      widget.controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: text.length,
                      );
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    counterText: '',
                    suffix: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.controller,
                      builder: (context, value, child) => Text(
                        '${value.text.length}/40',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          color: DesignTokens.dialogSupportingTextColor,
                        ),
                      ),
                    ),
                    hintStyle: GoogleFonts.lexend(
                      fontSize: DesignTokens.dialogBodyFontSize,
                      color: DesignTokens.textMuted,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: DesignTokens.dialogBrandTint,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: DesignTokens.dialogBrandTint,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: DesignTokens.dialogBrand,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: DesignTokens.dialogActionsSpacing),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: DesignTokens.dialogButtonHeight,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              DesignTokens.dialogDisabledActionColor,
                          side: const BorderSide(
                            color: DesignTokens.dialogDisabledActionBorderColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DesignTokens.dialogButtonRadius,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.lexend(
                            fontSize: DesignTokens.dialogButtonFontSize,
                            fontWeight: DesignTokens.weightSemiBold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: DesignTokens.dialogButtonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          if (widget.formKey.currentState?.validate() == true) {
                            Navigator.of(context).pop(true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: DesignTokens.dialogBrand,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DesignTokens.dialogButtonRadius,
                            ),
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.lexend(
                            fontSize: DesignTokens.dialogButtonFontSize,
                            fontWeight: DesignTokens.weightSemiBold,
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
}

// ==================== AVATAR PICKER DIALOG ====================
class _AvatarPickerDialog extends StatelessWidget {
  final String? currentAvatarUrl;
  final String displayName;

  const _AvatarPickerDialog({
    required this.currentAvatarUrl,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.dialogRadius),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 2.25,
                    child: currentAvatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: currentAvatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _avatarFallback(),
                            errorWidget: (context, url, error) =>
                                _avatarFallback(),
                          )
                        : _avatarFallback(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Change Profile Photo',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 20,
                    fontWeight: DesignTokens.weightSemiBold,
                    color: DesignTokens.dialogTitleColor,
                  ),
                ),
                const SizedBox(height: 18),
                _buildActionButton(
                  icon: Icons.camera_alt_rounded,
                  title: 'Take Photo',
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                const SizedBox(height: 10),
                _buildActionButton(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from Gallery',
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                if (currentAvatarUrl != null) ...[
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context, 'remove'),
                    icon: const Icon(Icons.delete_outline_rounded, size: 21),
                    label: Text(
                      'Remove Photo',
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        fontWeight: DesignTokens.weightSemiBold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: DesignTokens.dialogDanger,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: DesignTokens.dialogButtonHeight,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DesignTokens.dialogDisabledActionColor,
                      side: const BorderSide(
                        color: DesignTokens.dialogDisabledActionBorderColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.dialogButtonRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.lexend(
                        fontSize: DesignTokens.dialogButtonFontSize,
                        fontWeight: DesignTokens.weightSemiBold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: DesignTokens.dialogBrandTint,
        alignment: Alignment.center,
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: GoogleFonts.lexend(
            fontSize: 56,
            fontWeight: DesignTokens.weightSemiBold,
            color: DesignTokens.dialogBrand,
          ),
        ),
      );

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: DesignTokens.dialogButtonHeight,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.dialogTitleColor,
          side:
              const BorderSide(color: DesignTokens.dialogBrandTint, width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: DesignTokens.dialogTitleColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.dialogButtonFontSize,
                  fontWeight: DesignTokens.weightSemiBold,
                  color: DesignTokens.dialogTitleColor,
                ),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F2F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
