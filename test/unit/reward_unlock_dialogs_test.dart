import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmory_app/data/models/user_model.dart';
import 'package:starmory_app/data/models/vocabulary_model.dart';
import 'package:starmory_app/data/services/vocabulary_sync_service.dart';
import 'package:starmory_app/data/sticker_sets.dart';
import 'package:starmory_app/presentation/providers/providers.dart';
import 'package:starmory_app/presentation/utils/reward_unlock_helper.dart';
import 'package:starmory_app/presentation/widgets/badge_unlock_dialog.dart';
import 'package:starmory_app/presentation/widgets/sticker_pack_unlock_dialog.dart';
import '../test_helpers.mocks.dart';
import '../test_setup.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });
  group('BadgeUnlockDialog Widget Tests', () {
    testWidgets('shows badge unlock dialog with asset icon, renders elements and closes on button tap', (tester) async {
      bool viewBadgesCalled = false;
      final testBadge = Badge(
        id: 'first_word',
        name: 'First Star',
        titleTh: 'ดาวดวงแรก',
        icon: 'assets/images/badges/first_word.png',
        description: 'Learned your first word',
        descriptionTh: 'เรียนรู้คำศัพท์คำแรกของคุณ',
        isLocked: false,
        requiredStars: 1,
        category: 'Stars',
        tier: 'Bronze',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  BadgeUnlockDialog.show(
                    context,
                    badge: testBadge,
                    onViewBadges: () {
                      viewBadgesCalled = true;
                    },
                  );
                },
                child: const Text('Open Badge Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Badge Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify dialog is visible
      expect(find.byType(BadgeUnlockDialog), findsOneWidget);
      expect(find.text('BADGE UNLOCKED!'), findsOneWidget);
      expect(find.text('First Star'), findsOneWidget);
      expect(find.text('BRONZE'), findsOneWidget);
      expect(find.text('Learned your first word'), findsOneWidget);
      expect(find.text('Awesome!'), findsOneWidget);

      // Tap Awesome button
      await tester.tap(find.text('Awesome!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be dismissed and callback executed
      expect(find.byType(BadgeUnlockDialog), findsNothing);
      expect(viewBadgesCalled, isTrue);
    });

    testWidgets('shows badge unlock dialog with emoji icon and closes on X tap', (tester) async {
      final emojiBadge = Badge(
        id: 'night_owl',
        name: 'Night Owl',
        titleTh: 'นกฮูกราตรี',
        icon: '🦉',
        description: 'Active learning late at night (22:00 - 04:00) 30 times',
        descriptionTh: 'เรียนรู้คำศัพท์หรือทบทวนรอบดึก',
        isLocked: false,
        requiredStars: 30,
        category: 'Special',
        tier: 'Silver',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  BadgeUnlockDialog.show(
                    context,
                    badge: emojiBadge,
                  );
                },
                child: const Text('Open Emoji Badge Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Emoji Badge Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BadgeUnlockDialog), findsOneWidget);
      expect(find.text('Night Owl'), findsOneWidget);
      expect(find.text('🦉'), findsOneWidget);
      expect(find.text('SILVER'), findsOneWidget);

      // Tap close button (X)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BadgeUnlockDialog), findsNothing);
    });
  });

  group('StickerPackUnlockDialog Widget Tests', () {
    testWidgets('shows sticker pack unlock dialog, renders elements and closes on button tap', (tester) async {
      bool useInScrapbookCalled = false;
      final spacePack = stickerSets.firstWhere((p) => p.id == 'space');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  StickerPackUnlockDialog.show(
                    context,
                    stickerSet: spacePack,
                    onUseInScrapbook: () {
                      useInScrapbookCalled = true;
                    },
                  );
                },
                child: const Text('Open Sticker Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sticker Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify dialog is visible
      expect(find.byType(StickerPackUnlockDialog), findsOneWidget);
      expect(find.text('STICKER PACK UNLOCKED!'), findsOneWidget);
      expect(find.text('Space Pack'), findsOneWidget);
      expect(find.text('16 STICKERS READY'), findsOneWidget);
      expect(find.text(spacePack.description), findsOneWidget);
      expect(find.text('Awesome!'), findsOneWidget);

      // Tap Awesome button
      await tester.tap(find.text('Awesome!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be dismissed and callback executed
      expect(find.byType(StickerPackUnlockDialog), findsNothing);
      expect(useInScrapbookCalled, isTrue);
    });

    testWidgets('closes sticker pack unlock dialog on X tap', (tester) async {
      final flowerPack = stickerSets.firstWhere((p) => p.id == 'flower');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  StickerPackUnlockDialog.show(
                    context,
                    stickerSet: flowerPack,
                  );
                },
                child: const Text('Open Flower Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Flower Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(StickerPackUnlockDialog), findsOneWidget);
      expect(find.text('Flower Pack'), findsOneWidget);

      // Tap close button (X)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(StickerPackUnlockDialog), findsNothing);
    });
  });

  group('End-to-End Unlock Flow Tests', () {
    testWidgets('checkAndUnlockBadges triggers popup when user reaches milestone', (tester) async {
      final mockHive = MockHiveService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hiveServiceProvider.overrideWithValue(mockHive),
            userStateProvider.overrideWith(
              (ref) => UserNotifier(
                mockHive,
                initialState: UserState(user: UserModel.createGuest()),
                autoLoad: false,
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      ref.read(badgeStateProvider.notifier).checkAndUnlockBadges(
                            1, // 1 star => unlocks First Star (first_word)
                            0,
                            context: context,
                          );
                    },
                    child: const Text('Unlock Badge Trigger'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Unlock Badge Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify popup automatically appears!
      expect(find.byType(BadgeUnlockDialog), findsOneWidget);
      expect(find.text('First Star'), findsOneWidget);
      expect(find.text('BADGE UNLOCKED!'), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.text('Awesome!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BadgeUnlockDialog), findsNothing);
    });

    testWidgets('checkAndUnlockPacks triggers popup when user reaches streak milestone', (tester) async {
      final mockHive = MockHiveService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hiveServiceProvider.overrideWithValue(mockHive),
            userStateProvider.overrideWith(
              (ref) => UserNotifier(
                mockHive,
                initialState: UserState(user: UserModel.createGuest()),
                autoLoad: false,
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      ref.read(stickerStateProvider.notifier).checkAndUnlockPacks(
                            totalStars: 0,
                            streakDays: 7, // 7 days => unlocks Space Pack
                            natureVocabCount: 0,
                            context: context,
                          );
                    },
                    child: const Text('Unlock Sticker Trigger'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Unlock Sticker Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify sticker popup automatically appears!
      expect(find.byType(StickerPackUnlockDialog), findsOneWidget);
      expect(find.text('Space Pack'), findsOneWidget);
      expect(find.text('STICKER PACK UNLOCKED!'), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.text('Awesome!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StickerPackUnlockDialog), findsNothing);
    });

    testWidgets('RewardUnlockHelper.checkAndShowUnlocks triggers badge popup', (tester) async {
      final mockHive = MockHiveService();
      final mockReview = MockReviewService();
      final mockSync = VocabularySyncService();
      final guest = UserModel.createGuest();

      final testVocab = VocabularyModel(
        id: 'v1',
        word: 'Rose',
        partOfSpeech: 'noun',
        thaiTranslation: 'ดอกกุหลาบ',
        englishSentence: 'A red rose.',
        thaiSentence: 'ดอกกุหลาบสีแดง',
        cefrLevel: 'A1',
        communicativeFunction: 'statement',
        languageVariant: 'US',
        imageUrl: 'assets/images/placeholder.png',
        topic: 'nature',
        createdAt: DateTime(2026, 9, 29),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hiveServiceProvider.overrideWithValue(mockHive),
            reviewServiceProvider.overrideWithValue(mockReview),
            userStateProvider.overrideWith(
              (ref) => UserNotifier(
                mockHive,
                initialState: UserState(user: guest),
                autoLoad: false,
              ),
            ),
            vocabularyStateProvider.overrideWith(
              (ref) => VocabularyNotifier(
                mockHive,
                mockSync,
                mockReview,
                initialState: VocabularyState(
                  isLoading: false,
                  vocabularies: [testVocab],
                ),
                autoLoad: false,
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      RewardUnlockHelper.checkAndShowUnlocks(
                        context,
                        ref,
                      );
                    },
                    child: const Text('Check Rewards Trigger'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check Rewards Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1 word in vocabulary => First Star badge popup should be shown
      expect(find.byType(BadgeUnlockDialog), findsOneWidget);
      expect(find.text('First Star'), findsOneWidget);

      // Dismiss badge popup
      await tester.tap(find.text('Awesome!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // After dismissal, no more popups (since 1 word does not unlock any sticker pack)
      expect(find.byType(BadgeUnlockDialog), findsNothing);
      expect(find.byType(StickerPackUnlockDialog), findsNothing);
    });

    testWidgets('RewardUnlockHelper.checkAndShowUnlocks triggers both badge and sticker sequentially', (tester) async {
      final mockHive = MockHiveService();
      final mockReview = MockReviewService();
      final mockSync = VocabularySyncService();
      // Guest already has First Star (first_word) and First Spark (streak_3) to isolate 7-day streak
      final guest = UserModel.createGuest().copyWith(
        currentStreak: 7,
        badges: ['first_word', 'streak_3'],
        preferences: {
          'celebrated_badges': ['first_word', 'streak_3'],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hiveServiceProvider.overrideWithValue(mockHive),
            reviewServiceProvider.overrideWithValue(mockReview),
            userStateProvider.overrideWith(
              (ref) => UserNotifier(
                mockHive,
                initialState: UserState(user: guest),
                autoLoad: false,
              ),
            ),
            vocabularyStateProvider.overrideWith(
              (ref) => VocabularyNotifier(
                mockHive,
                mockSync,
                mockReview,
                initialState: const VocabularyState(
                  isLoading: false,
                  vocabularies: [],
                ),
                autoLoad: false,
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      RewardUnlockHelper.checkAndShowUnlocks(
                        context,
                        ref,
                      );
                    },
                    child: const Text('Check Sequential Rewards'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check Sequential Rewards'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Badge popup shows first (Week Warrior / streak_7)
      expect(find.byType(BadgeUnlockDialog), findsOneWidget);
      expect(find.text('Week Warrior'), findsOneWidget);
      expect(find.byType(StickerPackUnlockDialog), findsNothing);

      // Dismiss badge popup
      await tester.tap(find.text('Awesome!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 2. Sticker Pack popup shows next (Space Pack / space)
      expect(find.byType(BadgeUnlockDialog), findsNothing);
      expect(find.byType(StickerPackUnlockDialog), findsOneWidget);
      expect(find.text('Space Pack'), findsOneWidget);

      // Dismiss sticker popup
      await tester.tap(find.text('Awesome!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 3. All popups dismissed
      expect(find.byType(BadgeUnlockDialog), findsNothing);
      expect(find.byType(StickerPackUnlockDialog), findsNothing);
    });

    testWidgets('RewardUnlockHelper.checkAndShowUnlocks triggers popup for uncelebrated badge even if already in user.badges', (tester) async {
      final mockHive = MockHiveService();
      final mockReview = MockReviewService();
      final mockSync = VocabularySyncService();

      // User has first_word in user.badges (e.g. from background sync or trigger),
      // but has NOT celebrated it yet (not in celebrated_badges)
      final user = UserModel.createGuest().copyWith(
        badges: ['first_word'],
        preferences: {}, // Empty celebrated_badges
      );

      final testVocab = VocabularyModel(
        id: 'v1',
        word: 'Rose',
        partOfSpeech: 'noun',
        thaiTranslation: 'ดอกกุหลาบ',
        englishSentence: 'A red rose.',
        thaiSentence: 'ดอกกุหลาบสีแดง',
        cefrLevel: 'A1',
        communicativeFunction: 'statement',
        languageVariant: 'US',
        imageUrl: 'assets/images/placeholder.png',
        topic: 'nature',
        createdAt: DateTime(2026, 9, 29),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hiveServiceProvider.overrideWithValue(mockHive),
            reviewServiceProvider.overrideWithValue(mockReview),
            userStateProvider.overrideWith(
              (ref) => UserNotifier(
                mockHive,
                initialState: UserState(user: user),
                autoLoad: false,
              ),
            ),
            vocabularyStateProvider.overrideWith(
              (ref) => VocabularyNotifier(
                mockHive,
                mockSync,
                mockReview,
                initialState: VocabularyState(
                  isLoading: false,
                  vocabularies: [testVocab],
                ),
                autoLoad: false,
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      RewardUnlockHelper.checkAndShowUnlocks(
                        context,
                        ref,
                      );
                    },
                    child: const Text('Check Uncelebrated Rewards'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check Uncelebrated Rewards'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // First Star badge popup should still appear even though first_word was already in user.badges!
      expect(find.byType(BadgeUnlockDialog), findsOneWidget);
      expect(find.text('First Star'), findsOneWidget);

      // Dismiss popup
      await tester.tap(find.text('Awesome!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BadgeUnlockDialog), findsNothing);
    });
  });
}

