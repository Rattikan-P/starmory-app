import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starmory_app/main.dart';
import 'package:starmory_app/data/services/app_state_service.dart';
import 'package:starmory_app/presentation/pages/onboarding_page.dart' show onboardingServiceProvider;
import 'test_helpers.dart';

/// Widget Tests
/// Test Function: Widget integration tests
///
/// Description: This test verifies that the app's widgets load correctly
/// and integrate properly with Riverpod providers.
void main() {
  printTestHeader('Widget Tests');

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // Mock flutter_timezone — used by NotificationService._initializePlugin()
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (MethodCall call) async {
        if (call.method == 'getLocalTimezone') return 'Asia/Bangkok';
        return null;
      },
    );

    // Mock flutter_local_notifications — used by NotificationService
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
          default:
            return null;
        }
      },
    );

    // Mock home_widget — used by MainNavigationScreen._listenToWidgetTaps()
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall call) async => null,
    );
  });

  group('Widget Tests', () {
    testWidgets('WT-01: App loads without crashing', (WidgetTester tester) async {
      // Arrange
      final appStateService = AppStateService();
      final expected = {'appLoaded': true, 'materialAppFound': true};

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingServiceProvider.overrideWithValue(appStateService),
          ],
          child: MyApp(appStateService: appStateService),
        ),
      );

      final materialAppFound = find.byType(MaterialApp);

      // Assert
      expect(materialAppFound, findsOneWidget);

      // Drain all pending async microtasks (e.g. unawaited initState futures)
      // so that no exceptions surface after the test completes on Linux CI.
      await tester.pumpAndSettle(const Duration(seconds: 3));

      printTestOutputSimple(
        testId: 'WT-01',
        description: 'App loads without crashing',
        input: 'ProviderScope with onboardingServiceProvider override',
        expectedOutput: expected,
        actualOutput: {
          'appLoaded': true,
          'materialAppFound': materialAppFound.evaluate().isNotEmpty,
        },
      );
    });
  });
}
