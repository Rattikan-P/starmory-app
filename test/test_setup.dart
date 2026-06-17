import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test setup configuration
///
/// Since AuthService uses Supabase.instance.client which requires initialization,
/// we need to provide minimal Supabase config for unit tests.

Future<void> setupTestEnvironment() async {
  // Ensure Flutter binding is initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  // Check if already initialized
  try {
    Supabase.instance.client;
    // If we get here, it's already initialized
    return;
  } catch (e) {
    // Not initialized, proceed with test setup
  }

  // Mock SharedPreferences with empty initial values
  SharedPreferences.setMockInitialValues({});

  // Initialize Supabase with test configuration
  // This allows AuthService to be instantiated without errors
  await Supabase.initialize(
    url: 'https://test.supabase.co',
    anonKey: 'test-anon-key-for-unit-tests',
    debug: false, // Disable debug logs for cleaner test output
  );
}

/// Tear down test environment
Future<void> teardownTestEnvironment() async {
  // Supabase doesn't have a direct cleanup method for tests
  // Tests will use the same instance across the test run
}
