import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/preference_service.dart';
import '../../../utils/snackbar_helper.dart';
import '../main_navigation.dart';
import '../onboarding_page.dart';
import '../language_selection_page.dart';
import 'otp_verification_page.dart' show OtpVerificationPage;
import '../../../constants/app_defaults.dart';

class AccountMethodPage extends ConsumerStatefulWidget {
  const AccountMethodPage({super.key});

  @override
  ConsumerState<AccountMethodPage> createState() => _AccountMethodPageState();
}

class _AccountMethodPageState extends ConsumerState<AccountMethodPage> {
  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  bool _isEmailLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle(BuildContext context) async {
    try {
      final authService = AuthService();
      // force ถาม account ใหม่ตอน guest สร้าง account
      final success = await authService.signInWithGoogle(
        forceAccountSelection: true,
      );

      if (!success) {
        if (context.mounted) {
          SnackBarHelper.error(context, AlertMessages.loginFailed);
        }
        return;
      }

      if (!context.mounted) return;

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        if (context.mounted) {
          SnackBarHelper.error(context, AlertMessages.loginFailed);
        }
        return;
      }

      final preferenceService = ref.read(onboardingServiceProvider);
      await preferenceService.init();

      // Auto-accept terms
      await preferenceService.setTermsVersion(preferenceService.getCurrentTermsVersion());

      final guestLevel = await preferenceService.getGuestLanguageLevel();
      final guestVariant = await preferenceService.getGuestEnglishVariant();
      final hasGuestData = guestLevel != null || guestVariant != null;

      final userData = await client
          .from('users')
          .select('id, language_level, onboarding_completed, display_name')
          .eq('id', userId)
          .maybeSingle();

      final isNewUser =
          userData == null || userData['onboarding_completed'] != true;

      if (!context.mounted) return;

      if (isNewUser) {
        //  New user
        String? finalLevel = guestLevel;
        String? finalVariant = guestVariant;

        if (!hasGuestData) {
          // ไม่มีข้อมูล guest → ถาม level/variant
          // EnglishVariantPage จะจัดการทุกอย่าง (บันทึกข้อมูล, navigate) เมื่อ isInitialSetup
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LanguageSelectionPage(
                isGuest: false,
                isInitialSetup: true,
                returnAfterSelection: false,
              ),
            ),
          );
          // Context will be unmounted here since EnglishVariantPage handles full navigation
          return;
        }

        // บันทึกข้อมูล
        await authService.updateUserPreferences(
          userId: userId,
          email: client.auth.currentUser?.email ?? '',
          languageLevel: finalLevel ?? AppDefaults.defaultLanguageLevel,
          englishVariant: finalVariant ?? AppDefaults.defaultEnglishVariant,
          termsVersion: preferenceService.getCurrentTermsVersion(),
        );

        // set onboarding_completed
        await client
            .from('users')
            .update({'onboarding_completed': true})
            .eq('id', userId);
      } else {
        // Existing user → ใช้ข้อมูลเดิมไว้เลย ไม่ overwrite
        // TODO: อาจเพิ่ม merge strategy ในอนาคตเมื่อมี feature คำศัพท์
        // if (hasGuestData) {
        //   await authService.updateUserPreferences(
        //     userId: userId,
        //     email: client.auth.currentUser?.email ?? '',
        //     languageLevel: guestLevel,
        //     englishVariant: guestVariant ?? 'US',
        //   );
        // }
      }

      if (!context.mounted) return;

      await preferenceService.setOnboardingCompleted(true);
      await preferenceService.setGuestMode(false);

      if (!context.mounted) return;

      // Show different message for existing vs new users
      if (!isNewUser) {
        SnackBarHelper.success(context, AlertMessages.welcomeBack);
      } else {
        SnackBarHelper.success(context, AlertMessages.loginSuccess);
      }

      // Wait a bit so user can see the success message
      await Future.delayed(const Duration(milliseconds: 500));

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, AlertMessages.loginFailed);
      }
    }
  }

  Future<void> _continueWithEmail(BuildContext context) async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isEmailLoading = true);

    try {
      final email = _emailController.text.trim();

      if (!context.mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            email: email,
            isGuestCreatingAccount: true,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.error(context, AlertMessages.loginFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isEmailLoading = false);
      }
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            padding: const EdgeInsets.all(24),
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [

                    // Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFf472b6), // Soft pink
                            Color(0xFF60a5fa), // Soft blue
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
                        Icons.person_add_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'Create an account',
                      style: GoogleFonts.lexend(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1f2937),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),

                    Text(
                      'Your guest data will be saved',
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF9ca3af),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Email input with continue button
                    Form(
                      key: _emailFormKey,
                      child: Column(
                        children: [
                          // Email input field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            style: GoogleFonts.lexend(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'your@email.com',
                              hintStyle: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF9ca3af),
                              ),
                              prefixIcon: const Icon(Icons.email_outlined, size: 20, color: Color(0xFF9ca3af)),
                              filled: true,
                              fillColor: const Color(0xFFf3f4f6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFc4b5fd), width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFef4444), width: 1),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFef4444), width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                            ),
                            onFieldSubmitted: (_) => _continueWithEmail(context),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return AlertMessages.emailRequired;
                              }
                              if (!value.trim().contains('@')) {
                                return AlertMessages.invalidEmail;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Email Continue button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF60a5fa), // soft blue
                                    Color(0xFF818cf8), // soft indigo
                                    Color(0xFFa78bfa), // soft violet
                                    Color(0xFFc084fc), // soft purple
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFa78bfa).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _isEmailLoading ? null : () => _continueWithEmail(context),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Center(
                                    child: _isEmailLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            'Send OTP',
                                            style: GoogleFonts.lexend(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
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
                    const SizedBox(height: 18),

                    // OR divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFe5e7eb),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'OR',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9ca3af),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFe5e7eb),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Google Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _continueWithGoogle(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8b5cf6),
                          side: const BorderSide(color: Color(0xFFe5e7eb), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        icon: Image.asset(
                          'assets/images/google_logo.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.g_mobiledata, size: 20, color: Color(0xFF1f2937));
                          },
                        ),
                        label: Text(
                          'Continue with Google',
                          style: GoogleFonts.lexend(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1f2937),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

              // Terms notice
              Text.rich(
                TextSpan(
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9ca3af),
                  ),
                  children: const [
                    TextSpan(text: 'By signing up, you agree to our '),
                    TextSpan(
                      text: 'Terms',
                      style: TextStyle(
                        color: Color(0xFFa5b4fc),
                      ),
                    ),
                    TextSpan(text: ' & '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: Color(0xFFa5b4fc),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
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
        ),
      ],
      ),
        ),
      );
    }
  }
