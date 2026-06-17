// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:starmory_app/main.dart';
import 'package:starmory_app/data/services/app_state_service.dart';
import 'package:starmory_app/presentation/pages/onboarding_page.dart' show onboardingServiceProvider;

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    // Create a mock AppStateService for testing
    final appStateService = AppStateService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingServiceProvider.overrideWithValue(appStateService),
        ],
        child: MyApp(appStateService: appStateService),
      ),
    );

    // Verify that the app builds successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
