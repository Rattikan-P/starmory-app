import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:starmory_app/data/services/preference_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../constants/app_defaults.dart';
import '../providers/auth_provider.dart';
import '../../data/services/auth_service.dart';
import 'onboarding_page.dart';
import 'language_selection_page.dart';
import 'english_variant_page.dart';
import 'auth/account_method_page.dart';

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

// Shared Preferences Widget
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
      final preferenceService = ref.read(onboardingServiceProvider);
      final level = await preferenceService.getGuestLanguageLevel();
      final variant = await preferenceService.getGuestEnglishVariant();
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
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Section Title
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
            child: Text(
              'Your Preferences',
              style: GoogleFonts.cormorantUnicase(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5E3A8E),
              ),
            ),
          ),

          // Language Proficiency Card
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LanguageSelectionPage(
                        isGuest: widget.isGuest,
                        isEditing: true,
                        isInitialSetup: false,
                      ),
                    ),
                  );
                  widget.onPreferenceChanged?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          color: const Color(0xFF5E3A8E),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Language Level',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentLevel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5E3A8E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // English Variant Card
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EnglishVariantPage(
                        isGuest: widget.isGuest,
                        isEditing: true,
                        isInitialSetup: false,
                      ),
                    ),
                  );
                  widget.onPreferenceChanged?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            variantFlag,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'English Variant',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              variantName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5E3A8E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

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
    final level = await preferenceService.getGuestLanguageLevel();
    final variant = await preferenceService.getGuestEnglishVariant();
    if (mounted) {
      setState(() {
        _guestLanguageLevel = level;
        _guestEnglishVariant = variant;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Guest Header with onboarding-style gradient
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFB3BA).withValues(alpha: 0.6),
                const Color(0xFFFFDFBA).withValues(alpha: 0.6),
                const Color(0xFFE2D1F9).withValues(alpha: 0.6),
                const Color(0xFFBFEAF5).withValues(alpha: 0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Top bar with back button
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF5E3A8E)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Register Prompt Card - onboarding style
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Color(0xFF5E3A8E),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Guest User',
                                style: TextStyle(
                                  color: Color(0xFF5E3A8E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Icon(
                          Icons.cloud_sync_outlined,
                          size: 40,
                          color: const Color(0xFF8B5CF6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Save your progress',
                          style: GoogleFonts.cormorantUnicase(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF5E3A8E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create an account to sync across devices',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF5E3A8E).withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),

        // Preferences Section (using shared widget)
        Expanded(
          child: _PreferencesSection(
            languageLevel: _guestLanguageLevel ?? AppDefaults.defaultLanguageLevel,
            englishVariant: _guestEnglishVariant ?? AppDefaults.defaultEnglishVariant,
            isGuest: true,
            onPreferenceChanged: _loadGuestPreferences,
          ),
        ),
      ],
    );
  }
}

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

    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Column(
      children: [
        // Profile Header with onboarding-style gradient
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFB3BA).withValues(alpha: 0.6),
                const Color(0xFFFFDFBA).withValues(alpha: 0.6),
                const Color(0xFFE2D1F9).withValues(alpha: 0.6),
                const Color(0xFFBFEAF5).withValues(alpha: 0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Top bar with back and edit buttons
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
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Color(0xFF5E3A8E),
                          ),
                          onPressed: () => _showDisplayNameDialog(context, ref, displayName),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Avatar
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
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    displayName,
                    style: GoogleFonts.cormorantUnicase(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5E3A8E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF5E3A8E).withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // Preferences Section (using shared widget)
        Expanded(
          child: _PreferencesSection(
            languageLevel: languageLevel,
            englishVariant: englishVariant,
            isGuest: false,
            onPreferenceChanged: _fetchUserData,
          ),
        ),

        // Logout Button (separate for logged-in users)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  // Sync preferences to guest before logout
                  final client = Supabase.instance.client;
                  final level = _userData?['language_level'];
                  final variant = _userData?['english_variant'];

                  final preferenceService = ref.read(onboardingServiceProvider);
                  if (level != null) {
                    await preferenceService.setGuestLanguageLevel(level);
                  }
                  if (variant != null) {
                    await preferenceService.setGuestEnglishVariant(variant);
                  }

                  // Set guest mode before logout so ProfileTab shows guest view
                  await preferenceService.setGuestMode(true);

                  await client.auth.signOut();
                },
                icon: const Icon(Icons.login, color: Color(0xFF5E3A8E)),
                label: const Text('Logout', style: TextStyle(color: Color(0xFF5E3A8E))),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.transparent,
                  foregroundColor: const Color(0xFF5E3A8E),
                  shadowColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),

        // Delete Account Button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteAccountDialog(context, ref),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text('Delete Account'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.red.withValues(alpha: 0.8),
                side: BorderSide(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
      ],
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
        final client = Supabase.instance.client;
        final userId = widget.user.id;

        await client.auth.updateUser(
          UserAttributes(data: {'display_name': newName}),
        );
        await client
            .from('users')
            .update({'display_name': newName})
            .eq('id', userId);

        _fetchUserData();
      }
    }
  }
}

// Display Name Edit Dialog - matches onboarding style
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE2D1F9).withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 32,
                color: Color(0xFF5E3A8E),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Edit Display Name',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5E3A8E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Text field
            Form(
              key: widget.formKey,
              child: TextFormField(
                controller: widget.controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Enter your name',
                  filled: true,
                  fillColor: const Color(0xFFE2D1F9).withValues(alpha: 0.2),
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
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (widget.formKey.currentState?.validate() == true) {
                    Navigator.of(context).pop(true);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5E3A8E),
                  side: BorderSide(
                    color: const Color(0xFF5E3A8E).withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

Future<void> _showDeleteAccountDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Account'),
      content: const Text(
        'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
  try {
    final authService = ref.read(authServiceProvider);
    // อ่านค่าก่อน deleteAccount เพราะหลังจากนั้น ref อาจ dispose แล้ว
    final preferenceService = ref.read(onboardingServiceProvider);
    final navigator = Navigator.of(context);

    await authService.deleteAccount();

    // Clear guest mode and go to onboarding
    await preferenceService.clearGuestPreferences();
    await preferenceService.setGuestMode(false);
    await preferenceService.setOnboardingCompleted(false);

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingPage()),
      (route) => false,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: ${e.toString()}')),
      );
    }
  }
}
}
