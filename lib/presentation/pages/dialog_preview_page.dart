import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/design_tokens.dart';
import '../widgets/permission_required_dialog.dart';
import '../widgets/streak_info_dialogs.dart';
import '../widgets/tokenized_notice_dialogs.dart';
import '../widgets/start_over_dialog_details.dart';

/// Debug-only gallery for reviewing the app's production dialog components.
class DialogPreviewPage extends StatelessWidget {
  const DialogPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final previews = <_DialogPreviewItem>[
      _DialogPreviewItem('Free Trial Limit', 'Guest quota · Home / Generation',
          () {
        showFreeTrialLimitDialog(context, onSignUp: () {});
      }),
      _DialogPreviewItem(
          'Daily Limit Reached',
          'Registered quota · Home / Generation',
          () => showDailyLimitReachedDialog(context)),
      _DialogPreviewItem('Camera Permission', 'Permission popup',
          () => showPermissionRequiredDialog(context, 'Camera')),
      _DialogPreviewItem(
          'Scrapbook · Photo Library Permission', 'Edit scrapbook',
          () => showPermissionRequiredDialog(context, 'Photo Library')),
      _DialogPreviewItem('Scrapbook · Unsaved Changes', 'Edit scrapbook',
          () {
        showTokenizedActionDialog(
          context,
          title: 'Unsaved Changes',
          message:
              'You have unsaved changes. Are you sure you want to leave without saving?',
          icon: Icons.save_outlined,
          accentColor: DesignTokens.dialogWarning,
          accentTint: DesignTokens.dialogWarningTint,
          secondaryLabel: 'Discard',
          primaryLabel: 'Keep Editing',
        );
      }),
      _DialogPreviewItem('Streak Info', 'Info · blue tokens',
          () => showStreakInfoDialog(context, 0)),
      _DialogPreviewItem('Shield Info', 'Info · blue tokens',
          () => showShieldInfoDialog(context, 0)),
      _DialogPreviewItem(
        'Logout Confirmation',
        'Profile: mascot and outlined brand actions',
        () => showTokenizedActionDialog(
          context,
          title: 'Logout',
          message: 'Are you sure you want to log out?',
          icon: Icons.logout_rounded,
          iconWidget: Image.asset(
            'assets/images/logout_mascot.png',
            width: 75,
            height: 75,
          ),
          secondaryLabel: 'Cancel',
          primaryLabel: 'Logout',
          accentColor: DesignTokens.dialogBrand,
          accentTint: DesignTokens.dialogBrandTint,
          primaryOutlined: true,
          barrierDismissible: false,
        ),
      ),
      _DialogPreviewItem('Start Over', 'Profile: reset progress and streak',
          () {
        showTokenizedActionDialog(
          context,
          title: 'Start Over',
          message: 'This will reset your learning progress.',
          icon: Icons.restart_alt_rounded,
          content: const StartOverDialogDetails(),
          contentBottomSpacing: DesignTokens.spacingMedium,
          secondaryLabel: 'Cancel',
          primaryLabel: 'Start Over',
          accentColor: DesignTokens.dialogDanger,
          accentTint: DesignTokens.dialogDangerTint,
          primaryOutlined: true,
        );
      }),
      _DialogPreviewItem('Unsupported Format', 'Home picker',
          () => showUnsupportedFormatDialog(context)),
      _DialogPreviewItem(
          'Unsupported Image Format',
          'Preview picker',
          () => showUnsupportedImageFormatDialog(
                context,
                onChooseAnother: () {},
              )),
      _DialogPreviewItem('Image Quality Issue', 'Image preview warning',
          () => _showImageQuality(context)),
      _DialogPreviewItem('Image Processing Failed', 'Preview error', () {
        showTokenizedErrorDialog(
          context,
          title: 'Error',
          message: 'Failed to process photo: Could not read image file.',
          icon: Icons.error_outline_rounded,
        );
      }),
      _DialogPreviewItem(
          'No Internet Connection', 'Preview · Cancel / Try Again', () {
        showTokenizedActionDialog(
          context,
          title: 'No Internet Connection',
          message: 'Please check your internet connection and try again.',
          icon: Icons.cloud_off_rounded,
          secondaryLabel: 'Cancel',
          primaryLabel: 'Try Again',
        );
      }),
      _DialogPreviewItem('Scrapbook · Photo Picker Error', 'Edit scrapbook', () {
        showTokenizedErrorDialog(
          context,
          title: 'Error',
          message: 'Failed to pick image: Unable to open the selected photo.',
          icon: Icons.photo_library_outlined,
        );
      }),
      _DialogPreviewItem(
          'Permission Request In Progress', 'Image picker permission error',
          () {
        showTokenizedErrorDialog(
          context,
          title: 'Error',
          message:
              'Failed to pick image: A permission request is already in progress. Please wait a moment, then try again.',
          icon: Icons.photo_library_outlined,
        );
      }),
      _DialogPreviewItem('Scrapbook · Photo Save Error', 'Edit scrapbook', () {
        showTokenizedErrorDialog(
          context,
          title: 'Error',
          message: 'Failed to save photo: Storage write exception.',
          icon: Icons.save_outlined,
        );
      }),
      _DialogPreviewItem('Image Analysis Failed', 'Generation error', () {
        showTokenizedErrorDialog(
          context,
          title: 'Image Analysis Failed',
          message: 'We could not analyze this photo. Please try another photo.',
          icon: Icons.image_search_rounded,
        );
      }),
      _DialogPreviewItem('Connection Error · Timeout', 'Generation error', () {
        showTokenizedErrorDialog(
          context,
          title: 'Connection Error',
          message:
              'Request timed out. Please check your connection and try again.',
          icon: Icons.access_time_rounded,
        );
      }),
      _DialogPreviewItem('Connection Error · Internet', 'Generation error', () {
        showTokenizedErrorDialog(
          context,
          title: 'Connection Error',
          message:
              'We could not connect. Please check your internet and try again.',
          icon: Icons.cloud_off_rounded,
        );
      }),
      _DialogPreviewItem('Connection Error · Service Setup', 'Generation error',
          () {
        showTokenizedErrorDialog(
          context,
          title: 'Connection Error',
          message:
              'The learning service is not available right now. Please try again later.',
          icon: Icons.settings_rounded,
        );
      }),
      _DialogPreviewItem('Connection Error · Service Busy', 'Generation error',
          () {
        showTokenizedErrorDialog(
          context,
          title: 'Connection Error',
          message:
              'The learning service is busy right now. Please try again in a moment.',
          icon: Icons.hourglass_empty_rounded,
        );
      }),
      _DialogPreviewItem('Connection Error · Other', 'Generation error', () {
        showTokenizedErrorDialog(
          context,
          title: 'Connection Error',
          message:
              'We could not create your lesson right now. Please try again.',
          icon: Icons.error_outline_rounded,
        );
      }),
      _DialogPreviewItem('Gemini API Quota', 'Generation provider limit',
          () => showGeminiQuotaErrorDialog(context)),
      _DialogPreviewItem('Gemini Sentence Request Failed', 'Vocabulary screen',
          () {
        showTokenizedErrorDialog(
          context,
          title: 'Connection Error',
          message:
              'We couldn’t generate sentences right now. Please check your connection and try again.',
          icon: Icons.cloud_off_rounded,
        );
      }),
      _DialogPreviewItem('Supabase Request Failed', 'Account data sync',
          () => showSupabaseRequestErrorDialog(context)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Dialog Preview')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: previews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = previews[index];
          return Card(
            child: ListTile(
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: item.onTap,
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showImageQuality(BuildContext context) {
    return showDialog<void>(
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
              Container(
                width: DesignTokens.dialogIconSize + 10,
                height: DesignTokens.dialogIconSize + 10,
                decoration: const BoxDecoration(
                  color: DesignTokens.dialogWarningTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.blur_on_rounded,
                  color: DesignTokens.dialogWarning,
                  size: 38,
                ),
              ),
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
                  'Image appears too blurry for accurate analysis. Please try with a clearer, well-lit photo for best results.',
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
                    child: _QualityActionButton(
                      label: 'Cancel',
                      outlined: true,
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QualityActionButton(
                      label: 'Try again',
                      onPressed: () => Navigator.pop(dialogContext),
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
}

class _DialogPreviewItem {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DialogPreviewItem(this.title, this.subtitle, this.onTap);
}

class _QualityActionButton extends StatelessWidget {
  final String label;
  final bool outlined;
  final VoidCallback onPressed;

  const _QualityActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
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
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.dialogButtonRadius),
                ),
              ),
              child: _label(),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: DesignTokens.dialogWarning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.dialogButtonRadius),
                ),
              ),
              child: _label(),
            ),
    );
  }

  Widget _label() => Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.lexend(
          fontSize: DesignTokens.dialogButtonFontSize,
          fontWeight: DesignTokens.weightSemiBold,
        ),
      );
}
