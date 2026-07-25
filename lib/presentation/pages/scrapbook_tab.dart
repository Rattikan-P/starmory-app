import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/scrapbook_provider.dart';
import '../../data/models/scrapbook_model.dart';
import '../widgets/galaxy_screen_background.dart';
import 'edit_scrapbook_screen.dart';
import 'dart:io';

/// Scrapbook Tab - Shows calendar with scrapbook entries
class ScrapbookTab extends ConsumerStatefulWidget {
  const ScrapbookTab({super.key});

  @override
  ConsumerState<ScrapbookTab> createState() => _ScrapbookTabState();
}

class _ScrapbookTabState extends ConsumerState<ScrapbookTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final scrapbookState = ref.watch(scrapbookStateProvider);

    return GalaxyScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'SCRAPBOOK',
                      style: GoogleFonts.lexend(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1f2937),
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Calendar
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCalendar(scrapbookState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(ScrapbookState scrapbookState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Calendar Grid (with built-in header)
          TableCalendar(
            firstDay: DateTime.now().weekday == DateTime.monday
                ? DateTime.now()
                : DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: (day) {
              final scrapbooks = scrapbookState.getScrapbooksForDate(day);
              return scrapbooks.map((s) => s.id).toList();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: const Color(0xFF8b5cf6).withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFF8b5cf6),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Color(0xFF8b5cf6),
                shape: BoxShape.circle,
              ),
              todayTextStyle: GoogleFonts.lexend(
                color: const Color(0xFF1f2937),
                fontWeight: FontWeight.w600,
              ),
              defaultTextStyle: GoogleFonts.lexend(
                color: const Color(0xFF1f2937),
              ),
              selectedTextStyle: GoogleFonts.lexend(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              weekendTextStyle: GoogleFonts.lexend(
                color: const Color(0xFF8b5cf6),
              ),
              outsideTextStyle: GoogleFonts.lexend(
                color: const Color(0xFF9ca3af),
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: GoogleFonts.lexend(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1f2937),
              ),
              leftChevronIcon: const Icon(
                Icons.chevron_left,
                color: Color(0xFF8b5cf6),
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: Color(0xFF8b5cf6),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9ca3af),
              ),
              weekendStyle: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8b5cf6),
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _showDayScrapbooks(selectedDay, scrapbookState);
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
          ),

          // Scrapbooks for selected day
          if (_selectedDay != null)
            _buildDayScrapbooks(_selectedDay!, scrapbookState),
        ],
      ),
    );
  }

  Widget _buildDayScrapbooks(DateTime day, ScrapbookState scrapbookState) {
    final scrapbooks = scrapbookState.getScrapbooksForDate(day);

    if (scrapbooks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Memories from ${_getMonthName(day.month)} ${day.day}',
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6b7280),
          ),
        ),
        const SizedBox(height: 12),
        ...scrapbooks.map((scrapbook) => _buildScrapbookCard(scrapbook)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildScrapbookCard(ScrapbookModel scrapbook) {
    return GestureDetector(
      onTap: () => _viewScrapbook(scrapbook),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE2D1F9).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Image thumbnail
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              clipBehavior: Clip.antiAlias,
              child: scrapbook.imagePath.startsWith('http')
                  ? Image.network(
                      scrapbook.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    )
                  : Image.file(
                      File(scrapbook.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image),
                        );
                      },
                    ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji and word count
                    Row(
                      children: [
                        Text(
                          scrapbook.selectedEmoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${scrapbook.vocabularyWords.length} words',
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              color: const Color(0xFF6b7280),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Sentence preview
                    Flexible(
                      child: Text(
                        scrapbook.englishSentence.isNotEmpty
                            ? scrapbook.englishSentence
                            : 'No sentence',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          color: const Color(0xFF1f2937),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDayScrapbooks(DateTime day, ScrapbookState scrapbookState) {
    final scrapbooks = scrapbookState.getScrapbooksForDate(day);

    if (scrapbooks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No memories for this day yet'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _viewScrapbook(ScrapbookModel scrapbook) {
    // Navigate to edit screen to view (could create a separate view-only screen later)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditScrapbookScreen(
          scrapbookId: scrapbook.id,
          imagePath: scrapbook.imagePath,
          vocabularyWords: scrapbook.vocabularyWords,
          englishSentence: scrapbook.englishSentence,
          thaiSentence: scrapbook.thaiSentence,
          selectedEmoji: scrapbook.selectedEmoji,
          date: scrapbook.date,
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  bool isSameDay(DateTime? day1, DateTime? day2) {
    if (day1 == null || day2 == null) return false;
    return day1.year == day2.year &&
        day1.month == day2.month &&
        day1.day == day2.day;
  }
}
