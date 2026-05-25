import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_page.dart' show onboardingServiceProvider;
import 'main_navigation.dart';
import '../../constants/app_defaults.dart';

class LanguageAndVariantPage extends ConsumerStatefulWidget {
  final bool isGuest;
  final bool isInitialSetup;
  final bool returnAfterSelection;

  const LanguageAndVariantPage({
    super.key,
    this.isGuest = false,
    required this.isInitialSetup,
    this.returnAfterSelection = false,
  });

  @override
  ConsumerState<LanguageAndVariantPage> createState() =>
      _LanguageAndVariantPageState();
}

class _LanguageAndVariantPageState
    extends ConsumerState<LanguageAndVariantPage> {
  String? _selectedLevel;
  String? _selectedVariant;

  final List<LanguageLevel> _levels = const [
    LanguageLevel(
      code: 'A1',
      title: 'Just starting',
      description: 'I am new to English',
      icon: Icons.sentiment_satisfied,
    ),
    LanguageLevel(
      code: 'A2',
      title: 'A bit comfortable',
      description: 'I know basic phrases',
      icon: Icons.sentiment_satisfied_alt,
    ),
    LanguageLevel(
      code: 'B1',
      title: 'Getting better',
      description: 'I can handle daily conversations',
      icon: Icons.sentiment_dissatisfied,
    ),
    LanguageLevel(
      code: 'B2',
      title: 'Pretty good',
      description: 'I can chat with native speakers',
      icon: Icons.sentiment_very_satisfied,
    ),
  ];

  final List<EnglishVariant> _variants = const [
    EnglishVariant(
      code: 'US',
      name: 'American',
      flag: '🇺🇸',
      description: 'US English',
    ),
    EnglishVariant(
      code: 'UK',
      name: 'British',
      flag: '🇬🇧',
      description: 'UK English',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.isInitialSetup) {
      _loadExistingPreferences();
    }
  }

  Future<void> _loadExistingPreferences() async {
    final preferenceService = ref.read(onboardingServiceProvider);
    final level = await preferenceService.getGuestLanguageLevel();
    final variant = await preferenceService.getGuestEnglishVariant();
    if (mounted) {
      setState(() {
        _selectedLevel = level;
        _selectedVariant = variant;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final contentPadding = isTablet ? screenWidth * 0.15 : 16.0;

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
            top: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFC4B5FD).withValues(alpha: 0.4),
                    const Color(0x00C4B5FD),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF93C5FD).withValues(alpha: 0.4),
                    const Color(0x0093C5FD),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: 100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF472B6).withValues(alpha: 0.4),
                    const Color(0x00F472B6),
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(contentPadding, 12, contentPadding, 8),
                  child: Row(
                    children: [
                      if (widget.isGuest)
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
                        ),
                      const Spacer(),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: contentPadding),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Title
                        Text(
                          widget.isInitialSetup
                              ? 'Quick setup'
                              : 'Your settings',
                          style: GoogleFonts.lexend(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1f2937),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),

                        // Subtitle
                        Text(
                          widget.isInitialSetup
                              ? 'This helps us personalize your experience'
                              : 'Change anytime in settings',
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF6b7280),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Language Level Section
                        _buildSectionHeader('How\'s your English?'),
                        const SizedBox(height: 12),
                        _buildLevelsGrid(),
                        const SizedBox(height: 32),

                        // English Variant Section
                        _buildSectionHeader('Which English sounds good?'),
                        const SizedBox(height: 12),
                        _buildVariantsGrid(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Bottom section (match onboarding style)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 20,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Note
                      Text(
                        'No worries, you can always change this later',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9ca3af),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF60a5fa),
                                  Color(0xFF818cf8),
                                  Color(0xFFa78bfa),
                                  Color(0xFFc084fc),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFa78bfa).withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.isInitialSetup ? 'Let\'s go!' : 'Save',
                                style: GoogleFonts.lexend(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.lexend(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4b5563),
        ),
      ),
    );
  }

  Widget _buildLevelsGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final crossAxisCount = isTablet ? 4 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isTablet ? 16 : 12,
        mainAxisSpacing: isTablet ? 16 : 12,
        childAspectRatio: isTablet ? 1.58 : 1.52,
      ),
      itemCount: _levels.length,
      itemBuilder: (context, index) {
        final level = _levels[index];
        final isSelected = _selectedLevel == level.code;
        return _buildLevelCard(level, isSelected);
      },
    );
  }

  Widget _buildVariantsGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final crossAxisCount = isTablet ? 4 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isTablet ? 16 : 12,
        mainAxisSpacing: isTablet ? 16 : 12,
        childAspectRatio: isTablet ? 1.58 : 1.52,
      ),
      itemCount: _variants.length,
      itemBuilder: (context, index) {
        final variant = _variants[index];
        final isSelected = _selectedVariant == variant.code;
        return _buildVariantCard(variant, isSelected);
      },
    );
  }

  Widget _buildLevelCard(LanguageLevel level, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFFd8b4fe) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFd8b4fe).withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedLevel = level.code),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFd8b4fe).withValues(alpha: 0.15)
                              : const Color(0xFFf3f4f6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          level.icon,
                          size: 26,
                          color: isSelected ? const Color(0xFF8b5cf6) : const Color(0xFF6b7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        level.title,
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1f2937),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        level.description,
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9ca3af),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFa78bfa),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 13,
                        color: Colors.white,
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

  Widget _buildVariantCard(EnglishVariant variant, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFFd8b4fe) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFd8b4fe).withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedVariant = variant.code),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFd8b4fe).withValues(alpha: 0.15)
                              : const Color(0xFFf3f4f6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            variant.flag,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        variant.name,
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1f2937),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        variant.description,
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF9ca3af),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFa78bfa),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 13,
                        color: Colors.white,
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

  Future<void> _continue() async {
    final preferenceService = ref.read(onboardingServiceProvider);

    await preferenceService.setGuestLanguageLevel(
      _selectedLevel ?? AppDefaults.defaultLanguageLevel,
    );
    await preferenceService.setGuestEnglishVariant(
      _selectedVariant ?? AppDefaults.defaultEnglishVariant,
    );

    if (!mounted) return;

    if (widget.returnAfterSelection) {
      Navigator.of(context).pop(true);
      return;
    }

    if (widget.isInitialSetup) {
      await preferenceService.setOnboardingCompleted(true);
      await preferenceService.setGuestMode(false);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }
}

class LanguageLevel {
  final String code;
  final String title;
  final String description;
  final IconData icon;

  const LanguageLevel({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class EnglishVariant {
  final String code;
  final String name;
  final String flag;
  final String description;

  const EnglishVariant({
    required this.code,
    required this.name,
    required this.flag,
    required this.description,
  });
}
