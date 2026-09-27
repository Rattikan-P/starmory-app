import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_navigation.dart';
import 'english_variant_page.dart';
import '../../constants/app_defaults.dart';
import '../providers/providers.dart';
import '../../utils/snackbar_helper.dart';

class LanguageSelectionPage extends ConsumerStatefulWidget {
  final bool isGuest;
  final bool isEditing;
  final bool isInitialSetup;
  final bool forceSelection;
  final bool returnAfterSelection;
  final String? currentLevel;

  const LanguageSelectionPage({
    super.key,
    this.isGuest = false,
    this.isEditing = false,
    this.isInitialSetup = false,
    this.forceSelection = false,
    this.returnAfterSelection = false,
    this.currentLevel,
  });

  @override
  ConsumerState<LanguageSelectionPage> createState() =>
      _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends ConsumerState<LanguageSelectionPage> {
  String? _selectedLevel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingGuestLevel();
    });
  }

  Future<void> _checkExistingGuestLevel() async {
    // For editing mode, use currentLevel if provided
    if (widget.isEditing) {
      if (widget.currentLevel != null && mounted) {
        setState(() {
          _selectedLevel = widget.currentLevel;
        });
      }
      return;
    }

    if (widget.forceSelection || widget.isInitialSetup) return;

    // Load from UserModel instead of SharedPreferences
    final currentUser = ref.read(userStateProvider).user;
    if (currentUser != null && mounted) {
      final existingLevel = currentUser.languageLevel;

      // Store existing level for highlighting
      setState(() {
        _selectedLevel = existingLevel;
      });

      // ถ้ามีทั้ง level และ variant แล้ว → ไปหน้าถัดไป (guest ไป home)
      // Note: languageLevel and englishVariant always have defaults, never null
      if (widget.isGuest) {
        // Guest with complete preferences - skip to home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    }
    // ถ้ามี level แต่ไม่มี variant หรือไม่มีเลย → แสดงหน้า selection ให้เลือก
  }

  static const List<LanguageLevel> levels = [
    LanguageLevel(
      code: 'A1',
      title: 'Just starting',
      description: 'I\'m new to English',
      icon: Icons.sentiment_satisfied,
      color: Color(0xFF34d399), // Mint
    ),
    LanguageLevel(
      code: 'A2',
      title: 'Beginner',
      description: 'I know basic phrases',
      icon: Icons.sentiment_satisfied_alt,
      color: Color(0xFF60a5fa), // Blue
    ),
    LanguageLevel(
      code: 'B1',
      title: 'Intermediate',
      description: 'I can handle daily conversations',
      icon: Icons.sentiment_very_satisfied,
      color: Color(0xFFa78bfa), // Purple
    ),
    LanguageLevel(
      code: 'B2',
      title: 'Advanced',
      description: 'I\'m comfortable with most conversations',
      icon: Icons.emoji_events,
      color: Color(0xFFf472b6), // Pink
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
                                widthFactor: 0.5, // 50% for step 1 of 2
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
                              onPressed: () => _skip(context),
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
                          'assets/images/level_mascot.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          widget.isEditing
                              ? 'Change your level'
                              : 'What\'s your English level?',
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
                              ? 'Select your new proficiency level'
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

                        // Level cards
                        ...levels.map((level) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildLevelCard(level),
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

  Widget _buildLevelCard(LanguageLevel level) {
    final bool isSelected = _selectedLevel == level.code;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: level.color.withValues(alpha: 0.8), width: 1.5)
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
          onTap: () => _selectLevel(context, level.code),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: [
                // Icon with colored background
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        level.color.withValues(alpha: isSelected ? 0.3 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    level.icon,
                    size: 24,
                    color: level.color,
                  ),
                ),
                const SizedBox(width: 12),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.title,
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1f2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        level.description,
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
                        ? level.color.withValues(alpha: 0.16)
                        : const Color(0xFFF1F2F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_rounded
                        : Icons.chevron_right_rounded,
                    size: 20,
                    color: isSelected ? level.color : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _skip(BuildContext context) {
    _selectLevel(context, AppDefaults.defaultLanguageLevel);
  }

  void _selectLevel(BuildContext context, String code) async {
    setState(() {
      _selectedLevel = code;
    });

    if (!context.mounted) return;

    // EDITING MODE: Save preference immediately and return
    if (widget.isEditing) {
      try {
        final userNotifier = ref.read(userStateProvider.notifier);
        await userNotifier.updatePreferences({'defaultCefrLevel': code});
        debugPrint('✅ Updated language level: $code');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        debugPrint('❌ Failed to update language level: $e');
        if (mounted) {
          SnackBarHelper.error(
              context, 'Failed to update preference. Please try again.');
        }
      }
      return;
    }

    // ONBOARDING MODE: Go to English variant selection
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EnglishVariantPage(
          isGuest: widget.isGuest,
          isInitialSetup: widget.isInitialSetup,
          languageLevel: code,
          forceSelection: widget.forceSelection,
          returnAfterSelection: widget.returnAfterSelection,
        ),
      ),
    );

    _handleVariantSelectionResult(result);
  }

  void _handleVariantSelectionResult(bool? result) {
    if (widget.returnAfterSelection && mounted && result == true) {
      Navigator.pop(context, true);
    }
  }
}

class LanguageLevel {
  final String code;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const LanguageLevel({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
