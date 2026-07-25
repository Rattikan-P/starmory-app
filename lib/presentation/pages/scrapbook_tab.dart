import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/scrapbook_provider.dart';
import '../../data/models/scrapbook_model.dart';
import '../widgets/galaxy_screen_background.dart';
import 'edit_scrapbook_screen.dart';
import 'dart:io';

/// Bottom Sheet showing scrapbook entries for a selected day
class DayScrapbookBottomSheet extends StatelessWidget {
  final DateTime day;
  final List<ScrapbookModel> scrapbooks;

  const DayScrapbookBottomSheet({
    super.key,
    required this.day,
    required this.scrapbooks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8b5cf6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: GoogleFonts.lexend(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8b5cf6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getMonthName(day.month)} ${day.year}',
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1f2937),
                        ),
                      ),
                      Text(
                        '${scrapbooks.length} ${scrapbooks.length == 1 ? 'memory' : 'memories'}',
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          color: const Color(0xFF6b7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF6b7280)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Scrapbooks list
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              itemCount: scrapbooks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildScrapbookCard(context, scrapbooks[index]);
              },
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScrapbookCard(BuildContext context, ScrapbookModel scrapbook) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _viewScrapbook(context, scrapbook);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE2D1F9).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: scrapbook.imagePath.startsWith('http')
                    ? Image.network(
                        scrapbook.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          );
                        },
                      )
                    : Image.file(
                        File(scrapbook.imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                          );
                        },
                      ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji and English sentence
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scrapbook.selectedEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          scrapbook.englishSentence.isNotEmpty
                              ? scrapbook.englishSentence
                              : 'No sentence',
                          style: GoogleFonts.lexend(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1f2937),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (scrapbook.thaiSentence.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 36),
                      child: Text(
                        scrapbook.thaiSentence,
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          color: const Color(0xFF6b7280),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  // Vocabulary words
                  if (scrapbook.vocabularyWords.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: scrapbook.vocabularyWords.map((word) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8b5cf6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: word.word,
                                  style: GoogleFonts.lexend(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF8b5cf6),
                                  ),
                                ),
                                const TextSpan(
                                  text: ' - ',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF6b7280)),
                                ),
                                TextSpan(
                                  text: word.thaiTranslation,
                                  style: GoogleFonts.lexend(
                                    fontSize: 13,
                                    color: const Color(0xFF6b7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewScrapbook(BuildContext context, ScrapbookModel scrapbook) {
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
}

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
      child: TableCalendar(
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
          _showDayScrapbooksBottomSheet(selectedDay, scrapbookState);
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
    );
  }

  void _showDayScrapbooksBottomSheet(DateTime day, ScrapbookState scrapbookState) {
    final scrapbooks = scrapbookState.getScrapbooksForDate(day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return DayScrapbookBottomSheet(
              day: day,
              scrapbooks: scrapbooks,
            );
          },
        );
      },
    );
  }

  bool isSameDay(DateTime? day1, DateTime? day2) {
    if (day1 == null || day2 == null) return false;
    return day1.year == day2.year &&
        day1.month == day2.month &&
        day1.day == day2.day;
  }
}
