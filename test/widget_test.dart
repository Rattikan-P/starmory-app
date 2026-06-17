import 'package:flutter/material.dart';
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
