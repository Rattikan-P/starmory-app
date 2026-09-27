import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../constants/design_tokens.dart';

/// Shows the shared camera/photo-library permission dialog.
Future<void> showPermissionRequiredDialog(
  BuildContext context,
  String type,
) async {
  final isCamera = type == 'Camera';
  const accentColor = DesignTokens.dialogInfo;
  const accentTint = Color(0xFFE7F6FF);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.dialogRadius),
      ),
      backgroundColor: Colors.white,
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
            Container(
              width: DesignTokens.dialogIconSize,
              height: DesignTokens.dialogIconSize,
              decoration: const BoxDecoration(
                color: accentTint,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isCamera
                      ? Icons.no_photography_rounded
                      : Icons.hide_image_rounded,
                  color: accentColor,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: DesignTokens.dialogIconTitleSpacing),
            Text(
              '$type Permission Required',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogTitleFontSize,
                fontWeight: FontWeight.w700,
                color: DesignTokens.dialogTitleColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogTitleBodySpacing),
            Text(
              'Please grant $type permission to continue.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.dialogBodyFontSize,
                height: DesignTokens.dialogBodyLineHeight,
                fontWeight: FontWeight.w400,
                color: DesignTokens.dialogBodyColor,
              ),
            ),
            const SizedBox(height: DesignTokens.dialogActionsSpacing),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: DesignTokens.dialogButtonHeight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DesignTokens.dialogDisabledActionColor,
                        side: const BorderSide(
                          color: DesignTokens.dialogDisabledActionBorderColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DesignTokens.dialogButtonRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.lexend(
                          fontSize: DesignTokens.dialogButtonFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: DesignTokens.dialogButtonHeight,
                    child: ElevatedButton(
                      onPressed: () {
                        openAppSettings();
                        Navigator.pop(dialogContext);
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DesignTokens.dialogButtonRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        'Settings',
                        style: GoogleFonts.lexend(
                          fontSize: DesignTokens.dialogButtonFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
