import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/hive_service.dart';
import '../language_selection_page.dart';
import '../main_navigation.dart';

final onboardingServiceProvider = Provider<HiveService>((ref) => HiveService());

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class OtpVerificationPage extends ConsumerStatefulWidget {
  final String email;
  final String? displayName;
  final String? languageLevel;
  final String? englishVariant;
  final bool isGuestCreatingAccount;

  const OtpVerificationPage({
    super.key,
    required this.email,
    this.displayName,
    this.languageLevel,
    this.englishVariant,
    this.isGuestCreatingAccount = false,
  });

  @override
  ConsumerState<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isResending = false;
  int _countdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    // Auto-send OTP on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOtpAutomatically();
    });
  }

  Future<void> _sendOtpAutomatically() async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendOtp(widget.email);
    } catch (e) {
      // Silently fail, user can retry with resend button
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent successfully!')),
        );
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits')),
      );
      return;
    }

    setState(() => _isLoading = true);
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

      // Check if existing user with guest data that might differ
      // Check both passed data AND Hive storage
      final hiveService = ref.read(onboardingServiceProvider);
      final guestLevel = await hiveService.getGuestLanguageLevel();
      final guestVariant = await hiveService.getGuestEnglishVariant();

      final hasPassedGuestData = widget.languageLevel != null ||
          widget.englishVariant != null ||
          widget.displayName != null;
      final hasHiveGuestData = guestLevel != null || guestVariant != null;

      final hasGuestData = hasPassedGuestData || hasHiveGuestData;

      // Merge guest data: prioritize passed data, fall back to Hive data
      final finalGuestLevel = widget.languageLevel ?? guestLevel;
      final finalGuestVariant = widget.englishVariant ?? guestVariant;

      if (!isNewUser && hasGuestData && widget.isGuestCreatingAccount) {
        // Guest creating account with existing email - ask which data to use
        final useGuestData = await _showDataChoiceDialog(context);
        if (useGuestData == true && user != null) {
          // User chose to use guest data - update with merged guest data
          await authService.updateUserPreferences(
            userId: user.id,
            email: widget.email,
            displayName: widget.displayName,
            languageLevel: finalGuestLevel,
            englishVariant: finalGuestVariant,
          );
        }
        // If useGuestData is false or null, keep existing data
      } else if (!isNewUser && hasGuestData && !widget.isGuestCreatingAccount) {
        // Logging in with existing email - keep existing data, don't ask
        // Just continue to main app
      } else if (isNewUser && hasGuestData && widget.isGuestCreatingAccount && user != null) {
        // Guest creating account with new email - use existing guest data
        await authService.updateUserPreferences(
          userId: user.id,
          email: widget.email,
          displayName: widget.displayName,
          languageLevel: finalGuestLevel,
          englishVariant: finalGuestVariant,
        );
      } else if (isNewUser && user != null) {
        // New user from onboarding - ask for level/variant (clear any old guest data first)
        await hiveService.clearGuestPreferences();

        // Go to language selection, then come back to continue
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const LanguageSelectionPage(
              isInitialSetup: true,
              returnAfterSelection: true,
              forceSelection: true,
            ),
          ),
        );

        // If user cancelled or went back, exit
        if (!mounted || result != true) return;

        // Continue with the flow - user has selected level/variant
        // Need to update user preferences with the selected values
        final level = await hiveService.getGuestLanguageLevel();
        final variant = await hiveService.getGuestEnglishVariant();

        if (level != null) {
          await authService.updateUserPreferences(
            userId: user.id,
            email: widget.email,
            languageLevel: level,
            englishVariant: variant ?? 'US',
          );
        }
      }

      if (!mounted) return;

      // Check if user has display name
      final hasDisplayName = user?.userMetadata?['display_name'] != null;

      if (!hasDisplayName) {
        // Mark onboarding as completed and go to main, then show display name prompt
        if (mounted) {
          final hiveService = ref.read(onboardingServiceProvider);
          await hiveService.setOnboardingCompleted(true);

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen(showDisplayNamePrompt: true)),
            (route) => false,
          );
        }
      } else {
        // Mark onboarding as completed
        final hiveService = ref.read(onboardingServiceProvider);
        await hiveService.setOnboardingCompleted(true);

        // Go to main navigation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid OTP: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showDataChoiceDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Found your existing account!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'We found an account with this email. Would you like to keep your old settings or update with your latest guest preferences?',
            ),
            SizedBox(height: 12),
            Text(
              '⚠️ Note: If you create a new account instead, your old account data will be lost.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Old'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Update New'),
          ),
        ],
      ),
    );
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    // Auto verify when all 6 digits are entered
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length == 6 && !_isLoading) {
      _verifyOtp();
    }
  }

  void _onPaste() async {
    final clipboardData = await Clipboard.getData('text/plain');
    final pastedText = clipboardData?.text ?? '';
    if (pastedText.length == 6 && int.tryParse(pastedText) != null) {
      for (int i = 0; i < 6; i++) {
        _otpControllers[i].text = pastedText[i];
      }
      _focusNodes[5].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: GestureDetector(
              onTap: _onPaste,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                    // Icon
                    Icon(
                      Icons.email_outlined,
                      size: 60,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Check your email',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle
                    Text(
                      'We sent a 6-digit code to\n${widget.email}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // OTP Fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 48,
                          height: 56,
                          child: TextField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (value) => _onOtpChanged(index, value),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),

                    // Paste hint
                    Text(
                      'Tap anywhere to paste code',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Resend Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the code? ",
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: _countdown == 0 && !_isResending
                              ? _resendOtp
                              : null,
                          child: _isResending
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  _countdown > 0
                                      ? 'Resend in $_countdown s'
                                      : 'Resend',
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Change Email
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Wrong email? Go back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (_isLoading)
        Container(
          color: theme.colorScheme.surface,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
    ],
      ),
    );
  }
}
