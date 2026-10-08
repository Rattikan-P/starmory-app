import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../constants/design_tokens.dart';

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
                    decoration: BoxDecoration(
                      color: iconBgColor ?? DesignTokens.dialogBrandTint,
                      shape: BoxShape.circle,
                    ),
                    child: iconText != null
                        ? Text(iconText!, style: const TextStyle(fontSize: 20))
                        : Icon(icon,
                            size: 21, color: const Color(0xFF8957F5)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            color: DesignTokens.textPrimary,
                            fontWeight: DesignTokens.weightSemiBold,
                          ),
                        ),
                        if (useSubtitleMode || value != null)
                          const SizedBox(height: 3),
                        if (useSubtitleMode)
                          Text(
                            subtitle!,
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              color: DesignTokens.textSecondary,
                            ),
                          )
                        else if (value != null)
                          Text(
                            value!,
                            style: GoogleFonts.lexend(
                              fontSize: 13,
                              fontWeight: DesignTokens.weightMedium,
                              color: DesignTokens.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Animated chevron
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F2F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF9CA3AF),
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
            color: bgColor ?? DesignTokens.dialogDanger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: DesignTokens.dialogDanger,
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
                  color: DesignTokens.dialogDanger,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: DesignTokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Switch item widget used for toggling settings like notifications
class ProfileSwitchItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;
  final Color? iconBgColor;

  const ProfileSwitchItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.showDivider,
    this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBgColor ?? DesignTokens.dialogBrandTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 21, color: const Color(0xFF8957F5)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lexend(
                        fontSize: 14,
                        color: DesignTokens.textPrimary,
                        fontWeight: DesignTokens.weightSemiBold,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: DesignTokens.brandColor,
                activeThumbColor: Colors.white,
              ),
            ],
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
