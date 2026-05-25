import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/preference_service.dart';
import '../language_and_variant_page.dart';
import '../main_navigation.dart';
import '../onboarding_page.dart' show onboardingServiceProvider;
import '../../../constants/app_defaults.dart';

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
  ConsumerState<OtpVerificationPage> createState() =>
      _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('OTP sent successfully!')));
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

      final preferenceService = ref.read(onboardingServiceProvider);
      final guestLevel = await preferenceService.getGuestLanguageLevel();
      final guestVariant = await preferenceService.getGuestEnglishVariant();

      final hasGuestData = widget.languageLevel != null || guestLevel != null;

      if (!isNewUser) {
        // Existing user → ใช้ข้อมูลเดิมไว้เลย ไม่ overwrite
        // TODO: อาจเพิ่ม merge strategy ในอนาคตเมื่อมี feature คำศัพท์
      } else if (isNewUser && user != null) {
        // New user → มีข้อมูล guest ใช้เลย ไม่มีค่อยถาม
        await preferenceService.clearGuestPreferences();
        final finalLevel = widget.languageLevel ?? guestLevel;
        final finalVariant = widget.englishVariant ?? guestVariant;

        if (hasGuestData) {
          // มีข้อมูล guest → บันทึกเลย
          await authService.updateUserPreferences(
            userId: user.id,
            email: widget.email,
            displayName: widget.displayName,
            languageLevel: finalLevel ?? AppDefaults.defaultLanguageLevel,
            englishVariant: finalVariant ?? AppDefaults.defaultEnglishVariant,
          );
        } else {
          // ไม่มีข้อมูล guest → ถาม level/variant
          await preferenceService.clearGuestPreferences();

          final selectionResult = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const LanguageAndVariantPage(
                isGuest: false,
                isInitialSetup: true,
                returnAfterSelection: true,
              ),
            ),
          );

          if (!mounted || selectionResult != true) return;

          final level = await preferenceService.getGuestLanguageLevel();
          final variant = await preferenceService.getGuestEnglishVariant();

          await authService.updateUserPreferences(
            userId: user.id,
            email: widget.email,
            languageLevel: level ?? AppDefaults.defaultLanguageLevel,
            englishVariant: variant ?? AppDefaults.defaultEnglishVariant,
          );
        }
      }

      if (!mounted) return;

      // Mark onboarding as completed and clear guest mode
      await preferenceService.setOnboardingCompleted(true);
      await preferenceService.setGuestMode(false);

      // Update database
      if (user != null) {
        await Supabase.instance.client
            .from('users')
            .update({'onboarding_completed': true})
            .eq('id', user.id);
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Invalid OTP: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    return Scaffold(
      body: Container(
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
        child: Stack(
          children: [
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
            // Static stars
            ...List.generate(40, (i) {
              final r = Random(i * 42);
              final s = 1.5 + r.nextDouble() * 3.5;
              return Positioned(
                top: r.nextDouble() * MediaQuery.of(context).size.height,
                left: r.nextDouble() * MediaQuery.of(context).size.width,
                child: Opacity(
                  opacity: 0.2 + r.nextDouble() * 0.6,
                  child: Container(
                    width: s, height: s,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.white54, blurRadius: 2)],
                    ),
                  ),
                ),
              );
            }),
            // Content
            SafeArea(
              child: Stack(
                children: [
                  // Back button - outside card
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF1f2937)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  // Card content
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 80, bottom: 24, left: 24, right: 24),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          onTap: _onPaste,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [

                          // Icon
                          Center(
                            child: Container(
                              width: 90,
                              height: 90,
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
                                Icons.email_outlined,
                                size: 45,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Text(
                            'Check your email',
                            style: GoogleFonts.lexend(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1f2937),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            'We sent a 6-digit code to',
                            style: GoogleFonts.lexend(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF6b7280),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.email,
                            style: GoogleFonts.lexend(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8b5cf6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          // OTP Fields
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: SizedBox(
                                  width: 40,
                                  height: 52,
                                  child: TextField(
                                    controller: _otpControllers[index],
                                    focusNode: _focusNodes[index],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.lexend(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1f2937),
                                      height: 1.0,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(1),
                                    ],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                      filled: true,
                                      fillColor: const Color(0xFFF3F4F6),
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
                                          color: Color(0xFFa78bfa),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) =>
                                        _onOtpChanged(index, value),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),

                          // Paste hint
                          Text(
                            'Tap anywhere to paste code',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF9ca3af),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Resend Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive? ",
                                style: GoogleFonts.lexend(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF6b7280),
                                ),
                              ),
                              TextButton(
                                onPressed: _countdown == 0 && !_isResending
                                    ? _resendOtp
                                    : null,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: _isResending
                                    ? const SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF8b5cf6),
                                        ),
                                      )
                                    : Text(
                                        _countdown > 0
                                            ? 'Resend in $_countdown s'
                                            : 'Resend',
                                        style: GoogleFonts.lexend(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF8b5cf6),
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
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.white.withValues(alpha: 0.8),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFa78bfa),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
