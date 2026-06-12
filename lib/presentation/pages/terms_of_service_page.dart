import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/galaxy_screen_background.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GalaxyScreenBackground(
        child: SafeArea(
          child: Column(
            children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
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
                      const SizedBox(width: 16),
                      Text(
                        'Terms of Service',
                        style: GoogleFonts.lexend(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5E3A8E),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content card
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Center(
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF60a5fa), Color(0xFF818cf8)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF60a5fa).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.gavel_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Center(
                            child: Text(
                              'Terms of Service',
                              style: GoogleFonts.cormorantUnicase(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1f2937),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Rules and guidelines for using Starmory',
                              style: GoogleFonts.lexend(
                                fontSize: 14,
                                color: const Color(0xFF6b7280),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Last updated badge
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Last updated: June 2026',
                                style: GoogleFonts.lexend(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Divider
                          Container(
                            height: 1,
                            color: const Color(0xFFe5e7eb),
                          ),
                          const SizedBox(height: 24),

                          // Content sections
                          _TermsSection(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF34d399),
                            title: '1. Acceptance of Terms',
                            content: '''
By downloading, accessing, or using Starmory, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our app.

These terms constitute a legally binding agreement between you and Starmory.
''',
                          ),
                          const SizedBox(height: 24),

                          _TermsSection(
                            icon: Icons.info_rounded,
                            iconColor: const Color(0xFF60a5fa),
                            title: '2. Description of Service',
                            content: '''
Starmory is a language learning application that:

• Uses AI to generate vocabulary lessons from your personal photos
• Tracks your learning progress and streaks
• Provides spaced repetition for effective vocabulary retention
• Offers both guest mode and registered user accounts

We reserve the right to modify or discontinue the service at any time.
''',
                          ),
                          const SizedBox(height: 24),

                          _TermsSection(
                            icon: Icons.person_rounded,
                            iconColor: const Color(0xFFa78bfa),
                            title: '3. User Accounts',
                            content: '''
To use our service, you must:

• Provide accurate and complete information
• Maintain the security of your account
• Notify us of unauthorized access

Guest Mode:
• Limited functionality with daily and lifetime quotas
• Data stored locally on your device
• No cloud synchronization

Registered Accounts:
• Full access to all features
• Cloud synchronization across devices
• Data backup and recovery
''',
                          ),
                          const SizedBox(height: 24),

                          _TermsSection(
                            icon: Icons.block_rounded,
                            iconColor: const Color(0xFFef4444),
                            title: '4. User Conduct',
                            content: '''
You agree NOT to:

• Upload inappropriate, offensive, or illegal content
• Attempt to circumvent usage limitations or quotas
• Reverse engineer or attempt to extract our AI models
• Use the service for any illegal purpose
• Harass other users or violate their rights

We reserve the right to terminate accounts that violate these terms.
''',
                          ),
                          const SizedBox(height: 24),

                          _TermsSection(
                            icon: Icons.copyright_rounded,
                            iconColor: const Color(0xFFfbbf24),
                            title: '5. Content and Intellectual Property',
                            content: '''
• You retain ownership of photos you upload
• You grant us a license to use your content solely to provide our services
• Generated vocabulary lessons are based on your uploaded content
• You may not redistribute or resell our AI-generated content

The Starmory name, logo, and all related intellectual property belong to us.
''',
                          ),
                          const SizedBox(height: 24),

                          _TermsSection(
                            icon: Icons.warning_rounded,
                            iconColor: const Color(0xFFf472b6),
                            title: '6. Disclaimers',
                            content: '''
THE SERVICE IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND.

We do not guarantee:
• Uninterrupted or error-free service
• That AI-generated vocabulary will always be accurate
• That learning outcomes will meet your expectations

We are not liable for any damages arising from your use of the service.
''',
                          ),
                          const SizedBox(height: 24),

                          _TermsSection(
                            icon: Icons.shield_rounded,
                            iconColor: const Color(0xFF8b5cf6),
                            title: '7. Limitation of Liability',
                            content: '''
To the fullest extent permitted by law, Starmory shall not be liable for:

• Indirect, incidental, or consequential damages
• Loss of data or learning progress
• Service interruptions or errors
• Third-party content or links

Our total liability shall not exceed the amount you paid (if any) for the service.
''',
                          ),
                          const SizedBox(height: 24),

                          _TermsSection(
                            icon: Icons.cancel_rounded,
                            iconColor: const Color(0xFFef4444),
                            title: '8. Termination',
                            content: '''
We may suspend or terminate your account if:

• You violate these Terms of Service
• You abuse the service or quotas
• You engage in fraudulent activity
• Your account remains inactive for an extended period

You may delete your account at any time through Profile Settings.

Upon termination:
• Your right to use the service ends immediately
• We may delete your data in accordance with our Privacy Policy
''',
                          ),
                          const SizedBox(height: 24),

                          _TermsSection(
                            icon: Icons.update_rounded,
                            iconColor: const Color(0xFF60a5fa),
                            title: '9. Changes to Terms',
                            content: '''
We may modify these terms at any time. Significant changes will be communicated through in-app notification.

Continued use after changes constitutes acceptance.
''',
                          ),
                          const SizedBox(height: 24),

                          _TermsSection(
                            icon: Icons.balance_rounded,
                            iconColor: const Color(0xFFa78bfa),
                            title: '10. Governing Law',
                            content: '''
These terms are governed by the laws of Thailand. Any disputes shall be resolved through:

1. Good faith negotiation
2. Mediation
3. Appropriate courts in Thailand

For questions about these terms, please contact us through the app.
''',
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
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

class _TermsSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;

  const _TermsSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon row
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1f2937),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Content
        Text(
          content,
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4b5563),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
