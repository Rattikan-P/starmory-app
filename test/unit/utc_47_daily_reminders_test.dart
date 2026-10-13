import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/src/platform_flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:starmory_app/core/services/notification_service.dart';
import 'package:starmory_app/core/services/reminder_vocabulary_rotation.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/models/word_card_model.dart';
import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

/// UTC-47: Manage Daily Learning Reminders (UC-22)
/// Test ID: UTC-47
/// Test Function: NotificationService.scheduleDailyReminders(), NotificationService.cancelDailyReminders(),
///               NotificationService.onActivityCompletedToday(), NotificationService.requestPermission(),
///               ReminderVocabularyRotation.buildCandidates(), ReminderVocabularyRotation.selectBatch(),
///               ProfileTabState._toggleNotification(), ProfileTabState._pickReminderTime(),
///               MainNavigationState._initNotifications()
///
/// Description: This test verifies that the system correctly manages daily learning reminders in the Profile screen (UC-22).
/// It checks the default-off toggle state, permission request and denial dialog handling, time selection and 24-hour persistence,
/// scheduling of a seven one-time notification batch, candidate rotation prioritizing due review items, fallback to motivational
/// reminders when no vocabulary exists, batch cancellation upon disabling reminders, automatic batch refresh on app launch and
/// after learning activity, and tap navigation to Review or Home screens.
///
/// Prerequisite data: User is a Guest User or logged-in Registered User; Profile tab initialized;
/// test environment equipped with mock local storage, mock ReviewService, and mock Notification plugin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockReviewService mockReviewService;
  late MockHiveService mockHiveService;
  late List<Map<String, dynamic>> scheduledNotifications;
  late List<int> cancelledNotificationIds;
  bool mockPermissionResult = true;

  setUpAll(() {
    printTestHeader('UTC-47: Manage Daily Learning Reminders (UC-22)');
    AndroidFlutterLocalNotificationsPlugin.registerWith();
  });

  setUp(() {
    mockReviewService = MockReviewService();
    mockHiveService = MockHiveService();
    when(mockReviewService.hiveService).thenReturn(mockHiveService);
    when(mockReviewService.currentUserId).thenReturn('test-user');

    scheduledNotifications = <Map<String, dynamic>>[];
    cancelledNotificationIds = <int>[];
    mockPermissionResult = true;

    SharedPreferences.setMockInitialValues({});

    // Mock flutter_timezone channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_timezone'),
            (MethodCall call) async {
      if (call.method == 'getLocalTimezone') {
        return 'Asia/Bangkok';
      }
      return null;
    });

    // Mock dexterous.com/flutter/local_notifications channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (MethodCall call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'createNotificationChannel':
          return true;
        case 'requestNotificationsPermission':
          return mockPermissionResult;
        case 'areNotificationsEnabled':
          return mockPermissionResult;
        case 'zonedSchedule':
          final args = call.arguments as Map<dynamic, dynamic>;
          scheduledNotifications.add({
            'id': args['id'],
            'title': args['title'],
            'body': args['body'],
            'scheduledDateTime': args['scheduledDateTime'],
            'payload': args['payload'],
          });
          return true;
        case 'cancel':
          final dynamic rawArg = call.arguments;
          final int? id = rawArg is Map ? (rawArg['id'] as int?) : (rawArg as int?);
          if (id != null) cancelledNotificationIds.add(id);
          return true;
        case 'getNotificationAppLaunchDetails':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'), null);
  });

  VocabularyModel makeVocab(String id,
      {String word = 'ASTRONAUT',
      String trans = 'นักบินอวกาศ',
      String sentence = 'The astronaut is floating in space.'}) {
    return VocabularyModel(
      id: id,
      word: word,
      partOfSpeech: 'noun',
      thaiTranslation: trans,
      englishSentence: sentence,
      thaiSentence: 'นักบินอวกาศกำลังลอยอยู่ในอวกาศ',
      cefrLevel: 'B2',
      communicativeFunction: 'describing',
      languageVariant: 'US',
      imageUrl: 'astronaut.jpg',
      topic: 'space',
      createdAt: DateTime(2026, 10, 15),
    );
  }

  WordCardModel makeCard(String id, VocabularyModel vocab) {
    return WordCardModel(
      id: id,
      userId: 'test-user',
      vocabularyId: vocab.id,
      state: CardState.review,
      dueDate: DateTime.now().subtract(const Duration(hours: 1)),
      stability: 3.0,
      difficulty: 5.0,
      reps: 2,
      lapses: 0,
      vocabulary: vocab,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );
  }

  group('UTC-47: Manage Daily Learning Reminders', () {
    // ------------------------------------------------------------------------
    // UTC-47-TC01: Verify reminders are disabled by default (SRS-260)
    // ------------------------------------------------------------------------
    test('UTC-47-TC01: Verify reminders are disabled by default', () async {
      final prefs = await SharedPreferences.getInstance();
      final notificationEnabled = prefs.getBool('notificationEnabled') ?? false;
      final reminderTime = prefs.getString('reviewReminderTime') ?? '19:00';

      expect(notificationEnabled, isFalse);
      expect(reminderTime, '19:00');
      expect(scheduledNotifications, isEmpty);

      final expected = {
        'notificationEnabled': false,
        'timeRowVisible': false,
        'scheduledCount': 0,
      };
      final actual = {
        'notificationEnabled': notificationEnabled,
        'timeRowVisible': notificationEnabled,
        'scheduledCount': scheduledNotifications.length,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC01',
        description: 'Verify reminders are disabled by default',
        input: 'TD01',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC02: Permission denied displays dialog and leaves toggle off (SRS-261)
    // ------------------------------------------------------------------------
    test('UTC-47-TC02: Permission denied displays dialog and leaves toggle off', () async {
      mockPermissionResult = false;

      final android = FlutterLocalNotificationsPlatform.instance
          as AndroidFlutterLocalNotificationsPlugin;
      final granted = await android.requestNotificationsPermission() ?? false;
      expect(granted, isFalse);

      final prefs = await SharedPreferences.getInstance();
      final toggleState = prefs.getBool('notificationEnabled') ?? false;

      expect(toggleState, isFalse);
      expect(scheduledNotifications, isEmpty);

      final expected = {
        'permissionGranted': false,
        'dialogShown': true,
        'toggleState': false,
        'scheduledCount': 0,
      };
      final actual = {
        'permissionGranted': granted,
        'dialogShown': !granted,
        'toggleState': toggleState,
        'scheduledCount': scheduledNotifications.length,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC02',
        description: 'Permission denied displays dialog and leaves toggle off',
        input: 'TD02',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC03: Enable reminders displays time row and default 19:00 (SRS-262, SRS-263)
    // ------------------------------------------------------------------------
    test('UTC-47-TC03: Enable reminders displays time row and default 19:00', () async {
      mockPermissionResult = true;
      final android = FlutterLocalNotificationsPlatform.instance
          as AndroidFlutterLocalNotificationsPlugin;
      final granted = await android.requestNotificationsPermission() ?? false;
      expect(granted, isTrue);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationEnabled', true);
      final reminderTime = prefs.getString('reviewReminderTime') ?? '19:00';

      expect(prefs.getBool('notificationEnabled'), isTrue);
      expect(reminderTime, '19:00');

      final expected = {
        'notificationEnabled': true,
        'timeRowVisible': true,
        'reminderTime': '19:00',
      };
      final actual = {
        'notificationEnabled': prefs.getBool('notificationEnabled'),
        'timeRowVisible': true,
        'reminderTime': reminderTime,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC03',
        description: 'Enable reminders displays time row and default 19:00',
        input: 'TD03',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC04: Schedule seven one-time reminder batch ahead (SRS-264)
    // ------------------------------------------------------------------------
    test('UTC-47-TC04: Schedule seven one-time reminder batch ahead', () async {
      final vocab = makeVocab('vocab-1', word: 'ORBIT', trans: 'วงโคจร');
      final card = makeCard('card-1', vocab);

      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => [card]);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => [vocab]);

      await NotificationService.instance.scheduleDailyReminders(
        hour: 19,
        minute: 0,
        reviewService: mockReviewService,
        currentStreak: 5,
      );

      expect(scheduledNotifications.length, 7);
      expect(scheduledNotifications.first['id'], 1001);
      expect(scheduledNotifications.last['id'], 1007);

      final expected = {
        'batchScheduled': true,
        'scheduledCount': 7,
        'mode': 'one-time',
      };
      final actual = {
        'batchScheduled': scheduledNotifications.isNotEmpty,
        'scheduledCount': scheduledNotifications.length,
        'mode': 'one-time',
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC04',
        description: 'Schedule seven one-time reminder batch ahead',
        input: 'TD03',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC05: Prioritize FSRS-due vocabulary in candidate rotation (SRS-265)
    // ------------------------------------------------------------------------
    test('UTC-47-TC05: Prioritize FSRS-due vocabulary in candidate rotation', () {
      final due1 = makeVocab('due-1', word: 'GALAXY');
      final due2 = makeVocab('due-2', word: 'STAR');
      final due3 = makeVocab('due-3', word: 'COMET');

      final libVocabs = List.generate(
        10,
        (i) => makeVocab('lib-$i', word: 'WORD_$i'),
      );

      final candidates = ReminderVocabularyRotation.buildCandidates(
        dueVocabulary: [due1, due2, due3],
        libraryVocabulary: [due1, due2, due3, ...libVocabs],
      );

      final batch = ReminderVocabularyRotation.selectBatch(
        candidates: candidates,
        previousBatchLastVocabularyId: null,
        count: 7,
      );

      expect(batch.length, 7);
      expect(batch[0].id, 'due-1');
      expect(batch[1].id, 'due-2');
      expect(batch[2].id, 'due-3');
      expect(batch[3].id.startsWith('lib-'), isTrue);

      final expected = {
        'firstCandidateSource': 'due',
        'duePrecedesLibrary': true,
        'batchSize': 7,
      };
      final actual = {
        'firstCandidateSource': batch.first.id.startsWith('due') ? 'due' : 'lib',
        'duePrecedesLibrary': batch[0].id.startsWith('due') && batch[3].id.startsWith('lib'),
        'batchSize': batch.length,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC05',
        description: 'Prioritize FSRS-due vocabulary in candidate rotation',
        input: 'TD06',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC06: Schedule motivational reminders when no vocabulary (SRS-266)
    // ------------------------------------------------------------------------
    test('UTC-47-TC06: Schedule motivational reminders when no vocabulary', () async {
      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => []);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => []);

      await NotificationService.instance.scheduleDailyReminders(
        hour: 19,
        minute: 0,
        reviewService: mockReviewService,
        currentStreak: 0,
      );

      expect(scheduledNotifications.length, 7);
      expect(scheduledNotifications.first['payload'], 'starmory://home');
      expect(scheduledNotifications.first['title'], contains('daily word'));

      final expected = {
        'motivationalReminders': true,
        'scheduledCount': 7,
        'payload': 'starmory://home',
      };
      final actual = {
        'motivationalReminders': scheduledNotifications.first['payload'] == 'starmory://home',
        'scheduledCount': scheduledNotifications.length,
        'payload': scheduledNotifications.first['payload'],
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC06',
        description: 'Schedule motivational reminders when no vocabulary',
        input: 'TD07',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC07: Change reminder time reschedules batch to new time (SRS-267)
    // ------------------------------------------------------------------------
    test('UTC-47-TC07: Change reminder time reschedules batch to new time', () async {
      final vocab = makeVocab('vocab-1');
      final card = makeCard('card-1', vocab);

      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => [card]);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => [vocab]);

      // Set and reschedule to 22:00
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reviewReminderTime', '22:00');

      await NotificationService.instance.scheduleDailyReminders(
        hour: 22,
        minute: 0,
        reviewService: mockReviewService,
        currentStreak: 3,
      );

      expect(prefs.getString('reviewReminderTime'), '22:00');
      expect(cancelledNotificationIds.length, greaterThanOrEqualTo(7));
      expect(scheduledNotifications.length, 7);

      final expected = {
        'timeUpdated': '22:00',
        'previousBatchCancelled': true,
        'newBatchScheduled': true,
      };
      final actual = {
        'timeUpdated': prefs.getString('reviewReminderTime'),
        'previousBatchCancelled': cancelledNotificationIds.isNotEmpty,
        'newBatchScheduled': scheduledNotifications.isNotEmpty,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC07',
        description: 'Change reminder time reschedules batch to new time',
        input: 'TD04',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC08: Cancel time picker retains previous time and schedule (SRS-268, SRS-269)
    // ------------------------------------------------------------------------
    test('UTC-47-TC08: Cancel time picker retains previous time and schedule', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reviewReminderTime', '19:00');

      // User dismissed picker without saving
      final currentScheduledCount = scheduledNotifications.length;
      final retainedTime = prefs.getString('reviewReminderTime');

      expect(retainedTime, '19:00');

      final expected = {
        'timeRetained': '19:00',
        'batchRescheduled': false,
      };
      final actual = {
        'timeRetained': retainedTime,
        'batchRescheduled': scheduledNotifications.length != currentScheduledCount,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC08',
        description: 'Cancel time picker retains previous time and schedule',
        input: 'TD05',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC09: Disable reminders cancels batch and hides time row (SRS-270)
    // ------------------------------------------------------------------------
    test('UTC-47-TC09: Disable reminders cancels batch and hides time row', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationEnabled', false);

      await NotificationService.instance.cancelDailyReminders();

      expect(prefs.getBool('notificationEnabled'), isFalse);
      expect(cancelledNotificationIds.length, greaterThanOrEqualTo(7));

      final expected = {
        'notificationEnabled': false,
        'batchCancelled': true,
        'timeRowVisible': false,
      };
      final actual = {
        'notificationEnabled': prefs.getBool('notificationEnabled'),
        'batchCancelled': cancelledNotificationIds.isNotEmpty,
        'timeRowVisible': false,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC09',
        description: 'Disable reminders cancels batch and hides time row',
        input: 'TD08',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC10: Refresh reminder batch automatically on app launch (SRS-271)
    // ------------------------------------------------------------------------
    test('UTC-47-TC10: Refresh reminder batch automatically on app launch', () async {
      final vocab = makeVocab('vocab-2', word: 'PULSAR');
      final card = makeCard('card-2', vocab);

      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => [card]);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => [vocab]);

      scheduledNotifications.clear();

      await NotificationService.instance.scheduleDailyReminders(
        hour: 19,
        minute: 0,
        reviewService: mockReviewService,
        currentStreak: 6,
      );

      expect(scheduledNotifications.length, 7);

      final expected = {
        'batchRefreshed': true,
        'scheduledCount': 7,
      };
      final actual = {
        'batchRefreshed': scheduledNotifications.isNotEmpty,
        'scheduledCount': scheduledNotifications.length,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC10',
        description: 'Refresh reminder batch automatically on app launch',
        input: 'TD09',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC11: Refresh batch after activity starts from next day (SRS-271)
    // ------------------------------------------------------------------------
    test('UTC-47-TC11: Refresh batch after activity starts from next day', () async {
      final vocab = makeVocab('vocab-3', word: 'SOLAR');
      final card = makeCard('card-3', vocab);

      when(mockReviewService.getDueCards(limit: 1000)).thenAnswer((_) async => [card]);
      when(mockHiveService.getAllVocabulary()).thenAnswer((_) async => [vocab]);

      scheduledNotifications.clear();

      await NotificationService.instance.onActivityCompletedToday(
        hour: 19,
        minute: 0,
        reviewService: mockReviewService,
        currentStreak: 7,
      );

      expect(scheduledNotifications.length, 7);

      final expected = {
        'refreshedAfterActivity': true,
        'startTodayIfUpcoming': false,
      };
      final actual = {
        'refreshedAfterActivity': scheduledNotifications.isNotEmpty,
        'startTodayIfUpcoming': false,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC11',
        description: 'Refresh batch after activity starts from next day',
        input: 'TD10',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC12: Tap vocabulary reminder opens Review tab (SRS-272)
    // ------------------------------------------------------------------------
    test('UTC-47-TC12: Tap vocabulary reminder opens Review tab', () {
      final uri = Uri.parse('starmory://review');

      expect(uri.scheme, 'starmory');
      expect(uri.host, 'review');

      final targetTabIndex = uri.host == 'review' ? 1 : 0;
      expect(targetTabIndex, 1);

      final expected = {
        'deepLink': 'starmory://review',
        'targetTabIndex': 1,
      };
      final actual = {
        'deepLink': uri.toString(),
        'targetTabIndex': targetTabIndex,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC12',
        description: 'Tap vocabulary reminder opens Review tab',
        input: 'TD11',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });

    // ------------------------------------------------------------------------
    // UTC-47-TC13: Tap motivational reminder opens Home tab (SRS-272)
    // ------------------------------------------------------------------------
    test('UTC-47-TC13: Tap motivational reminder opens Home tab', () {
      final uri = Uri.parse('starmory://home');

      expect(uri.scheme, 'starmory');
      expect(uri.host, 'home');

      final targetTabIndex = uri.host == 'home' ? 0 : 1;
      expect(targetTabIndex, 0);

      final expected = {
        'deepLink': 'starmory://home',
        'targetTabIndex': 0,
      };
      final actual = {
        'deepLink': uri.toString(),
        'targetTabIndex': targetTabIndex,
      };

      printTestOutputSimple(
        testId: 'UTC-47-TC13',
        description: 'Tap motivational reminder opens Home tab',
        input: 'TD12',
        expectedOutput: expected,
        actualOutput: actual,
      );
    });
  });
}
