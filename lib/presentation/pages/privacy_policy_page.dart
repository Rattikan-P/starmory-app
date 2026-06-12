import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/galaxy_screen_background.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                        'Privacy Policy',
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
                                  colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.privacy_tip_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          Center(
                            child: Text(
                              'Privacy Policy',
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
                              'Your privacy matters to us',
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
                          _PolicySection(
                            icon: Icons.data_usage_rounded,
                            iconColor: const Color(0xFF60a5fa),
                            title: '1. Information We Collect',
                            content: '''
We collect information you provide directly to us, including:

• Account information: Name, email address, and profile photo
• Learning data: Vocabulary words, photos you upload, and your progress
• Usage data: How you use the app and your learning patterns
• Device information: Device type, operating system, and unique device identifiers

We collect this information to:
• Provide and improve our learning services
• Personalize your learning experience
• Track your progress and provide motivating streaks
''',
                          ),
                          const SizedBox(height: 24),

                          _PolicySection(
                            icon: Icons.settings_rounded,
                            iconColor: const Color(0xFFa78bfa),
                            title: '2. How We Use Your Information',
                            content: '''
We use your information to:

• Deliver and improve our AI-powered vocabulary learning service
• Generate personalized lessons from your photos
• Track your learning progress and streaks
• Provide customer support
• Comply with legal obligations

We do not sell your personal data to third parties.
''',
                          ),
                          const SizedBox(height: 24),

                          _PolicySection(
                            icon: Icons.security_rounded,
                            iconColor: const Color(0xFF34d399),
                            title: '3. Data Storage and Security',
                            content: '''
Your data is stored securely:

• Registered users: Data is stored in Supabase cloud infrastructure
• Guest users: Data is stored locally on your device
• Photos and vocabulary: Stored securely
• We implement appropriate security measures to protect your data

Guest mode limitations:
• Limited to 10 total photo uploads
• Limited to 3 uploads per day
• Data may be lost if you clear app data or uninstall
''',
                          ),
                          const SizedBox(height: 24),

                          _PolicySection(
                            icon: Icons.verified_user_rounded,
                            iconColor: const Color(0xFFf472b6),
                            title: '4. Your Rights',
                            content: '''
You have the right to:

• Access your personal data
• Correct inaccurate data
• Delete your account and associated data

To exercise these rights, use the options in Profile Settings.
''',
                          ),
                          const SizedBox(height: 24),

                          _PolicySection(
                            icon: Icons.schedule_rounded,
                            iconColor: const Color(0xFFfbbf24),
                            title: '5. Data Retention',
                            content: '''
We retain your data for as long as your account is active. If you delete your account:

• Your personal data will be permanently deleted
• Your learning progress and vocabulary will be deleted
• Some data may be retained in backups for up to 30 days before permanent deletion
• Anonymous aggregated data may be retained for analytics
''',
                          ),
                          const SizedBox(height: 24),

                          _PolicySection(
                            icon: Icons.update_rounded,
                            iconColor: const Color(0xFFa78bfa),
                            title: '6. Changes to This Policy',
                            content: '''
We may update this privacy policy from time to time. We will notify you of significant changes by posting the new policy in the app.

Your continued use of the app after changes indicates acceptance of the updated policy.
''',
                          ),
                          const SizedBox(height: 24),

                          _PolicySection(
                            icon: Icons.email_rounded,
                            iconColor: const Color(0xFF8b5cf6),
                            title: '7. Contact Us',
                            content: '''
If you have questions about this privacy policy or your personal data, please contact us through the app.

We are working on setting up direct email contact and will update this section soon.
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

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;

  const _PolicySection({
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
