import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/design_tokens.dart';

/// Shared tokenized layout for errors raised during image analysis/generation.
Future<void> showTokenizedErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  Color accentColor = DesignTokens.dialogDanger,
  Color? accentTint,
  VoidCallback? onOk,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WarningIcon(
              icon: icon,
              color: accentColor,
              tint: accentTint ?? accentColor.withValues(alpha: 0.1),
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
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogBodyFontSize,
                height: DesignTokens.dialogBodyLineHeight,
                color: DesignTokens.dialogBodyColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogActionsSpacing),
            SizedBox(
              width: double.infinity,
              child: _DialogActionButton(
                label: 'OK',
                buttonColor: accentColor,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onOk?.call();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared tokenized dialog for errors that need retry/cancel actions.
Future<void> showTokenizedActionDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  String primaryLabel = 'OK',
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  Color accentColor = DesignTokens.dialogDanger,
  Color? accentTint,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WarningIcon(
              icon: icon,
              color: accentColor,
              tint: accentTint ?? accentColor.withValues(alpha: 0.1),
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
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogBodyFontSize,
                height: DesignTokens.dialogBodyLineHeight,
                color: DesignTokens.dialogBodyColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogActionsSpacing),
            if (secondaryLabel == null)
              SizedBox(
                width: double.infinity,
                child: _DialogActionButton(
                  label: primaryLabel,
                  buttonColor: accentColor,
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    onPrimary?.call();
                  },
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _DialogActionButton(
                      label: secondaryLabel,
                      outlined: true,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        onSecondary?.call();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogActionButton(
                      label: primaryLabel,
                      buttonColor: accentColor,
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        onPrimary?.call();
                      },
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

/// Shared tokenized warning shown when an image is too blurry to analyze.
Future<void> showImageQualityIssueDialog(
  BuildContext context, {
  required String message,
  required VoidCallback onTryAgain,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _WarningIcon(icon: Icons.blur_on_rounded, iconSize: 38),
            const SizedBox(height: DesignTokens.dialogIconTitleSpacing),
            Text(
              'Image Quality Issue',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogTitleFontSize,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogTitleBodySpacing),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                textAlign: TextAlign.left,
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.dialogBodyFontSize,
                  height: DesignTokens.dialogBodyLineHeight,
                  color: DesignTokens.dialogBodyColor,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.dialogActionsSpacing),
            Row(
              children: [
                Expanded(
                  child: _DialogActionButton(
                    label: 'Cancel',
                    outlined: true,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DialogActionButton(
                    label: 'Try again',
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      onTryAgain();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared warning dialog shown when a registered account reaches its daily quota.
Future<void> showDailyLimitReachedDialog(
  BuildContext context, {
  VoidCallback? onOk,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _WarningIcon(icon: Icons.wb_sunny_rounded),
            const SizedBox(height: DesignTokens.dialogIconTitleSpacing),
            Text(
              'Daily Limit Reached',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogTitleFontSize,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You've reached your 15 daily generations. Come back tomorrow for more!",
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogBodyFontSize,
                height: DesignTokens.dialogBodyLineHeight,
                color: DesignTokens.dialogSupportingTextColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogActionsSpacing),
            SizedBox(
              width: double.infinity,
              child: _DialogActionButton(
                label: 'OK',
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onOk?.call();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared warning dialogs for exhausted guest trials and unsupported images.
Future<void> showFreeTrialLimitDialog(
  BuildContext context, {
  required VoidCallback onSignUp,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _WarningIcon(icon: Icons.hourglass_bottom_rounded),
            const SizedBox(height: DesignTokens.dialogIconTitleSpacing),
            Text(
              'Free Trial Limit',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogTitleFontSize,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You've used all your guest generations.\nSign up to get 15 daily generations!",
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogBodyFontSize,
                height: DesignTokens.dialogBodyLineHeight,
                color: DesignTokens.dialogSupportingTextColor,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DesignTokens.spacingMedium),
              decoration: BoxDecoration(
                border: Border.all(
                    color: DesignTokens.dialogDisabledActionBorderColor),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: DesignTokens.dialogWarningTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: DesignTokens.dialogWarning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacingMedium),
                  Expanded(
                    child: Text(
                      '15 generations every day with a free account.',
                      style: GoogleFonts.lexend(
                        fontSize: DesignTokens.dialogBodyFontSize,
                        height: DesignTokens.dialogBodyLineHeight,
                        color: DesignTokens.dialogSupportingTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.dialogActionsSpacing),
            Row(
              children: [
                Expanded(
                  child: _DialogActionButton(
                    label: 'Later',
                    outlined: true,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogActionButton(
                    label: 'Create account',
                    multiline: true,
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      onSignUp();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showUnsupportedFormatDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WarningIcon(
                icon: Icons.insert_drive_file_rounded, showClose: true),
            const SizedBox(height: DesignTokens.dialogIconTitleSpacing),
            Text(
              'Unsupported Format',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogTitleFontSize,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogTitleBodySpacing),
            Text(
              'Only JPEG and PNG images are supported. Please select a different photo',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogBodyFontSize,
                height: DesignTokens.dialogBodyLineHeight,
                color: DesignTokens.dialogBodyColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogActionsSpacing),
            SizedBox(
              width: double.infinity,
              child: _DialogActionButton(
                label: 'OK',
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Preview-specific format warning; keeps the choose-another-photo action.
Future<void> showUnsupportedImageFormatDialog(
  BuildContext context, {
  required VoidCallback onChooseAnother,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _WarningIcon(
              icon: Icons.insert_drive_file_rounded,
              showClose: true,
            ),
            const SizedBox(height: DesignTokens.dialogIconTitleSpacing),
            Text(
              'Unsupported Image Format',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogTitleFontSize,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogTitleBodySpacing),
            Text(
              'Only JPEG and PNG images are supported.\nSupported formats: JPEG (.jpg, .jpeg) and PNG (.png)',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogBodyFontSize,
                height: DesignTokens.dialogBodyLineHeight,
                color: DesignTokens.dialogBodyColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogActionsSpacing),
            Row(
              children: [
                Expanded(
                  child: _DialogActionButton(
                    label: 'Cancel',
                    outlined: true,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DialogActionButton(
                    label: 'Choose Another Photo',
                    multiline: true,
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      onChooseAnother();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _WarningIcon extends StatelessWidget {
  final IconData? icon;
  final bool showClose;
  final Color color;
  final Color tint;
  final double iconSize;

  const _WarningIcon({
    this.icon,
    this.showClose = false,
    this.color = DesignTokens.dialogWarning,
    this.tint = DesignTokens.dialogWarningTint,
    this.iconSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DesignTokens.dialogIconSize + 10,
      height: DesignTokens.dialogIconSize + 10,
      decoration: BoxDecoration(
        color: tint,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: showClose
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon!, color: color, size: iconSize),
                  const Positioned(
                    right: 13,
                    top: 17,
                    child: Icon(Icons.close_rounded,
                        color: Colors.white, size: 14),
                  ),
                ],
              )
            : Icon(icon!, color: color, size: iconSize),
      ),
    );
  }
}

class _DialogActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool outlined;
  final bool multiline;
  final Color buttonColor;

  const _DialogActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.multiline = false,
    this.buttonColor = DesignTokens.dialogWarning,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: DesignTokens.dialogButtonHeight,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: DesignTokens.dialogDisabledActionColor,
                side: const BorderSide(
                  color: DesignTokens.dialogDisabledActionBorderColor,
                ),
                padding: _buttonPadding,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.dialogButtonRadius),
                ),
              ),
              child: _buttonLabel(),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: _buttonPadding,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.dialogButtonRadius),
                ),
              ),
              child: _buttonLabel(),
            ),
    );
  }

  Widget _buttonLabel() => Text(
        label,
        textAlign: TextAlign.center,
        maxLines: multiline ? 2 : 1,
        overflow: TextOverflow.visible,
        style: GoogleFonts.lexend(
          fontSize: DesignTokens.dialogButtonFontSize,
          fontWeight: DesignTokens.weightSemiBold,
          height: multiline ? 1.0 : null,
        ),
      );

  EdgeInsetsGeometry get _buttonPadding => multiline
      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 0)
      : const EdgeInsets.symmetric(horizontal: 16);
}
