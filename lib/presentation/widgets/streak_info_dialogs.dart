import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/design_tokens.dart';

/// The shared streak information dialog used by the top header and profile.
void showStreakInfoDialog(BuildContext context, int streakDays) {
  _showStreakInfoDialog(
    context,
    icon: Icons.local_fire_department_rounded,
    title: '$streakDays Day Streak',
    description: 'Practice vocabulary daily to keep your streak going.',
    buttonLabel: 'Keep learning',
    items: [
      _buildInfoItem(
        icon: Icons.calendar_month_rounded,
        iconColor: DesignTokens.dialogInfo,
        bgColor: DesignTokens.dialogInfoTint,
        title: 'Daily Habit',
        description: 'Take photos or review word cards every day',
      ),
    ],
  );
}

/// The shared shield information dialog used by the top header and profile.
void showShieldInfoDialog(BuildContext context, int shields) {
  _showStreakInfoDialog(
    context,
    icon: Icons.shield_outlined,
    iconWidget: const FaIcon(
      FontAwesomeIcons.shieldHalved,
      color: DesignTokens.dialogInfo,
      size: 38,
    ),
    title: '$shields Streak Shields',
    description: 'Don\'t let a missed day break your streak.',
    buttonLabel: 'Got it',
    items: [
      _buildInfoItem(
        icon: Icons.shield_rounded,
        shieldHeartIcon: true,
        iconColor: DesignTokens.dialogInfo,
        bgColor: DesignTokens.dialogInfoTint,
        title: 'Shield Protection',
        description: 'Each shield protects your streak for 1 missed day',
      ),
      const SizedBox(height: DesignTokens.spacingMedium),
      _buildInfoItem(
        icon: Icons.star_rounded,
        iconColor: DesignTokens.dialogInfo,
        bgColor: DesignTokens.dialogInfoTint,
        title: 'Earn Shields',
        description: 'Keep learning for 7 days to earn a new shield',
      ),
    ],
  );
}

void _showStreakInfoDialog(
  BuildContext context, {
  required IconData icon,
  Widget? iconWidget,
  required String title,
  required String description,
  required String buttonLabel,
  required List<Widget> items,
}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: DesignTokens.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.dialogRadius),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.dialogInsetHorizontal,
        vertical: DesignTokens.dialogInsetVertical,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.dialogPaddingHorizontal,
          vertical: DesignTokens.dialogPaddingVertical,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: DesignTokens.dialogIconSize + 10,
                height: DesignTokens.dialogIconSize + 10,
                decoration: const BoxDecoration(
                  color: DesignTokens.dialogInfoTint,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: iconWidget ??
                      Icon(icon, color: DesignTokens.dialogInfo, size: 38),
                ),
              ),
              const SizedBox(height: DesignTokens.dialogIconTitleSpacing),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.dialogTitleFontSize,
                  fontWeight: DesignTokens.weightSemiBold,
                  color: DesignTokens.dialogTitleColor,
                ),
              ),
              const SizedBox(height: DesignTokens.dialogTitleBodySpacing),
              Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.dialogBodyFontSize,
                  height: DesignTokens.dialogBodyLineHeight,
                  fontWeight: DesignTokens.weightRegular,
                  color: DesignTokens.dialogSupportingTextColor,
                ),
              ),
              const SizedBox(height: DesignTokens.dialogActionsSpacing),
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacingMedium),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(
                    color: DesignTokens.dialogAccentBorderColor(
                      DesignTokens.dialogInfo,
                    ),
                  ),
                ),
                child: Column(children: items),
              ),
              const SizedBox(height: DesignTokens.dialogActionsSpacing),
              SizedBox(
                width: double.infinity,
                height: DesignTokens.dialogButtonHeight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.dialogInfo,
                    foregroundColor: DesignTokens.textOnDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DesignTokens.dialogButtonRadius,
                      ),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: GoogleFonts.lexend(
                      fontSize: DesignTokens.dialogButtonFontSize,
                      fontWeight: DesignTokens.weightSemiBold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildInfoItem({
  required IconData icon,
  bool shieldHeartIcon = false,
  required Color iconColor,
  required Color bgColor,
  required String title,
  required String description,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: DesignTokens.spacingSmall),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: shieldHeartIcon
              ? const _ShieldHeartIcon()
              : Icon(icon, size: 24, color: iconColor),
        ),
        const SizedBox(width: DesignTokens.spacingMedium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.dialogBodyFontSize,
                  fontWeight: DesignTokens.weightSemiBold,
                  color: DesignTokens.dialogInfo,
                ),
              ),
              const SizedBox(height: DesignTokens.spacingBase),
              Text(
                description,
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.fontSizeSmall,
                  fontWeight: DesignTokens.weightRegular,
                  color: DesignTokens.dialogSupportingTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ShieldHeartIcon extends StatelessWidget {
  const _ShieldHeartIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.shield_rounded,
            color: DesignTokens.dialogInfo,
            size: 24,
          ),
          Icon(
            Icons.favorite_rounded,
            color: DesignTokens.dialogInfoTint,
            size: 11,
          ),
        ],
      ),
    );
  }
}
