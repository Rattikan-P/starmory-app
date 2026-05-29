import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_page.dart';
import 'main_navigation.dart';
import 'english_variant_page.dart';
import '../../constants/app_defaults.dart';

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

    final preferenceService = ref.read(onboardingServiceProvider);
    final existingLevel = await preferenceService.getGuestLanguageLevel();
    final existingVariant = await preferenceService.getGuestEnglishVariant();

    // Store existing level for highlighting
    if (existingLevel != null && mounted) {
      setState(() {
        _selectedLevel = existingLevel;
      });
    }

    // ถ้ามีทั้ง level และ variant แล้ว → ไปหน้าถัดไป (guest ไป home, register ไป login)
    // ถ้ามีแค่ level แต่ไม่มี variant → ให้เลือก variant ต่อ (ไม่ skip)
    if (existingLevel != null && existingVariant != null && mounted) {
      if (widget.isGuest) {
        await preferenceService.setGuestMode(true);
        await preferenceService.setOnboardingCompleted(true);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            (route) => false,
          );
        }
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
      body: Stack(
        children: [
          // Gradient background
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

          SafeArea(
            child: Column(
              children: [
                // Custom header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      // Back button - only show for guest or editing
                      if (widget.isGuest || widget.isEditing)
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
                        )
                      else
                        // Invisible placeholder with same visual size as back button
                        const Opacity(
                          opacity: 0,
                          child: SizedBox(
                            width: 48,
                            height: 48,
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
                                  widthFactor: 0.5, // 50% for step 1 of 2
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
                          onPressed: () => _skip(context),
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
                                  ? 'Change your level'
                                  : 'What\'s your English level?',
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
                            const SizedBox(height: 24),

                            // Level cards
                            ...levels.map((level) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildLevelCard(level),
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
        ],
      ),
    );
  }

  Widget _buildLevelCard(LanguageLevel level) {
    final bool isSelected = _selectedLevel == level.code;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: level.color, width: 2)
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
          onTap: () => _selectLevel(context, level.code),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon with colored background
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: level.color.withValues(alpha: isSelected ? 0.3 : 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    level.icon,
                    size: 30,
                    color: level.color,
                  ),
                ),
                const SizedBox(width: 16),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.title,
                        style: GoogleFonts.lexend(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1f2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        level.description,
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6b7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow icon or Checkmark
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? level.color.withValues(alpha: 0.15)
                        : const Color(0xFFf3f4f6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: isSelected ? 20 : 16,
                    color: isSelected
                        ? level.color
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

  void _skip(BuildContext context) {
    _selectLevel(context, AppDefaults.defaultLanguageLevel);
  }

  void _selectLevel(BuildContext context, String code) async {
    setState(() {
      _selectedLevel = code;
    });

    final preferenceService = ref.read(onboardingServiceProvider);
    await preferenceService.setGuestLanguageLevel(code);

    if (!context.mounted) return;

    if (widget.isEditing) {
      if (widget.isGuest) {
        // Already saved above
      } else {
        final client = Supabase.instance.client;
        final userId = client.auth.currentSession?.user.id;
        if (userId != null) {
          await client.auth.updateUser(
            UserAttributes(data: {'language_level': code}),
          );
          await client
              .from('users')
              .update({'language_level': code})
              .eq('id', userId);
        }
      }
      if (context.mounted) Navigator.pop(context);
      return;
    }

    // Go to English variant selection
    if (context.mounted) {
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

      if (widget.returnAfterSelection && context.mounted) {
        if (result == true) {
          Navigator.pop(context, true);
        }
      }
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
