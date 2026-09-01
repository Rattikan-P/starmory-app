import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starmory_app/data/models/scrapbook_model.dart';
import 'package:starmory_app/data/services/hive_service.dart';
import 'package:starmory_app/data/services/image_storage_service.dart';
import 'package:starmory_app/data/services/review_service.dart';
import 'package:starmory_app/data/services/vocabulary_sync_service.dart';
import 'package:starmory_app/presentation/providers/providers.dart';
import 'package:starmory_app/presentation/providers/scrapbook_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes only the local Supabase client needed by screen constructors.
/// Widget tests never make a network request.
Future<void> initializeScrapbookTestDependencies() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    Supabase.instance.client;
    return;
  } catch (_) {}
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    anonKey: 'test-anon-key',
  );
}

ScrapbookModel scrapbook({
  required String id,
  required DateTime date,
  DateTime? createdAt,
  String emoji = '😊',
  String imagePath = '',
  List<ScrapbookVocabularyWord> vocabulary = const [],
}) =>
    ScrapbookModel(
      id: id,
      date: date,
      imagePath: imagePath,
      createdAt: createdAt ?? date,
      selectedEmoji: emoji,
      vocabularyWords: vocabulary,
    );

Widget scrapbookTestApp({
  required Widget child,
  List<ScrapbookModel> scrapbooks = const [],
  String? error,
  bool isLoading = false,
}) {
  final state = ScrapbookState(
    scrapbooks: scrapbooks,
    error: error,
    isLoading: isLoading,
  );
  return ProviderScope(
    overrides: [
      scrapbookStateProvider.overrideWith(
        (ref) => FakeScrapbookNotifier(state),
      ),
      vocabularyStateProvider.overrideWith(
        (ref) => FakeVocabularyNotifier(),
      ),
      userStateProvider.overrideWith(
        (ref) => FakeUserNotifier(),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

class FakeUserNotifier extends UserNotifier {
  FakeUserNotifier([UserState state = const UserState(isLoading: false)])
      : super(
          HiveService(),
          initialState: state,
          autoLoad: false,
        );
}

class FakeVocabularyNotifier extends VocabularyNotifier {
  FakeVocabularyNotifier([VocabularyState state = const VocabularyState(isLoading: false)])
      : super(
          HiveService(),
          VocabularySyncService(),
          ReviewService(hiveService: HiveService()),
          initialState: state,
          autoLoad: false,
        );
}

/// A provider replacement that never starts Hive/cloud work. It gives widget
/// tests a fixed state while preserving the production provider's type.
class FakeScrapbookNotifier extends ScrapbookNotifier {
  FakeScrapbookNotifier(ScrapbookState state)
      : super(
          HiveService(),
          ImageStorageService(),
          initialState: state,
          autoLoad: false,
        );
}
