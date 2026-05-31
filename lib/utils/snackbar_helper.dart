import 'package:flutter/material.dart';

/// SnackBar type for different message categories
enum SnackBarType {
  success,
  error,
  info,
  warning,
}

/// Helper class for showing consistent SnackBar messages across the app
class SnackBarHelper {
  SnackBarHelper._();

  /// Validate email format
  /// Returns true if email is valid, false otherwise
  static bool isValidEmail(String email) {
    if (email.trim().isEmpty) return false;

    // Basic email regex pattern
    // - Must have non-empty username before @
    // - Must have exactly one @
    // - Must have non-empty domain name
    // - Must have at least one dot in domain
    // - Must have non-empty TLD (2+ characters)
    final pattern = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    // Additional checks
    final trimmed = email.trim();

    // No spaces allowed
    if (trimmed.contains(' ')) return false;

    // Must have exactly one @
    if ('@'.allMatches(trimmed).length != 1) return false;

    // Check against regex
    return pattern.hasMatch(trimmed);
  }

  /// Show a SnackBar with the specified type and message
  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    bool showAboveKeyboard = false,
    double keyboardSpacing = 2,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    final backgroundColor = _getBackgroundColor(type);
    final icon = _getIcon(type);
    final textColor = _getTextColor(type);

    messenger.hideCurrentSnackBar();

    // Calculate margin for keyboard avoidance
    EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    SnackBarBehavior behavior = SnackBarBehavior.floating;

    if (showAboveKeyboard) {
      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
      if (keyboardHeight > 0) {
        // Keyboard is up - show above keyboard with bottom margin
        margin = EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: keyboardHeight + keyboardSpacing,
        );
      } else {
        // Keyboard is down - show at top to avoid middle of screen
        margin = const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12,
        );
      }
    }

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: behavior,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: margin,
        action: action,
      ),
    );
  }

  /// Show success message
  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    bool showAboveKeyboard = false,
    double keyboardSpacing = 2,
  }) {
    show(context, message, type: SnackBarType.success, duration: duration, showAboveKeyboard: showAboveKeyboard, keyboardSpacing: keyboardSpacing);
  }

  /// Show error message
  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    bool showAboveKeyboard = false,
    double keyboardSpacing = 2,
  }) {
    show(context, message, type: SnackBarType.error, duration: duration, showAboveKeyboard: showAboveKeyboard, keyboardSpacing: keyboardSpacing);
  }

  /// Show info message
  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool showAboveKeyboard = false,
    double keyboardSpacing = 2,
  }) {
    show(context, message, type: SnackBarType.info, duration: duration, showAboveKeyboard: showAboveKeyboard, keyboardSpacing: keyboardSpacing);
  }

  /// Show warning message
  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    bool showAboveKeyboard = false,
    double keyboardSpacing = 2,
  }) {
    show(context, message, type: SnackBarType.warning, duration: duration, showAboveKeyboard: showAboveKeyboard, keyboardSpacing: keyboardSpacing);
  }

  /// Show loading indicator (dismissible message)
  static void loading(
    BuildContext context,
    String message, {
    bool showIndicator = true,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showIndicator)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            if (showIndicator) const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF8b5cf6),
        duration: const Duration(minutes: 30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Hide current SnackBar
  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  static Color _getBackgroundColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return const Color(0xFF10B981);
      case SnackBarType.error:
        return const Color(0xFFEF4444);
      case SnackBarType.warning:
        return const Color(0xFFF59E0B);
      case SnackBarType.info:
        return const Color(0xFF3B82F6);
    }
  }

  static Color _getTextColor(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
      case SnackBarType.error:
      case SnackBarType.warning:
      case SnackBarType.info:
        return Colors.white;
    }
  }

  static IconData? _getIcon(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return Icons.check_circle;
      case SnackBarType.error:
        return Icons.error;
      case SnackBarType.warning:
        return Icons.warning;
      case SnackBarType.info:
        return Icons.info;
    }
  }
}

/// Predefined alert messages for common scenarios
class AlertMessages {
  AlertMessages._();

  // Auth / Login
  static const String loginSuccess = 'Login successful!';
  static const String loginFailed = 'Login failed. Please try again.';
  static const String logoutFailed = 'Logout failed. Please try again.';
  static const String welcomeBack = 'Welcome back!';
  static const String welcomeToApp = 'Welcome to Starmory!';
  static const String loggingIn = 'Logging in...';
  static const String noAccountFound = 'No account found with this email.';

  // OTP
  static const String otpSent = 'OTP sent to your email.';
  static const String otpSendFailed = 'Failed to send OTP. Please try again.';
  /// Covers: wrong digits, expired, already used, malformed
  static const String otpInvalid = 'Invalid OTP. Please try again or request a new one.';
  static const String otpResent = 'New OTP sent!';
  static const String verifyingOtp = 'Verifying...';

  // Network
  static const String noInternet = 'No internet connection. Please check your network.';
  static const String requestTimeout = 'Request timed out. Please try again.';
  static const String serviceUnavailable = 'Service unavailable. Please try again later.';
  static const String loading = 'Loading...';
  static const String pleaseWait = 'Please wait...';

  // Save / Settings
  static const String changesSaved = 'Changes saved successfully.';
  static const String saveFailed = 'Failed to save changes. Please try again.';
  static const String noChanges = 'No changes to save.';
  static const String saving = 'Saving...';

  // Account
  static const String passwordResetSent = 'Password reset email sent.';
  static const String accountDeleted = 'Account deleted successfully.';
  static const String deleteAccountFailed = 'Failed to delete account. Please try again.';

  // Validation
  static const String invalidEmail = 'Please enter a valid email address.';
  static const String emailRequired = 'Please enter your email address.';
  static const String passwordRequired = 'Please enter your password.';
  static const String passwordTooShort = 'Password must be at least 8 characters.';
}
