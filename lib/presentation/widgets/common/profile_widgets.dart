import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact list item widget used throughout profile sections
/// Shows icon, title, value/subtitle, and optional divider with tap handler
class ProfileCompactItem extends StatelessWidget {
  final IconData icon;
  final String? iconText;
  final String title;
  final String? value;
  final String? subtitle;
  final bool showDivider;
  final VoidCallback onTap;
  final Color? iconBgColor;

  const ProfileCompactItem({
    super.key,
    required this.icon,
    this.iconText,
    required this.title,
    this.value,
    this.subtitle,
    required this.showDivider,
    required this.onTap,
    this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    // Use subtitle mode if value is not provided
    final useSubtitleMode = value == null && subtitle != null;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            highlightColor: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Minimal icon - no background
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: iconText != null
                        ? Text(iconText!, style: const TextStyle(fontSize: 20))
                        : Icon(icon, size: 24, color: const Color(0xFF1f2937)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: useSubtitleMode ? 15 : 12,
                            color: useSubtitleMode
                                ? const Color(0xFF1f2937)
                                : const Color(0xFF1f2937).withValues(alpha: 0.65),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (useSubtitleMode)
                          const SizedBox(height: 3),
                        if (useSubtitleMode)
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF1f2937).withValues(alpha: 0.65),
                            ),
                          )
                        else ...[
                          const SizedBox(height: 3),
                          if (value != null)
                            Text(
                              value!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1f2937),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  // Animated chevron
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70, right: 16),
            child: Divider(
              height: 1,
              color: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
              thickness: 0.5,
            ),
          ),
      ],
    );
  }
}

/// Info item widget used in confirmation dialogs
/// Shows icon, title, and description in a compact row
class ProfileConfirmInfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color? bgColor;

  const ProfileConfirmInfoItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor ?? const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFDC2626),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6b7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
