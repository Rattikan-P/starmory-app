import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/app_defaults.dart';
import '../../utils/snackbar_helper.dart';
import '../providers/auth_provider.dart';
import '../../data/services/auth_service.dart';
import 'onboarding_page.dart';
import 'language_selection_page.dart';
import 'english_variant_page.dart';
import 'auth/account_method_page.dart';
import 'privacy_policy_page.dart';
import 'terms_of_service_page.dart';

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
    final user = ref.watch(currentUserProvider);

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
    // TODO: Fetch actual streak data from provider/database
    final bestStreak = 30; // Placeholder
    final thisMonthDays = 25; // Placeholder

    // Generate weekly progress (Mon-Fri)
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final completedDays = [true, true, true, true, false]; // Placeholder

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFB3BA).withValues(alpha: 0.3),
            const Color(0xFFFFDFBA).withValues(alpha: 0.3),
            const Color(0xFFE2D1F9).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '🔥',
                  style: TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'STREAK DETAILS',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5E3A8E),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekly Progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Week days
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(5, (index) {
                    final isCompleted = index < completedDays.length && completedDays[index];
                    return Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFE5E7EB),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              weekDays[index].substring(0, 1),
                              style: GoogleFonts.lexend(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isCompleted ? Colors.white : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weekDays[index],
                          style: GoogleFonts.lexend(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              // Best Streak
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Best',
                              style: GoogleFonts.lexend(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$bestStreak days',
                              style: GoogleFonts.lexend(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF5E3A8E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // This Month
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Text('📊', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This month',
                              style: GoogleFonts.lexend(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$thisMonthDays days',
                              style: GoogleFonts.lexend(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF5E3A8E),
                              ),
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
  ConsumerState<_PreferencesSection> createState() => _PreferencesSectionState();
}

class _PreferencesSectionState extends ConsumerState<_PreferencesSection> {
  late String _currentLevel;
  late String _currentVariant;
  late String _currentTheme;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.languageLevel;
    _currentVariant = widget.englishVariant;
    _currentTheme = 'Light'; // TODO: Get from actual settings
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
      final preferenceService = ref.read(onboardingServiceProvider);
      final level = await preferenceService.getLanguageLevel();
      final variant = await preferenceService.getEnglishVariant();
      if (mounted) {
        setState(() {
          _currentLevel = level ?? AppDefaults.defaultLanguageLevel;
          _currentVariant = variant ?? AppDefaults.defaultEnglishVariant;
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
            child: Text(
              'YOUR PREFERENCES',
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5E3A8E),
                letterSpacing: 1.5,
              ),
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
          ),

          // English Variant
          _buildCompactItem(
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
          ),

          // Theme
          _buildCompactItem(
            icon: Icons.palette_outlined,
            title: 'Theme',
            value: _currentTheme,
            showDivider: false,
            onTap: () {
              // TODO: Navigate to theme settings
            },
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
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: iconText != null
                        ? Center(
                            child: Text(
                              iconText,
                              style: const TextStyle(fontSize: 18),
                            ),
                          )
                        : Icon(
                            icon,
                            size: 20,
                            color: const Color(0xFF5E3A8E),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF5E3A8E).withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5E3A8E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: const Color(0xFF5E3A8E).withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(
              height: 1,
              color: const Color(0xFFE5E7EB),
              thickness: 1,
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
            child: Text(
              'DATA (Guest Mode)',
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5E3A8E),
                letterSpacing: 1.5,
              ),
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
                  final preferenceService = ref.read(onboardingServiceProvider);
                  await preferenceService.clearGuestData();

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
          ),

          // Export Vocabulary
          _buildCompactItem(
            icon: Icons.download_outlined,
            title: 'Export Vocabulary',
            subtitle: 'Download your vocabulary list',
            showDivider: false,
            onTap: () {
              // TODO: Export vocabulary as CSV
            },
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
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: const Color(0xFF5E3A8E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5E3A8E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF5E3A8E).withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: const Color(0xFF5E3A8E).withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(
              height: 1,
              color: const Color(0xFFE5E7EB),
              thickness: 1,
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
            colors: [
              Colors.white,
              Color(0xFFf8f9ff),
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8B5CF6),
                      Color(0xFF60a5fa),
                    ],
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
                  color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConfirmItem('✅ Vocabulary deleted'),
                    _buildConfirmItem('✅ Progress reset'),
                    _buildConfirmItem('✅ Streak cleared'),
                    const SizedBox(height: 4),
                    _buildConfirmItem('💡 Settings (Level, Variant) kept'),
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
                            color: const Color(0xFF9ca3af).withValues(alpha: 0.3),
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
                            colors: [
                              Color(0xFF8B5CF6),
                              Color(0xFF60a5fa),
                            ],
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

  Widget _buildConfirmItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.lexend(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF5E3A8E),
        ),
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
            child: Text(
              'DATA',
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5E3A8E),
                letterSpacing: 1.5,
              ),
            ),
          ),

          // Export Vocabulary
          _buildCompactItem(
            icon: Icons.download_outlined,
            title: 'Export Vocabulary',
            subtitle: 'Download your vocabulary list',
            showDivider: true,
            onTap: () {
              // TODO: Export vocabulary as CSV
            },
          ),

          // Clear Cache
          _buildCompactItem(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear Cache',
            subtitle: 'Remove cached data from device',
            showDivider: true,
            onTap: () {
              // TODO: Clear cache
            },
          ),

          // Reset All Data
          _buildCompactItem(
            icon: Icons.refresh,
            title: 'Reset All Data',
            subtitle: 'Clear all data from the cloud (keep account)',
            showDivider: false,
            onTap: () {
              // TODO: Reset all data from cloud
            },
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
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: const Color(0xFF5E3A8E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5E3A8E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF5E3A8E).withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: const Color(0xFF5E3A8E).withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(
              height: 1,
              color: const Color(0xFFE5E7EB),
              thickness: 1,
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
                const Text(
                  '⚠️',
                  style: TextStyle(fontSize: 14),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
            child: Text(
              'ABOUT',
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5E3A8E),
                letterSpacing: 1.5,
              ),
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
          ),

          // Privacy Policy
          _buildCompactItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            showDivider: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyPage(),
                ),
              );
            },
          ),

          // Terms of Service
          _buildCompactItem(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            showDivider: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TermsOfServicePage(),
                ),
              );
            },
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
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: const Color(0xFF5E3A8E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5E3A8E),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: const Color(0xFF5E3A8E).withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(
              height: 1,
              color: const Color(0xFFE5E7EB),
              thickness: 1,
            ),
          ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AboutDialog(),
    );
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
            colors: [
              Colors.white,
              Color(0xFFf8f9ff),
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
    final preferenceService = ref.read(onboardingServiceProvider);
    final level = await preferenceService.getLanguageLevel();
    final variant = await preferenceService.getEnglishVariant();
    if (mounted) {
      setState(() {
        _guestLanguageLevel = level;
        _guestEnglishVariant = variant;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Galaxy gradient background
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
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF472B6).withValues(alpha: 0.55),
                    const Color(0x00F472B6),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFCD34D).withValues(alpha: 0.5),
                    const Color(0x00FCD34D),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Guest Header
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Top bar with back button
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
                              icon: const Icon(Icons.arrow_back, color: Color(0xFF5E3A8E)),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Register Prompt Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                            // Guest User badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: Color(0xFF5E3A8E),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Guest User',
                                    style: TextStyle(
                                      color: Color(0xFF5E3A8E),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Icon(
                              Icons.cloud_sync_outlined,
                              size: 32,
                              color: const Color(0xFF8B5CF6),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Save your progress',
                              style: GoogleFonts.cormorantUnicase(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF5E3A8E),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Create an account to sync across devices',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF5E3A8E).withValues(alpha: 0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const AccountMethodPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_add),
                                label: const Text('Create Account'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                          languageLevel: _guestLanguageLevel ?? AppDefaults.defaultLanguageLevel,
                          englishVariant: _guestEnglishVariant ?? AppDefaults.defaultEnglishVariant,
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
        ],
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
    final rawAvatarUrl = _userData?['avatar_url'] ??
        widget.user.userMetadata?['avatar_url'] ??
        widget.user.userMetadata?['picture'];

    final avatarUrl = rawAvatarUrl != null
        ? '$rawAvatarUrl?t=${DateTime.now().millisecondsSinceEpoch}'
        : null;

    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Galaxy gradient background
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
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF472B6).withValues(alpha: 0.55),
                    const Color(0x00F472B6),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFCD34D).withValues(alpha: 0.5),
                    const Color(0x00FCD34D),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Profile Header
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                              icon: const Icon(Icons.arrow_back, color: Color(0xFF5E3A8E)),
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
                              icon: const Icon(Icons.logout, color: Color(0xFF5E3A8E)),
                              onPressed: () => _showLogoutDialog(context, ref),
                              tooltip: 'Logout',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Avatar - clickable to change
                      GestureDetector(
                        onTap: () => _showAvatarPicker(context, displayName, avatarUrl),
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
                                        displayName.substring(0, 1).toUpperCase(),
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
                                  border: Border.all(color: Colors.white, width: 2),
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
                        onTap: () => _showDisplayNameDialog(context, ref, displayName),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.cormorantUnicase(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF5E3A8E),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: const Color(0xFF5E3A8E).withValues(alpha: 0.5),
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
                          color: const Color(0xFF5E3A8E).withValues(alpha: 0.7),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                          onDeleteAccount: () => _showDeleteAccountDialog(context, ref),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      builder: (context) => _DisplayNameDialog(
        controller: controller,
        formKey: formKey,
      ),
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
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
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
      final fileName = '${userId}_avatar.$safeExt';

      final fileBytes = await pickedFile.readAsBytes();

      try {
        await client.storage.from('avatars').uploadBinary(
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

      final avatarUrl = client.storage.from('avatars').getPublicUrl(fileName);

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
        SnackBarHelper.success(context, 'Profile photo updated');
      }

      _fetchUserData();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        SnackBarHelper.error(context, 'Failed to upload photo. Please try again.');
      }
    }
  }

  Future<void> _removeAvatar(BuildContext context) async {
    try {
      final client = Supabase.instance.client;
      final userId = widget.user.id;

      final currentAvatarUrl = widget.user.userMetadata?['avatar_url'] as String?;
      if (currentAvatarUrl != null) {
        try {
          final fileName = currentAvatarUrl.split('/').last;
          await client.storage.from('avatars').remove([fileName]);
        } catch (e) {
          // Ignore if file doesn't exist
        }
      }

      await client.auth.updateUser(
        UserAttributes(data: {'avatar_url': null}),
      );
      await client
          .from('users')
          .update({'avatar_url': null})
          .eq('id', userId);

      if (context.mounted) {
        SnackBarHelper.success(context, 'Profile photo removed');
      }

      _fetchUserData();
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, 'Failed to remove photo');
      }
    }
  }

  Future<void> _showLogoutDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
              colors: [
                Colors.white,
                Color(0xFFf8f9ff),
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFf472b6),
                        Color(0xFF60a5fa),
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
                              color: const Color(0xFF9ca3af).withValues(alpha: 0.3),
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
        final navigator = Navigator.of(context);

        await preferenceService.clearLocalPreferences();
        await preferenceService.setGuestMode(false);
        await preferenceService.setOnboardingCompleted(false);
        await client.auth.signOut();

        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingPage(skipToAuth: true)),
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
              colors: [
                Colors.white,
                Color(0xFFf8f9ff),
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFef4444),
                        Color(0xFFf97316),
                      ],
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
                              color: const Color(0xFF9ca3af).withValues(alpha: 0.3),
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
                              colors: [
                                Color(0xFFef4444),
                                Color(0xFFf97316),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFef4444).withValues(alpha: 0.4),
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

    if (confirmed == true && context.mounted) {
      try {
        final authService = ref.read(authServiceProvider);
        final preferenceService = ref.read(onboardingServiceProvider);
        final navigator = Navigator.of(context);

        await authService.deleteAccount();
        await preferenceService.clearLocalPreferences();
        await preferenceService.setGuestMode(false);
        await preferenceService.setOnboardingCompleted(false);

        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
          (route) => false,
        );
      } catch (e) {
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

  const _DisplayNameDialog({
    required this.controller,
    required this.formKey,
  });

  @override
  State<_DisplayNameDialog> createState() => _DisplayNameDialogState();
}

class _DisplayNameDialogState extends State<_DisplayNameDialog> {
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
            colors: [
              Colors.white,
              Color(0xFFf8f9ff),
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFf472b6),
                      Color(0xFF60a5fa),
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
                            color: const Color(0xFF9ca3af).withValues(alpha: 0.3),
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
                            onTap: () {
                              if (widget.formKey.currentState?.validate() == true) {
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
            colors: [
              Colors.white,
              Color(0xFFf8f9ff),
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
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFf472b6),
                      Color(0xFF60a5fa),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFf472b6).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
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
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Change Profile Photo',
                style: GoogleFonts.lexend(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'camera'),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: Text(
                    'Take Photo',
                    style: GoogleFonts.lexend(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'gallery'),
                  icon: const Icon(Icons.photo_library, size: 20),
                  label: Text(
                    'Choose from Gallery',
                    style: GoogleFonts.lexend(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: BorderSide(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (currentAvatarUrl != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context, 'remove'),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(
                      'Remove Photo',
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.red,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.withValues(alpha: 0.8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.lexend(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6b7280),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6b7280),
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
