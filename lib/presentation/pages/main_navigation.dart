import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_tab.dart';
import 'review_tab.dart';
import 'scrapbook_tab.dart';
import 'progress_tab.dart';
import '../providers/providers.dart';

// Sync only once per app session (from launch, not resume)
bool _hasSyncedThisSession = false;

/// Main Navigation Screen with Bottom Navigation Bar
/// 4 Tabs: Home, Review, Scrapbook, Progress
/// Profile accessible from Progress tab
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final List<Widget> _tabs = const [
    HomeTab(),
    ReviewTab(),
    ScrapbookTab(),
    ProgressTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Auto sync vocabularies when app opens (for registered users)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOnAppOpen();
    });
  }

  Future<void> _syncOnAppOpen() async {
    // Only sync once per app session (not on resume from background)
    if (_hasSyncedThisSession) {
      print('ℹ️ [App Open] Skipping sync (already synced this session)');
      return;
    }

    try {
      // Only sync for registered users (not guests)
      if (Supabase.instance.client.auth.currentSession == null) {
        print('ℹ️ [App Open] Skipping sync (not logged in)');
        return;
      }

      print('🔄 [App Open] Starting auto sync...');
      final hiveService = ref.read(hiveServiceProvider);
      final vocabSyncService = ref.read(vocabularySyncServiceProvider);

      final localVocabs = await hiveService.getAllVocabulary();

      print('📦 [App Open] Found ${localVocabs.length} local vocabularies');

      if (localVocabs.isNotEmpty) {
        // Use mergeWithCloud to avoid duplicates
        print('☁️ [App Open] Merging with cloud...');
        final syncedVocabs = await vocabSyncService.mergeWithCloud(localVocabs);
        // Update local storage with merged vocabularies
        await hiveService.clearAllVocabulary();
        for (final vocab in syncedVocabs) {
          await hiveService.saveVocabulary(vocab);
        }
        print('✅ [App Open] Sync complete! Total vocabularies: ${syncedVocabs.length}');
      } else {
        print('ℹ️ [App Open] No local vocabularies to sync');
      }

      // Mark as synced for this session
      _hasSyncedThisSession = true;
    } catch (e) {
      print('❌ [App Open] Sync failed: $e');
      // Sync failed - continue with app (local vocabularies still available)
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainNavigationIndexProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            ref.read(mainNavigationIndexProvider.notifier).state = index;
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF6C63FF),
          unselectedItemColor: const Color(0xFF9E9E9E),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.refresh_outlined),
              activeIcon: Icon(Icons.refresh_rounded),
              label: 'Review',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_library_outlined),
              activeIcon: Icon(Icons.photo_library_rounded),
              label: 'Scrapbook',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Progress',
            ),
          ],
        ),
      ),
    );
  }
}
