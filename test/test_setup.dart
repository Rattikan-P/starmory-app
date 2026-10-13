import 'package:flutter/services.dart';
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

  // Register mock platform channels so tests don't throw MissingPluginException
  // on headless Linux CI where no native plugins are registered.
  _registerTestChannelMocks();

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

/// Register mock handlers for all platform channels used by production code.
/// Must be safe to call multiple times (each registration simply overwrites).
void _registerTestChannelMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // flutter_timezone — used by NotificationService._initializePlugin()
  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter_timezone'),
    (MethodCall call) async {
      if (call.method == 'getLocalTimezone') return 'Asia/Bangkok';
      return null;
    },
  );

  // flutter_local_notifications — used by NotificationService
  messenger.setMockMethodCallHandler(
    const MethodChannel('dexterous.com/flutter/local_notifications'),
    (MethodCall call) async {
      switch (call.method) {
        case 'initialize':
        case 'createNotificationChannel':
        case 'requestNotificationsPermission':
        case 'areNotificationsEnabled':
          return true;
        case 'getNotificationAppLaunchDetails':
          return null;
        case 'zonedSchedule':
        case 'cancel':
        case 'cancelAll':
        case 'pendingNotificationRequests':
          return null;
        default:
          return null;
      }
    },
  );

  // home_widget — used by MainNavigationScreen._listenToWidgetTaps()
  messenger.setMockMethodCallHandler(
    const MethodChannel('home_widget'),
    (MethodCall call) async => null,
  );
}

/// Tear down test environment
Future<void> teardownTestEnvironment() async {
  // Supabase doesn't have a direct cleanup method for tests
  // Tests will use the same instance across the test run
}
