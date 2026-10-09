import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../constants/design_tokens.dart';
import '../../data/models/vocabulary_model.dart';
import '../../data/services/review_service.dart';
import 'reminder_vocabulary_rotation.dart';

/// Service managing low-friction, glanceable learning reminders.
/// Features:
/// - Seven one-time vocabulary and streak reminders scheduled ahead
/// - Tap to jump straight to the Review tab
/// - Refreshes the batch after app open or a completed learning activity
/// - Custom reminder time configuration
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _dailyReminderNotificationId = 1001;
  static const int _reminderBatchLength = 7;
  static const String _lastBatchVocabularyKey =
      'daily_learning_reminder_last_batch_vocabulary';
  static const String _channelId = 'starmory_daily_reminders';
  static const String _channelName = 'Daily Learning Reminders';
  static const String _channelDescription =
      'Glanceable daily vocabulary and learning streak reminders';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  /// Callback when user taps a notification payload (e.g. starmory://review)
  static void Function(String? payload)? onNotificationTapped;

  /// Initialize notification plugin & timezone
  Future<void> initialize(
      {void Function(String? payload)? onSelectNotification}) async {
    if (kIsWeb) return;

    if (onSelectNotification != null) {
      onNotificationTapped = onSelectNotification;
    }
    if (_isInitialized) return;
    final pendingInitialization = _initializationFuture;
    if (pendingInitialization != null) {
      await pendingInitialization;
      return;
    }

    final initialization = _initializePlugin();
    _initializationFuture = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    }
  }

  Future<void> _initializePlugin() async {
    // 1. Initialize timezone & set device local timezone
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
      debugPrint(
          '🔔 [NotificationService] Device timezone configured: ${timeZoneInfo.identifier}');
    } catch (e) {
      debugPrint(
          '⚠️ [NotificationService] Could not set local timezone from device: $e');
    }

    // 2. Android Initialization Settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS / Darwin Initialization Settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        debugPrint('🔔 [Notification] Tapped with payload: $payload');
        onNotificationTapped?.call(payload);
      },
    );

    final launchDetails =
        await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      debugPrint('🔔 [Notification] Launched app with payload: $payload');
      onNotificationTapped?.call(payload);
    }

    // 4. Create high-priority Notification Channel on Android
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    _isInitialized = true;
    debugPrint(
        '🔔 [NotificationService] Initialized successfully with channel.');
  }

  /// Request notification permission on Android 13+ and iOS
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Check if notification permission is currently granted
  Future<bool> isPermissionGranted() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final areEnabled = await androidImplementation?.areNotificationsEnabled();
      return areEnabled ?? false;
    }
    return true;
  }

  /// Replace pending learning reminders with seven one-time reminders.
  Future<void> scheduleDailyReminders({
    required int hour,
    required int minute,
    required ReviewService reviewService,
    required int currentStreak,
    bool startTodayIfUpcoming = true,
  }) async {
    if (kIsWeb) return;

    await initialize();

    if (tz.local.name == 'UTC') {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    }

    final dueCards = await reviewService.getDueCards(limit: 1000);
    final libraryVocabulary =
        await reviewService.hiveService.getAllVocabulary();
    final candidates = ReminderVocabularyRotation.buildCandidates(
      dueVocabulary:
          dueCards.map((card) => card.vocabulary).whereType<VocabularyModel>(),
      libraryVocabulary: libraryVocabulary,
    );

    final preferences = await SharedPreferences.getInstance();
    final scope = reviewService.currentUserId ?? 'guest';
    final lastVocabularyKey = '$_lastBatchVocabularyKey.$scope';
    final batchVocabulary = ReminderVocabularyRotation.selectBatch(
      candidates: candidates,
      previousBatchLastVocabularyId: preferences.getString(lastVocabularyKey),
      count: _reminderBatchLength,
    );

    await cancelDailyReminders();

    final now = tz.TZDateTime.now(tz.local);
    final firstScheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    final firstDayOffset =
        startTodayIfUpcoming && firstScheduledDate.isAfter(now) ? 0 : 1;
    for (var dayIndex = 0; dayIndex < _reminderBatchLength; dayIndex++) {
      final scheduledDate = tz.TZDateTime(
        tz.local,
        firstScheduledDate.year,
        firstScheduledDate.month,
        firstScheduledDate.day + dayIndex + firstDayOffset,
        hour,
        minute,
      );
      final targetVocab =
          batchVocabulary.isEmpty ? null : batchVocabulary[dayIndex];
      final title = targetVocab != null
          ? (currentStreak > 0
              ? '🔥 $currentStreak-Day Streak!'
              : '⭐ Daily Vocab')
          : (currentStreak > 0
              ? '🔥 Keep your $currentStreak-day streak alive!'
              : '📸 Time for your daily word!');
      final body = targetVocab != null
          ? '${targetVocab.word.toUpperCase()} (${targetVocab.thaiTranslation}) • "${targetVocab.englishSentence}"'
          : 'Snap a photo or review your cards to collect stars today.';
      final bigText = targetVocab != null
          ? '${targetVocab.word.toUpperCase()} (${targetVocab.thaiTranslation})\n\n"${targetVocab.englishSentence}"'
          : 'Take 2 minutes to scan a new photo or review your saved cards.';
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            bigText,
            contentTitle: title,
            summaryText: 'Starmory Daily Word',
          ),
          icon: '@drawable/ic_stat_notification',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: DesignTokens.brandColor,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _scheduleOneReminder(
        id: _dailyReminderNotificationId + dayIndex,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        details: details,
        payload: targetVocab != null ? 'starmory://review' : 'starmory://home',
      );
      debugPrint(
        '🔔 [NotificationService] Scheduled one-time reminder ${dayIndex + 1}/$_reminderBatchLength for $scheduledDate',
      );
    }

    if (batchVocabulary.isNotEmpty) {
      await preferences.setString(lastVocabularyKey, batchVocabulary.last.id);
    }
  }

  Future<void> _scheduleOneReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required String payload,
  }) async {
    for (final mode in [
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: payload,
        );
        return;
      } catch (e) {
        debugPrint(
          '⚠️ [NotificationService] Scheduling reminder $id with $mode failed: $e',
        );
      }
    }

    throw StateError('All scheduling modes failed for reminder $id.');
  }

  /// Instantly trigger a test notification (useful for instant verification)
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload = 'starmory://review',
  }) async {
    if (kIsWeb) return;
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Starmory Daily Word',
      ),
      icon: '@drawable/ic_stat_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: DesignTokens.brandColor,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Cancel all scheduled learning reminders in this batch and the legacy ID.
  Future<void> cancelDailyReminders() async {
    if (kIsWeb) return;
    for (var dayIndex = 0; dayIndex < _reminderBatchLength; dayIndex++) {
      await _notificationsPlugin.cancel(
        id: _dailyReminderNotificationId + dayIndex,
      );
    }
    debugPrint('🔔 [NotificationService] Cancelled pending reminder batch.');
  }

  /// Refresh the batch after the user completes a learning activity.
  Future<void> onActivityCompletedToday({
    required int hour,
    required int minute,
    required ReviewService reviewService,
    required int currentStreak,
  }) async {
    if (kIsWeb) return;
    debugPrint(
      '🔔 [NotificationService] Activity completed -> Refreshing reminder batch',
    );
    await scheduleDailyReminders(
      hour: hour,
      minute: minute,
      reviewService: reviewService,
      currentStreak: currentStreak,
      startTodayIfUpcoming: false,
    );
  }
}
