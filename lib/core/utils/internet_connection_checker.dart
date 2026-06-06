import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utility for checking internet connection
class InternetConnectionChecker {
  /// Check if device has active internet connection
  /// Returns true if can connect to external servers, false otherwise
  static Future<bool> hasInternetConnection() async {
    try {
      // Try to resolve a hostname - this checks actual internet connectivity
      // not just WiFi/Mobile data status
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
      return false;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check multiple reliable endpoints for better accuracy
  static Future<bool> hasInternetConnectionReliable() async {
    final hosts = ['google.com', 'cloudflare.com', 'apple.com'];

    for (final host in hosts) {
      try {
        final result = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          debugPrint('✅ Internet check passed via $host');
          return true;
        }
      } catch (_) {
        // Try next host
        continue;
      }
    }

    debugPrint('❌ No internet connection detected');
    return false;
  }
}
