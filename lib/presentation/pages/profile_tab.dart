import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/auth_provider.dart';
import 'onboarding_page.dart';
import 'auth/login_page.dart';
import 'language_selection_page.dart';
import 'english_variant_page.dart';

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
  }

  Future<void> _checkGuestMode() async {
    final hiveService = ref.read(onboardingServiceProvider);
    final isGuest = await hiveService.isGuestMode();
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: user == null
          ? _NotLoggedInView(isGuestMode: _isGuestMode)
          : _LoggedInView(user: user),
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

  @override
  void initState() {
    super.initState();
    if (widget.isGuestMode) {
      _loadGuestLevel();
    }
  }

  Future<void> _loadGuestLevel() async {
    final hiveService = ref.read(onboardingServiceProvider);
    final level = await hiveService.getGuestLanguageLevel();
    if (mounted) {
      setState(() {
        _guestLanguageLevel = level;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isGuestMode ? Icons.person_outline : Icons.account_circle_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isGuestMode ? 'Guest Mode' : 'Not logged in',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            // Show language level for guests
            if (widget.isGuestMode && _guestLanguageLevel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.language,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Level: $_guestLanguageLevel',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

            Text(
              widget.isGuestMode
                  ? 'Create an account to save your progress'
                  : 'Sign in to track your progress',
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 24),

            // Create Account button for guests
            if (widget.isGuestMode)
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LanguageSelectionPage(isInitialSetup: false)),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Create Account'),
              ),

            if (!widget.isGuestMode)
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Login'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoggedInView extends StatelessWidget {
  final User user;

  const _LoggedInView({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = user.userMetadata?['display_name'] ?? 'User';
    final email = user.email ?? '';
    // Default: B1 (can be changed here)
    final languageLevel = user.userMetadata?['language_level'] ?? 'B1';
    // Default: US (can be changed here)
    final englishVariant = user.userMetadata?['english_variant'] ?? 'US';
    final variantName = englishVariant == 'UK' ? 'British English' : 'American English';
    final variantFlag = englishVariant == 'UK' ? '🇬🇧' : '🇺🇸';

    return Column(
      children: [
        // Profile Header
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Top bar with back button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        onPressed: () {
                          // TODO: Edit profile
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Text(
                    displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Email
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // User Characteristics
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // User Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Registered User',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Language Proficiency Card
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Language Proficiency'),
                    subtitle: Text(languageLevel),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageSelectionPage(
                            isGuest: false,
                            isEditing: true,
                            isInitialSetup: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // English Variant Card
                Card(
                  child: ListTile(
                    leading: Text(variantFlag, style: const TextStyle(fontSize: 24)),
                    title: const Text('English Variant'),
                    subtitle: Text(variantName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EnglishVariantPage(
                            isGuest: false,
                            isEditing: true,
                            isInitialSetup: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Settings
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('Settings'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Navigate to settings
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          'Delete Account',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        onTap: () {
                          // TODO: Delete account confirmation
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
