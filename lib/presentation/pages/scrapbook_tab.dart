import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../constants/design_tokens.dart';
import '../../data/models/scrapbook_model.dart';
import '../providers/scrapbook_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/galaxy_screen_background.dart';
import '../widgets/scrapbook_detail_sheet.dart';
import '../widgets/scrapbook_polaroid.dart';
import 'edit_scrapbook_screen.dart';

/// Calendar-led archive of the learner's saved memories.
class ScrapbookTab extends ConsumerStatefulWidget {
  const ScrapbookTab({super.key});

  @override
  ConsumerState<ScrapbookTab> createState() => _ScrapbookTabState();
}

class _ScrapbookTabState extends ConsumerState<ScrapbookTab> {
  final ScrollController _scrollController = ScrollController();
  static const _ink = Color(0xFF28252D);
  static const _softInk = Color(0xFF68636D);
  static const _divider = Color(0xFFE8E4EC);
  static const _calendarLavender = Color(0xFFD9CEFF);
  static const _calendarLavenderInk = Color(0xFF493579);
  static const _calendarMarker = Color(0xFFA991E8);

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime? _visuallySelectedDay;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for scroll to top signal from tab navigation
    ref.listen<int>(
      navigationProvider.select((s) => s.scrapbookScrollToTopTrigger),
      (previous, next) {
        if (previous != next) {
          _scrollToTop();
        }
      },
    );

    final scrapbookState = ref.watch(scrapbookStateProvider);

    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator(
            color: DesignTokens.brandColor,
            onRefresh: () =>
                ref.read(scrapbookStateProvider.notifier).refresh(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: _buildPageHeader(scrapbookState),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _buildCalendar(scrapbookState),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildSelectedDay(scrapbookState),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(ScrapbookState state) {
    final memoryLabel = state.totalCount == 1 ? 'memory' : 'memories';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scrapbook',
                style: GoogleFonts.lexend(
                  fontSize: 26,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                state.isLoading
                    ? 'Gathering your memories…'
                    : '${state.totalCount} $memoryLabel saved along the way',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  height: 1.4,
                  color: _softInk,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(ScrapbookState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x170E0917),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMonthHeader(),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _divider),
          const SizedBox(height: 8),
          TableCalendar<String>(
            firstDay: DateTime(2015, 1, 1),
            lastDay: DateTime(DateTime.now().year + 5, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_visuallySelectedDay ?? _selectedDay, day),
            eventLoader: (day) => state
                .getScrapbooksForDate(day)
                .map((scrapbook) => scrapbook.id)
                .toList(),
            headerVisible: false,
            availableGestures: AvailableGestures.horizontalSwipe,
            rowHeight: 44,
            daysOfWeekHeight: 34,
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.all(3),
              todayDecoration: BoxDecoration(
                color: const Color(0xFFF0ECFF),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: _calendarLavender,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: _calendarMarker,
                shape: BoxShape.circle,
              ),
              markerSize: 5,
              markersMaxCount: 1,
              markerMargin: const EdgeInsets.only(top: 3),
              defaultTextStyle: _dayTextStyle(_ink),
              weekendTextStyle: _dayTextStyle(_ink),
              outsideTextStyle: _dayTextStyle(const Color(0xFFAAA5AE)),
              todayTextStyle: _dayTextStyle(
                _calendarLavenderInk,
                FontWeight.w700,
              ),
              selectedTextStyle: _dayTextStyle(
                _calendarLavenderInk,
                FontWeight.w700,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: _weekDayTextStyle,
              weekendStyle: _weekDayTextStyle,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
                _visuallySelectedDay = selectedDay;
                _selectedDay = selectedDay;
              });

              // Show the detail sheet for the selected day
              final entries = state.getScrapbooksForDate(selectedDay);
              if (entries.isNotEmpty) {
                _showDayScrapbooks(entries, selectedDay);
              } else {
                // Show feedback for empty days
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No memories saved on this day'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                // Reset visual selection
                setState(() => _visuallySelectedDay = null);
              }
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    final isCurrentMonth = _focusedDay.year == DateTime.now().year &&
        _focusedDay.month == DateTime.now().month;

    return Row(
      children: [
        Expanded(
          child: Text(
            '${_monthName(_focusedDay.month)} ${_focusedDay.year}',
            style: GoogleFonts.lexend(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: _ink,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (!isCurrentMonth)
          TextButton(
            onPressed: _jumpToToday,
            style: TextButton.styleFrom(
              foregroundColor: DesignTokens.brandColor,
              minimumSize: const Size(52, DesignTokens.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Today'),
          ),
        _monthButton(
          tooltip: 'Previous month',
          icon: Icons.chevron_left_rounded,
          onPressed: () => _changeMonth(-1),
        ),
        _monthButton(
          tooltip: 'Next month',
          icon: Icons.chevron_right_rounded,
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _monthButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(
        width: DesignTokens.touchTarget,
        height: DesignTokens.touchTarget,
      ),
      icon: Icon(icon, size: 24),
      color: _ink,
    );
  }

  Widget _buildSelectedDay(ScrapbookState state) {
    if (state.isLoading && state.scrapbooks.isEmpty) {
      return const _MemorySkeleton();
    }

    if (state.error != null && state.scrapbooks.isEmpty) {
      return _ErrorState(
        onRetry: () => ref.read(scrapbookStateProvider.notifier).refresh(),
      );
    }

    final entries = state.getScrapbooksForDate(_selectedDay);
    final isToday = isSameDay(_selectedDay, DateTime.now());
    final title = isToday ? 'Today' : _longDate(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.lexend(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                      letterSpacing: -0.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entries.isEmpty
                        ? 'A fresh page waiting for a memory'
                        : '${entries.length} ${entries.length == 1 ? 'memory' : 'memories'} on this day',
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      height: 1.4,
                      color: _softInk,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 15),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: DesignTokens.durationMedium),
          switchInCurve: DesignTokens.curveEaseOutQuart,
          switchOutCurve: Curves.easeIn,
          child: entries.isEmpty
              ? _EmptyDay(key: ValueKey(_dateKey(_selectedDay)))
              : _MemoryStrip(
                  key: ValueKey(_dateKey(_selectedDay)),
                  entries: entries,
                  onEntryTap: (entry) => _openEditor(context, entry),
                ),
        ),
      ],
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + offset, 1);
    });
  }

  void _jumpToToday() {
    final today = DateTime.now();
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
      _visuallySelectedDay = null;
    });
  }

  void _showDayScrapbooks(List<ScrapbookModel> scrapbooks, [DateTime? selectedDay]) async {
    await showScrapbookDetailSheet(context, scrapbooks: scrapbooks);
    // Reset visual selection after sheet closes
    if (mounted && selectedDay != null) {
      setState(() => _visuallySelectedDay = null);
    }
  }

  void _openEditor(BuildContext context, ScrapbookModel entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditScrapbookScreen(
          scrapbookId: entry.id,
          imagePath: entry.imagePath,
          vocabularyWords: entry.vocabularyWords,
          englishSentence: entry.englishSentence,
          thaiSentence: entry.thaiSentence,
          selectedEmoji: entry.selectedEmoji,
          date: entry.date,
        ),
      ),
    );
  }

