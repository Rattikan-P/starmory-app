import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_defaults.dart';
import '../../utils/snackbar_helper.dart';
import '../providers/auth_provider.dart' as auth;
import '../providers/streak_provider.dart';
import '../providers/providers.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/user_model.dart';
import '../../data/models/vocabulary_model.dart';
import '../../utils/csv_export_helper.dart';
import 'onboarding_page.dart';
import 'language_selection_page.dart';
import 'english_variant_page.dart';
import 'auth/account_method_page.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';
import '../widgets/galaxy_screen_background.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

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
    final preferenceService = ref.read(onboardingServiceProvider);
    final isGuest = await preferenceService.isGuestMode();
    if (mounted) {
      setState(() {
        _isGuestMode = isGuest;
        _isCheckingGuest = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(auth.currentUserProvider);

    if (_isCheckingGuest) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
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
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      ),
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
                    onTap: () => _showShieldInfoDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🛡️', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            '$shields',
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Color(0xFF8B5CF6),
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
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFF60A5FA),
                                      ],
                                    ),
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
          ],
        ),
    );
  }

  void _showShieldInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFf8f9ff)],
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Streak Shields',
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1f2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Don\'t let a missed day break your streak!',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6b7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildShieldInfoItem(
                        icon: Icons.shield_rounded,
                        title: 'Shield Protection',
                        description:
                            'Each shield protects your streak for 1 missed day',
                      ),
                      const SizedBox(height: 12),
                      _buildShieldInfoItem(
                        icon: Icons.star_rounded,
                        title: 'Earn Shields',
                        description:
                            'Keep learning for 7 days to earn a shield',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(14),
                        child: const Center(
                          child: Text(
                            'Got it!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }

  Widget _buildShieldInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF5E3A8E)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5E3A8E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.languageLevel;
    _currentVariant = widget.englishVariant;
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
    if (widget.isGuest) {
      // Load from UserModel instead of SharedPreferences
      final currentUser = ref.read(userStateProvider).user;
      if (currentUser != null && mounted) {
        setState(() {
          _currentLevel = currentUser.languageLevel;
          _currentVariant = currentUser.englishVariant;
        });
      }
    }
  }

  String get variantName =>
      _currentVariant == 'UK' ? 'British English' : 'American English';
  String get variantFlag => _currentVariant == 'UK' ? '🇬🇧' : '🇺🇸';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
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
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                    ),
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
          _buildCompactItem(
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
            iconBgColor: const Color(0xFFF3F4F6), // 🩶 Soft Gray (Minimal)
          ),

          // English Variant
          _buildCompactItem(
            icon: Icons.public,
            iconText: variantFlag,
            title: 'English Variant',
            value: variantName,
            showDivider: false,
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
            iconBgColor: const Color(0xFFF3F4F6), // 🩶 Soft Gray (Minimal)
          ),
        ],
      ),
    );
  }

  Widget _buildCompactItem({
    required IconData icon,
    String? iconText,
    required String title,
    required String value,
    required bool showDivider,
    required VoidCallback onTap,
    Color? iconBgColor, // Kept for compatibility but not used
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            highlightColor: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Minimal icon - no background
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: iconText != null
                        ? Text(iconText, style: const TextStyle(fontSize: 20))
                        : Icon(icon, size: 24, color: const Color(0xFF1f2937)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(
                              0xFF1f2937,
                            ).withValues(alpha: 0.65),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1f2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Animated chevron
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70, right: 16),
            child: Divider(
              height: 1,
              color: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
              thickness: 0.5,
            ),
          ),
      ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
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
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                    ),
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
          _buildCompactItem(
            icon: Icons.refresh,
            title: 'Start Over',
            subtitle: 'Reset learning progress (keep settings)',
            showDivider: true,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => _ConfirmStartOverDialog(),
              );

              if (confirmed == true && context.mounted) {
                try {
                  // Clear all vocabulary
                  final hiveService = ref.read(hiveServiceProvider);
                  await hiveService.clearAllVocabulary();

                  // Reset streak
                  await ref.read(streakProvider.notifier).reset();

                  // Clear guest data (preferences but keep language level/variant)
                  final preferenceService = ref.read(onboardingServiceProvider);
                  await preferenceService.clearGuestData();

                  // Update UserModel to reset progress (keep preferences)
                  final userNotifier = ref.read(userStateProvider.notifier);
                  final currentUser = ref.read(userStateProvider).user;
                  if (currentUser != null && currentUser.isGuest) {
                    final updatedUser = UserModel.createGuest().copyWith(
                      preferences: currentUser.preferences, // Keep language level/variant
                    );
                    await userNotifier.updateUser(updatedUser);
                  }

                  if (context.mounted) {
                    SnackBarHelper.success(context, 'Learning progress reset');
                  }
                } catch (e) {
                  if (context.mounted) {
                    SnackBarHelper.error(context, 'Failed to reset progress');
                  }
                }
              }
            },
            iconBgColor: const Color(0xFFF3F4F6), // 🩶 Soft Gray (Minimal)
          ),

          // Export Vocabulary
          _buildCompactItem(
            icon: Icons.download_outlined,
            title: 'Export Vocabulary',
            subtitle: 'Download your vocabulary list',
            showDivider: false,
            onTap: () async {
              print('🔘 Export Vocabulary button pressed');
              try {
                final hiveService = ref.read(hiveServiceProvider);
                print('📦 Getting vocabulary list...');
                final vocabularyList = await hiveService.getAllVocabulary();
                print('📦 Got ${vocabularyList.length} vocabularies');

                if (vocabularyList.isEmpty) {
                  print('⚠️ No vocabulary to export');
                  if (context.mounted) {
                    SnackBarHelper.info(context, 'No vocabulary to export yet');
                  }
                  return;
                }

                print('📤 Starting CSV export...');
                final result = await CsvExportHelper.exportVocabularyToCsv(vocabularyList);

                // Only show success message if user actually shared (not dismissed)
                if (result.status == ShareResultStatus.success) {
                  if (context.mounted) {
                    SnackBarHelper.success(context, 'Vocabulary exported (${vocabularyList.length} words)');
                  }
                }
              } catch (e) {
                print('❌ Export error: $e');
                if (context.mounted) {
                  SnackBarHelper.error(context, 'Failed to export vocabulary');
                }
              }
            },
            iconBgColor: const Color(0xFFF3F4F6), // 🩶 Soft Gray (Minimal)
          ),
        ],
      ),
    );
  }

  Widget _buildCompactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showDivider,
    required VoidCallback onTap,
    Color? iconBgColor, // Kept for compatibility but not used
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            highlightColor: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Minimal icon - no background
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(icon, size: 24, color: const Color(0xFF1f2937)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1f2937),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(
                              0xFF1f2937,
                            ).withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Animated chevron
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70, right: 16),
            child: Divider(
              height: 1,
              color: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
              thickness: 0.5,
            ),
          ),
      ],
    );
  }
}

