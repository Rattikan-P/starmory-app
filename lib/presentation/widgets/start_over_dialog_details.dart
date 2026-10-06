import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/design_tokens.dart';

/// Summary of the learning data Start Over clears and the preferences it keeps.
class StartOverDialogDetails extends StatelessWidget {
  const StartOverDialogDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: DesignTokens.dialogDanger.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            children: const [
              _StartOverDetailRow(
                icon: Icons.menu_book_rounded,
                title: 'Vocabulary Deleted',
                description:
                    'Saved words and scrapbook data on this device will be removed',
              ),
              SizedBox(height: 12),
              _StartOverDetailRow(
                icon: Icons.bar_chart_rounded,
                title: 'Progress Reset',
                description: 'Review progress and statistics will be reset',
              ),
              SizedBox(height: 12),
              _StartOverDetailRow(
                icon: Icons.local_fire_department_rounded,
                title: 'Streak Cleared',
                description: 'Your streak and shields will be reset',
              ),
              SizedBox(height: 12),
              _StartOverDetailRow(
                icon: Icons.settings_rounded,
                title: 'Settings Kept',
                description: 'Language level and variant will be preserved',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: DesignTokens.dialogDangerTint,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_rounded,
                size: 18,
                color: DesignTokens.dialogDanger,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Are you sure you want to start over?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: DesignTokens.weightSemiBold,
                    color: DesignTokens.dialogDanger,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StartOverDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _StartOverDetailRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: DesignTokens.dialogDangerTint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: DesignTokens.dialogDanger),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: DesignTokens.weightSemiBold,
                  color: DesignTokens.dialogDanger,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  height: 1.3,
                  color: DesignTokens.dialogSupportingTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