  TextStyle _dayTextStyle(Color color, [FontWeight weight = FontWeight.w500]) {
    return GoogleFonts.lexend(
      fontSize: 13,
      fontWeight: weight,
      color: color,
    );
  }

  TextStyle get _weekDayTextStyle => GoogleFonts.lexend(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _softInk,
      );

  String _monthName(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];

  String _longDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[date.weekday - 1]}, ${_monthName(date.month)} ${date.day}';
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  bool isSameDay(DateTime? first, DateTime? second) {
    if (first == null || second == null) return false;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _MemoryStrip extends StatelessWidget {
  const _MemoryStrip({
    super.key,
    required this.entries,
    required this.onEntryTap,
  });

  final List<ScrapbookModel> entries;
  final ValueChanged<ScrapbookModel> onEntryTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Transform.rotate(
            angle: index.isEven ? -0.015 : 0.015,
            child: ScrapbookPolaroid(
              width: 132,
              imagePath: entry.imagePath,
              backgroundColor: Color(entry.backgroundColor),
              vocabularyCount: entry.vocabularyWords.length,
              semanticLabel: 'Open memory ${index + 1}',
              onTap: () => onEntryTap(entry),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE8FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 21,
              color: DesignTokens.brandColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Memories you create from Home will appear here.',
              style: GoogleFonts.lexend(
                fontSize: 13,
                height: 1.45,
                color: const Color(0xFF56515B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemorySkeleton extends StatelessWidget {
  const _MemorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 112,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          width: double.infinity,
          height: 126,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF6B6670)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'We couldn’t load your scrapbook.',
              style: GoogleFonts.lexend(
                fontSize: 13,
                color: const Color(0xFF454049),
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
