import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pages/terms_of_service_page.dart';
import '../pages/privacy_policy_page.dart';
import '../../utils/snackbar_helper.dart';

/// Reusable email input section with continue button
class _EmailInputSection extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final VoidCallback onContinue;

  const _EmailInputSection({
    required this.controller,
    required this.formKey,
    required this.isLoading,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          // Email input field
          TextFormField(
            controller: controller,
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
            onFieldSubmitted: (_) => onContinue(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return AlertMessages.emailRequired;
              }
              if (!SnackBarHelper.isValidEmail(value)) {
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
                  onTap: isLoading ? null : onContinue,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Continue with Email',
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
    );
  }
}

/// Reusable OR divider
class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

/// Reusable Google sign-in button
class _GoogleAuthButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GoogleAuthButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF8b5cf6),
          side: const BorderSide(color: Color(0xFFe5e7eb), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        icon: SvgPicture.network(
          'https://thesvg.org/icons/google/default.svg',
          width: 20,
          height: 20,
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
    );
  }
}

/// Reusable Terms & Privacy notice
class _AuthTermsNotice extends StatelessWidget {
  const _AuthTermsNotice();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.lexend(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF9ca3af),
        ),
        children: [
          const TextSpan(text: 'By signing up, you agree to our '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () {
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                  );
                }
              },
              child: Text(
                'Terms',
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFa5b4fc),
                ),
              ),
            ),
          ),
          const TextSpan(text: ' & '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () {
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                  );
                }
              },
              child: Text(
                'Privacy Policy',
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFa5b4fc),
                ),
              ),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Complete auth form combining all components
/// This is the main reusable widget for auth UI across the app
class AuthForm extends StatelessWidget {
  final VoidCallback onGoogleTap;
  final VoidCallback onEmailTap;
  final TextEditingController emailController;
  final GlobalKey<FormState> emailFormKey;
  final bool isEmailLoading;

  const AuthForm({
    super.key,
    required this.onGoogleTap,
    required this.onEmailTap,
    required this.emailController,
    required this.emailFormKey,
    required this.isEmailLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Email input section with continue button
        _EmailInputSection(
          controller: emailController,
          formKey: emailFormKey,
          isLoading: isEmailLoading,
          onContinue: onEmailTap,
        ),
        const SizedBox(height: 24),

        // OR divider
        const _AuthDivider(),
        const SizedBox(height: 18),

        // Google sign-in button
        _GoogleAuthButton(
          onTap: onGoogleTap,
        ),
        const SizedBox(height: 16),

        // Terms & Privacy notice
        const _AuthTermsNotice(),
      ],
    );
  }
}