// ==================== CONFIRM START OVER DIALOG ====================
class _ConfirmStartOverDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFf8f9ff)],
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Start Over',
                style: GoogleFonts.lexend(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This will reset your learning progress.',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6b7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildConfirmInfoItem(
                      icon: Icons.menu_book_rounded,
                      title: 'Vocabulary Deleted',
                      description: 'All saved words will be removed',
                    ),
                    const SizedBox(height: 12),
                    _buildConfirmInfoItem(
                      icon: Icons.analytics_rounded,
                      title: 'Progress Reset',
                      description: 'Learning progress will be reset to zero',
                    ),
                    const SizedBox(height: 12),
                    _buildConfirmInfoItem(
                      icon: Icons.local_fire_department_rounded,
                      title: 'Streak Cleared',
                      description: 'Your streak and shields will be reset',
                    ),
                    const SizedBox(height: 12),
                    _buildConfirmInfoItem(
                      icon: Icons.lightbulb_rounded,
                      title: 'Settings Kept',
                      description:
                          'Language level and variant will be preserved',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                            color: const Color(
                              0xFF9ca3af,
                            ).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
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
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFF6B6B,
                              ).withValues(alpha: 0.4),
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
                            child: Center(
                              child: Text(
                                'Start Over',
                                style: GoogleFonts.lexend(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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

  Widget _buildConfirmInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFFDC2626)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
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
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                    ),
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

          // Export Vocabulary
          _buildCompactItem(
            icon: Icons.download_outlined,
            title: 'Export Vocabulary',
            subtitle: 'Download your vocabulary list',
            showDivider: true,
            onTap: () async {
              print('🔘 Export Vocabulary button pressed (registered)');
              try {
                List<VocabularyModel> vocabularyList;
                final vocabSyncService = ref.read(vocabularySyncServiceProvider);
                final hiveService = ref.read(hiveServiceProvider);

                print('📦 Fetching vocabulary from cloud...');
                vocabularyList = await vocabSyncService.fetchFromCloud();
                print('📦 Got ${vocabularyList.length} vocabularies from cloud');

                // Fallback to local if cloud is empty
                if (vocabularyList.isEmpty) {
                  print('☁️ Cloud empty, trying local...');
                  vocabularyList = await hiveService.getAllVocabulary();
                  print('📦 Got ${vocabularyList.length} vocabularies from local');
                }

                if (vocabularyList.isEmpty) {
                  print('⚠️ No vocabulary to export');
                  if (context.mounted) {
                    SnackBarHelper.info(context, 'No vocabulary to export yet');
                  }
                  return;
                }

                print('📤 Starting CSV export...');
                final result = await CsvExportHelper.exportVocabularyToCsv(vocabularyList);

                // Only show success message if user actually shared (not dismissed)
                if (result.status == ShareResultStatus.success) {
                  if (context.mounted) {
                    SnackBarHelper.success(context, 'Vocabulary exported (${vocabularyList.length} words)');
                  }
                }
              } catch (e) {
                print('❌ Export error: $e');
                if (context.mounted) {
                  SnackBarHelper.error(context, 'Failed to export vocabulary');
                }
              }
            },
            iconBgColor: const Color(0xFFF3F4F6), // 🩶 Soft Gray (Minimal)
          ),

          // Clear Cache
          _buildCompactItem(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Cache',
            subtitle: 'Free up storage space',
            showDivider: false,
            onTap: () async {
              try {
                final preferenceService = ref.read(onboardingServiceProvider);
                await preferenceService.clearCache();

                if (context.mounted) {
                  SnackBarHelper.success(context, 'Cache cleared successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  SnackBarHelper.error(context, 'Failed to clear cache');
                }
              }
            },
            iconBgColor: const Color(0xFFF3F4F6), // 🩶 Soft Gray (Minimal)
          ),
        ],
      ),
    );
  }

  Widget _buildCompactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool showDivider,
    required VoidCallback onTap,
    Color? iconBgColor, // Kept for compatibility but not used
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            highlightColor: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Minimal icon - no background
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(icon, size: 24, color: const Color(0xFF1f2937)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1f2937),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(
                              0xFF1f2937,
                            ).withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Animated chevron
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70, right: 16),
            child: Divider(
              height: 1,
              color: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
              thickness: 0.5,
            ),
          ),
      ],
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
                Text(
                  'ACCOUNT',
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('⚠️', style: TextStyle(fontSize: 14)),
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
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Colors.red.withValues(alpha: 0.6),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          width: 1,
        ),
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
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF8B5CF6), Color(0xFF60a5fa)],
                    ),
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
          _buildCompactItem(
            icon: Icons.info_outline,
            title: 'About App',
            showDivider: true,
            onTap: () {
              _showAboutDialog(context);
            },
            iconBgColor: const Color(0xFFF3F4F6), // 🩶 Soft Gray (Minimal)
          ),

          // Privacy Policy
          _buildCompactItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            showDivider: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
            iconBgColor: const Color(0xFFF3F4F6), // 🩶 Soft Gray (Minimal)
          ),

          // Terms of Service
          _buildCompactItem(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            showDivider: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
              );
            },
            iconBgColor: const Color(0xFFF3F4F6), // 🩶 Soft Gray (Minimal)
          ),
        ],
      ),
    );
  }

  Widget _buildCompactItem({
    required IconData icon,
    required String title,
    required bool showDivider,
    required VoidCallback onTap,
    Color? iconBgColor, // Kept for compatibility but not used
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            highlightColor: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Minimal icon - no background
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(icon, size: 24, color: const Color(0xFF1f2937)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1f2937),
                      ),
                    ),
                  ),
                  // Animated chevron
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70, right: 16),
            child: Divider(
              height: 1,
              color: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
              thickness: 0.5,
            ),
          ),
      ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFf8f9ff)],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App Icon/Logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF60a5fa), Color(0xFFa78bfa)],
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
                Icons.stars_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            // App Name
            Text(
              'Starmory',
              style: GoogleFonts.cormorantUnicase(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1f2937),
              ),
            ),
            const SizedBox(height: 8),

            // Tagline
            Text(
              'Learn English through your memories',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6b7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Version
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Version 1.0.0',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Starmory helps you learn English vocabulary by turning your personal photos into meaningful learning experiences.',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6b7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF60a5fa), Color(0xFFa78bfa)],
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
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(14),
                    child: const Center(
                      child: Text(
                        'Close',
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
          ],
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
      body: GalaxyScreenBackground(
        child: Column(
            children: [
              // Guest Header
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Top bar with back button and Guest badge
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Color(0xFF1f2937),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
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
                      const SizedBox(height: 16),

                      // Register Prompt Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
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
                              size: 36,
                              color: const Color(0xFF8B5CF6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Save your progress',
                              style: GoogleFonts.cormorantUnicase(
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
                            const SizedBox(height: 16),
                            // Consistent gradient button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF8B5CF6),
                                      Color(0xFF60a5fa),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AccountMethodPage(),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.person_add,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Create Account',
                                          style: TextStyle(
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
                      const SizedBox(height: 12),
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

                        // Preferences Section
                        _PreferencesSection(
                          languageLevel:
                              _guestLanguageLevel ??
                              AppDefaults.defaultLanguageLevel,
                          englishVariant:
                              _guestEnglishVariant ??
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
    final displayName =
        _userData?['display_name'] ??
        widget.user.userMetadata?['display_name'] ??
        'User';
    final email = widget.user.email ?? '';
    final languageLevel =
        _userData?['language_level'] ??
        widget.user.userMetadata?['language_level'] ??
        AppDefaults.defaultLanguageLevel;
    final englishVariant =
        _userData?['english_variant'] ??
        widget.user.userMetadata?['english_variant'] ??
        AppDefaults.defaultEnglishVariant;

    // Get avatar URL from database or Google (fallback)
    final rawAvatarUrl =
        _userData?['avatar_url'] ??
        widget.user.userMetadata?['avatar_url'] ??
        widget.user.userMetadata?['picture'];

    final avatarUrl = rawAvatarUrl != null
        ? '$rawAvatarUrl?t=${DateTime.now().millisecondsSinceEpoch}'
        : null;

    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: GalaxyScreenBackground(
        child: Column(
            children: [
              // Profile Header
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      // Top bar with back and logout buttons
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Color(0xFF1f2937),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.logout,
                                color: Color(0xFF1f2937),
                              ),
                              onPressed: () => _showLogoutDialog(context, ref),
                              tooltip: 'Logout',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Avatar - clickable to change
                      GestureDetector(
                        onTap: () =>
                            _showAvatarPicker(context, displayName, avatarUrl),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                backgroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? Text(
                                        displayName
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            // Edit icon overlay
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Name - clickable to edit
                      GestureDetector(
                        onTap: () =>
                            _showDisplayNameDialog(context, ref, displayName),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.cormorantUnicase(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1f2937),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: const Color(
                                0xFF1f2937,
                              ).withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Email
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF1f2937).withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
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
        try {
          final client = Supabase.instance.client;
          final userId = widget.user.id;

          await client.auth.updateUser(
            UserAttributes(data: {'display_name': newName}),
          );
          await client
              .from('users')
              .update({'display_name': newName})
              .eq('id', userId);

          if (context.mounted) {
            SnackBarHelper.success(context, AlertMessages.changesSaved);
          }

          _fetchUserData();
        } catch (e) {
          if (context.mounted) {
            SnackBarHelper.error(context, AlertMessages.saveFailed);
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
        final ImageSource source = result == 'camera'
            ? ImageSource.camera
            : ImageSource.gallery;
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
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      if (!context.mounted) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Upload to Supabase Storage
      final client = Supabase.instance.client;
      final userId = widget.user.id;
      final fileNameOnly = pickedFile.name;
      final fileExt = fileNameOnly.split('.').last.toLowerCase();

      String getContentType(String ext) {
        switch (ext) {
          case 'jpg':
          case 'jpeg':
            return 'image/jpeg';
          case 'png':
            return 'image/png';
          case 'gif':
            return 'image/gif';
          case 'webp':
            return 'image/webp';
          case 'bmp':
            return 'image/bmp';
          default:
            return 'image/jpeg';
        }
      }

      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
      final safeExt = validExtensions.contains(fileExt) ? fileExt : 'jpg';
      // Use same filename so it overwrites (no storage waste)
      final fileName = '${userId}_avatar.$safeExt';

      // Delete old avatar files with different extensions first
      try {
        final oldAvatarUrl = widget.user.userMetadata?['avatar_url'] as String?;
        if (oldAvatarUrl != null) {
          final urlWithoutParams = oldAvatarUrl.split('?').first;
          final oldFileName = urlWithoutParams.split('/').last;
          // Only delete if it's a different file (different extension)
          if (oldFileName != fileName) {
            try {
              await client.storage.from('avatars').remove([oldFileName]);
            } catch (e) {
              // Ignore if old file doesn't exist
            }
          }
        }
      } catch (e) {
        // Ignore if metadata fetch fails
      }

      final fileBytes = await pickedFile.readAsBytes();

      try {
        await client.storage
            .from('avatars')
            .uploadBinary(
              fileName,
              fileBytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: getContentType(fileExt),
              ),
            );
      } catch (uploadError) {
        rethrow;
      }

      // Add version parameter to URL for cache busting
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final baseUrl = client.storage.from('avatars').getPublicUrl(fileName);
      final avatarUrl = '$baseUrl?v=$timestamp';

      try {
        await client.auth.updateUser(
          UserAttributes(data: {'avatar_url': avatarUrl}),
        );
      } catch (authError) {
        rethrow;
      }

      try {
        await client
            .from('users')
            .update({'avatar_url': avatarUrl})
            .eq('id', userId);
      } catch (dbError) {
        rethrow;
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        SnackBarHelper.success(context, AlertMessages.changesSaved);
      }

      _fetchUserData();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        SnackBarHelper.error(context, AlertMessages.saveFailed);
      }
    }
  }

  Future<void> _removeAvatar(BuildContext context) async {
    try {
      final client = Supabase.instance.client;
      final userId = widget.user.id;

      final currentAvatarUrl =
          widget.user.userMetadata?['avatar_url'] as String?;
      if (currentAvatarUrl != null) {
        try {
          // Remove query parameters (e.g., ?v=123456) before getting file name
          final urlWithoutParams = currentAvatarUrl.split('?').first;
          final fileName = urlWithoutParams.split('/').last;
          await client.storage.from('avatars').remove([fileName]);
        } catch (e) {
          // Ignore if file doesn't exist
        }
      }

      await client.auth.updateUser(UserAttributes(data: {'avatar_url': null}));
      await client.from('users').update({'avatar_url': null}).eq('id', userId);

      if (context.mounted) {
        SnackBarHelper.success(context, AlertMessages.changesSaved);
      }

      _fetchUserData();
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, AlertMessages.saveFailed);
      }
    }
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFf8f9ff)],
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFf472b6), Color(0xFF60a5fa)],
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
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Logout',
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1f2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to log out?',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6b7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
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
                              color: const Color(
                                0xFF9ca3af,
                              ).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Cancel',
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
                              colors: [Color(0xFF60a5fa), Color(0xFFa78bfa)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFa78bfa,
                                ).withValues(alpha: 0.4),
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
                              child: Center(
                                child: Text(
                                  'Logout',
                                  style: GoogleFonts.lexend(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
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

    if (confirmed == true && context.mounted) {
      try {
        final client = Supabase.instance.client;
        final preferenceService = ref.read(onboardingServiceProvider);
        final hiveService = ref.read(hiveServiceProvider);
        final navigator = Navigator.of(context);

        // ⭐ Clear local data FIRST (before signout to avoid auth state listener interference)
        await Future.wait([
          hiveService.clearAllVocabulary(),
          preferenceService.clearLocalPreferences(),
          preferenceService.setGuestMode(false),
          preferenceService.setOnboardingCompleted(false),
        ]);

        // ⭐ Clear local streak state (NOT cloud) - will reload fresh from cloud on next login
        ref.read(streakProvider.notifier).clearLocalState();

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
    // ⭐ CRITICAL FIX: Capture all providers AND navigator BEFORE showing dialog
    // This prevents "Cannot use ref after widget was disposed" error
    final authService = ref.read(authServiceProvider);
    final preferenceService = ref.read(onboardingServiceProvider);
    final hiveService = ref.read(hiveServiceProvider);
    final streakNotifier = ref.read(streakProvider.notifier);
    final navigator = Navigator.of(context, rootNavigator: true);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFf8f9ff)],
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFef4444), Color(0xFFf97316)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFef4444).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Delete Account',
                  style: GoogleFonts.lexend(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1f2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone and all your data will be permanently lost.',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6b7280),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete your account?',
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFef4444),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
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
                              color: const Color(
                                0xFF9ca3af,
                              ).withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Cancel',
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
                              colors: [Color(0xFFef4444), Color(0xFFf97316)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFef4444,
                                ).withValues(alpha: 0.4),
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
                              child: Center(
                                child: Text(
                                  'Delete',
                                  style: GoogleFonts.lexend(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
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

    if (confirmed == true) {
      try {
        print('🗑️ Starting account deletion...');

        // ⭐ Clear local data FIRST (before delete to avoid auth state listener interference)
        await Future.wait([
          hiveService.clearAllVocabulary(),
          preferenceService.clearLocalPreferences(),
          preferenceService.setGuestMode(false),
          preferenceService.setOnboardingCompleted(false),
        ]);

        // Clear UserModel from Hive (this will trigger creating fresh guest on logout)
        await hiveService.clearCurrentUser();
        print('✅ UserModel cleared from Hive');

        // Clear local streak state
        streakNotifier.clearLocalState();
        print('✅ Local streak state cleared');

        // Delete account (includes signOut → logout → creates fresh guest)
        await authService.deleteAccount();
        print('✅ Account deleted, new guest created');

        // Navigate to Onboarding using captured navigator
        print('🚪 Navigating to onboarding...');
        // Use captured navigator (with rootNavigator) to ensure navigation works
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingPage(skipToAuth: true)),
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
}

// ==================== DISPLAY NAME DIALOG ====================
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFf8f9ff)],
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFf472b6), Color(0xFF60a5fa)],
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
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Edit Display Name',
                style: GoogleFonts.lexend(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your new display name',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6b7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Form(
                key: widget.formKey,
                child: TextFormField(
                  controller: widget.controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  onTap: () {
                    // Select all text when tapped for easy editing
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
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF8B5CF6),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF9ca3af),
                          side: BorderSide(
                            color: const Color(
                              0xFF9ca3af,
                            ).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Cancel',
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
                            colors: [Color(0xFF60a5fa), Color(0xFFa78bfa)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFa78bfa,
                              ).withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (widget.formKey.currentState?.validate() ==
                                  true) {
                                Navigator.of(context).pop(true);
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Center(
                              child: Text(
                                'Save',
                                style: GoogleFonts.lexend(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFf8f9ff)],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar preview with gradient glow
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8B5CF6), Color(0xFF60A5FA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.5),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: currentAvatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: currentAvatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Change Profile Photo',
              style: GoogleFonts.lexend(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1f2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a new profile picture',
              style: GoogleFonts.lexend(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6b7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Take Photo
            _buildActionButton(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            const SizedBox(height: 12),

            // Choose from Gallery
            _buildActionButton(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              onTap: () => Navigator.pop(context, 'gallery'),
            ),

            if (currentAvatarUrl != null) ...[
              const SizedBox(height: 20),
              // Remove Photo
              TextButton.icon(
                onPressed: () => Navigator.pop(context, 'remove'),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: Text(
                  'Remove Photo',
                  style: GoogleFonts.lexend(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.withValues(alpha: 0.8),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.withValues(alpha: 0.8),
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Cancel
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.lexend(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9ca3af),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Icon(icon, size: 22, color: const Color(0xFF6B7280)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.lexend(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1f2937),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: const Color(0xFFD1D5DB),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
