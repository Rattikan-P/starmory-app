import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/scrapbook_provider.dart';
import '../../data/models/scrapbook_model.dart';
import '../widgets/galaxy_screen_background.dart';

/// Edit Scrapbook Screen
/// Allows users to customize their scrapbook before saving
class EditScrapbookScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final List<ScrapbookVocabularyWord> vocabularyWords;
  final String englishSentence;
  final String thaiSentence;
  final String selectedEmoji;
  final DateTime? date;
  final String? scrapbookId; // ID of existing scrapbook to edit (null = new)

  const EditScrapbookScreen({
    super.key,
    required this.imagePath,
    required this.vocabularyWords,
    required this.englishSentence,
    required this.thaiSentence,
    this.selectedEmoji = '😊',
    this.date,
    this.scrapbookId,
  });

  @override
  ConsumerState<EditScrapbookScreen> createState() => _EditScrapbookScreenState();
}

class _EditScrapbookScreenState extends ConsumerState<EditScrapbookScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  // Editable state
  late List<ScrapbookTextOverlay> _textOverlays;
  late List<ScrapbookSticker> _stickers;
  late List<ScrapbookPhoto> _additionalPhotos; // Store additional photos with positions
  late int _backgroundColor;
  late String _selectedEmoji;

  // UI state
  bool _isSaving = false;
  int _selectedToolbarIndex = -1; // -1 = none, 0 = text, 1 = sticker, 2 = photo, 3 = background

  // Dragging state
  String? _draggingId; // ID of item being dragged
  String? _draggingType; // 'text', 'sticker', or 'photo'
  Offset? _dragStartOffset;
  Offset? _itemStartOffset;
  bool _isOverDeleteZone = false; // Track if dragged item is over delete zone

  // Canvas size for positioning calculations
  Size? _canvasSize;

  // Available emojis for selection
  static const List<String> _availableEmojis = [
    '😊', '😍', '🥰', '😎', '🤩', '😇', '🥳', '😋', '🤗', '😌',
    '🌟', '⭐', '✨', '💫', '🌙', '☀️', '🌈', '🎨', '🎭', '🎪',
    '❤️', '💜', '💙', '💚', '💛', '🧡', '🤍', '🖤', '💕', '💞',
    '🎀', '🎈', '🎁', '🎉', '🎊', '🏆', '🥇', '🎯', '💎', '👑',
    '🍀', '🌸', '🌺', '🌻', '🌹', '🍄', '🌲', '🌳', '🍁', '🍂',
    '☕', '🍵', '🧸', '🎹', '🎸', '🎧', '📚', '✏️', '🖊️', '📷',
  ];

  // Background colors
  static const List<int> _backgroundColorOptions = [
    0xFFFFFFFF, // White
    0xFFFFF8E1, // Cream
    0xFFF3E5F5, // Light Purple
    0xFFE8F5E9, // Light Green
    0xFFFFEBEE, // Light Pink
    0xFFE3F2FD, // Light Blue
    0xFFFFF3E0, // Light Orange
    0xFFF5F5F5, // Light Gray
    0xFF263238, // Dark
    0xFF000000, // Black
  ];

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.selectedEmoji;
    _textOverlays = [];
    _stickers = [];
    _additionalPhotos = [];
    _backgroundColor = 0xFFFFFFFF;

    // Load existing scrapbook data if editing
    if (widget.scrapbookId != null) {
      _loadExistingScrapbook();
    }
  }

  void _loadExistingScrapbook() {
    final scrapbookState = ref.read(scrapbookStateProvider);
    final existingScrapbook = scrapbookState.scrapbooks
        .where((s) => s.id == widget.scrapbookId)
        .firstOrNull;

    if (existingScrapbook != null) {
      setState(() {
        _textOverlays = existingScrapbook.textOverlays;
        _stickers = existingScrapbook.stickers;
        _additionalPhotos = existingScrapbook.additionalPhotos;
        _backgroundColor = existingScrapbook.backgroundColor;
        _selectedEmoji = existingScrapbook.selectedEmoji;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GalaxyScreenBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Main Content
              Column(
                children: [
                  // Top Bar
                  _buildTopBar(),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Date
                          _buildDateHeader(),

                          // Main Canvas
                          _buildScrapbookCanvas(),

                          // Sentences
                          if (widget.englishSentence.isNotEmpty || widget.thaiSentence.isNotEmpty)
                            _buildSentences(),

                          // Vocabulary Words
                          _buildVocabularyWords(),

                          // Bottom padding for toolbar
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom Toolbar (Positioned at bottom)
              _buildBottomToolbar(),

              // Delete Zone (appears when dragging)
              if (_draggingId != null) _buildDeleteZone(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Color(0xFF1f2937),
                size: 18,
              ),
            ),
          ),

          const Spacer(),

          // Edit Title
          Text(
            'Edit',
            style: GoogleFonts.lexend(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1f2937),
            ),
          ),

          const Spacer(),

          // Save Button
          GestureDetector(
            onTap: _isSaving ? null : _saveScrapbook,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isSaving
                    ? Colors.grey.shade300
                    : const Color(0xFF8b5cf6),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8b5cf6).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final date = widget.date ?? DateTime.now();
    final weekday = _getWeekday(date.weekday);
    final month = _getMonth(date.month);
    final day = date.day;
    final year = date.year;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        '$weekday, $day $month $year',
        style: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6b7280),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildScrapbookCanvas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 400,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background canvas with rounded corners (for visual only)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(_backgroundColor),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Layout area for items (extends beyond canvas for touch events)
            // Oversized container to capture taps on items outside canvas
            Positioned(
              left: -100, // Allow items on left to be tappable
              right: -100, // Allow items on right to be tappable
              top: -100, // Allow items on top to be tappable
              bottom: -100, // Allow items on bottom to be tappable
              child: SizedBox(
                width: 600, // 400 canvas + 100 each side
                height: 600,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Update canvas size for positioning calculations (use original canvas size 400)
                    _canvasSize = const Size(400, 400);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Emoji overlay (stays inside canvas)
                        Positioned(
                          left: 116, // Offset to account for oversized container (600-400)/2 + 16
                          top: 116,
                          child: GestureDetector(
                            onTap: _showEmojiPicker,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _selectedEmoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Text Overlays (can extend outside canvas and be tappable)
                        ..._textOverlays.map((overlay) => _buildTextOverlay(overlay)),

                        // Stickers (can extend outside canvas and be tappable)
                        ..._stickers.map((sticker) => _buildSticker(sticker)),

                        // Additional Photos (can extend outside canvas and be tappable)
                        ..._additionalPhotos.map((photo) => _buildAdditionalPhoto(photo)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextOverlay(ScrapbookTextOverlay overlay) {
    if (_canvasSize == null) return const SizedBox.shrink();

    // Calculate actual position based on canvas size
    final left = overlay.x * _canvasSize!.width;
    final top = overlay.y * _canvasSize!.height;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => _editTextOverlay(overlay),
        onPanStart: (details) {
          setState(() {
            _draggingId = overlay.id;
            _draggingType = 'text';
            _dragStartOffset = details.localPosition;
            _itemStartOffset = Offset(left, top);
            _isOverDeleteZone = false;
          });
        },
        onPanUpdate: (details) {
          if (_draggingId != overlay.id || _draggingType != 'text') return;

          setState(() {
            final delta = details.localPosition - _dragStartOffset!;
            final newOffset = _itemStartOffset! + delta;

            // Check if over delete zone
            _isOverDeleteZone = _isPositionOverDeleteZone(details.globalPosition);

            // Only update position if NOT over delete zone
            if (!_isOverDeleteZone) {
              // Allow dragging outside canvas bounds (-0.3 to 1.3 = 30% overflow on each side)
              final clampedX = (newOffset.dx / _canvasSize!.width).clamp(-0.3, 1.3);
              final clampedY = (newOffset.dy / _canvasSize!.height).clamp(-0.3, 1.3);

              final index = _textOverlays.indexWhere((o) => o.id == overlay.id);
              if (index != -1) {
                _textOverlays[index] = overlay.copyWith(x: clampedX, y: clampedY);
              }
            }
          });
        },
        onPanEnd: (details) {
          if (_isOverDeleteZone) {
            // Delete the item
            setState(() {
              _textOverlays.removeWhere((o) => o.id == overlay.id);
              _draggingId = null;
              _draggingType = null;
              _dragStartOffset = null;
              _itemStartOffset = null;
              _isOverDeleteZone = false;
            });
          } else {
            // Just reset dragging state
            setState(() {
              _draggingId = null;
              _draggingType = null;
              _dragStartOffset = null;
              _itemStartOffset = null;
              _isOverDeleteZone = false;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
            border: _draggingId == overlay.id
                ? Border.all(
                    color: _isOverDeleteZone ? Colors.red : const Color(0xFF8b5cf6),
                    width: 2,
                  )
                : null,
          ),
          child: Text(
            overlay.text,
            style: TextStyle(
              color: Color(overlay.color),
              fontSize: overlay.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSticker(ScrapbookSticker sticker) {
    if (_canvasSize == null) return const SizedBox.shrink();

    // Calculate actual position based on canvas size
    final left = sticker.x * _canvasSize!.width;
    final top = sticker.y * _canvasSize!.height;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _draggingId = sticker.id;
            _draggingType = 'sticker';
            _dragStartOffset = details.localPosition;
            _itemStartOffset = Offset(left, top);
            _isOverDeleteZone = false;
          });
        },
        onPanUpdate: (details) {
          if (_draggingId != sticker.id || _draggingType != 'sticker') return;

          setState(() {
            final delta = details.localPosition - _dragStartOffset!;
            final newOffset = _itemStartOffset! + delta;

            // Check if over delete zone
            _isOverDeleteZone = _isPositionOverDeleteZone(details.globalPosition);

            // Only update position if NOT over delete zone
            if (!_isOverDeleteZone) {
              // Allow dragging outside canvas bounds (-0.3 to 1.3 = 30% overflow on each side)
              final clampedX = (newOffset.dx / _canvasSize!.width).clamp(-0.3, 1.3);
              final clampedY = (newOffset.dy / _canvasSize!.height).clamp(-0.3, 1.3);

              final index = _stickers.indexWhere((s) => s.id == sticker.id);
              if (index != -1) {
                _stickers[index] = sticker.copyWith(x: clampedX, y: clampedY);
              }
            }
          });
        },
        onPanEnd: (details) {
          if (_isOverDeleteZone) {
            // Delete the item
            setState(() {
              _stickers.removeWhere((s) => s.id == sticker.id);
              _draggingId = null;
              _draggingType = null;
              _dragStartOffset = null;
              _itemStartOffset = null;
              _isOverDeleteZone = false;
            });
          } else {
            // Just reset dragging state
            setState(() {
              _draggingId = null;
              _draggingType = null;
              _dragStartOffset = null;
              _itemStartOffset = null;
              _isOverDeleteZone = false;
            });
          }
        },
        child: Container(
          decoration: _draggingId == sticker.id
              ? BoxDecoration(
                  border: Border.all(
                    color: _isOverDeleteZone ? Colors.red : const Color(0xFF8b5cf6),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Text(
            sticker.emoji,
            style: TextStyle(
              fontSize: 40 * sticker.scale,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalPhoto(ScrapbookPhoto photo) {
    if (_canvasSize == null) return const SizedBox.shrink();

    // Calculate actual position and size based on canvas size
    final left = photo.x * _canvasSize!.width;
    final top = photo.y * _canvasSize!.height;
    final width = photo.width * _canvasSize!.width;
    final height = photo.height * _canvasSize!.height;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _draggingId = photo.id;
            _draggingType = 'photo';
            _dragStartOffset = details.localPosition;
            _itemStartOffset = Offset(left, top);
            _isOverDeleteZone = false;
          });
        },
        onPanUpdate: (details) {
          if (_draggingId != photo.id || _draggingType != 'photo') return;

          setState(() {
            final delta = details.localPosition - _dragStartOffset!;
            final newOffset = _itemStartOffset! + delta;

            // Check if over delete zone
            _isOverDeleteZone = _isPositionOverDeleteZone(details.globalPosition);

            // Only update position if NOT over delete zone
            if (!_isOverDeleteZone) {
              // Allow dragging outside canvas bounds (-0.3 to 1.3 = 30% overflow on each side)
              final clampedX = (newOffset.dx / _canvasSize!.width).clamp(-0.3, 1.3);
              final clampedY = (newOffset.dy / _canvasSize!.height).clamp(-0.3, 1.3);

              final index = _additionalPhotos.indexWhere((p) => p.id == photo.id);
              if (index != -1) {
                _additionalPhotos[index] = photo.copyWith(x: clampedX, y: clampedY);
              }
            }
          });
        },
        onPanEnd: (details) {
          if (_isOverDeleteZone) {
            // Delete the item
            setState(() {
              _additionalPhotos.removeWhere((p) => p.id == photo.id);
              _draggingId = null;
              _draggingType = null;
              _dragStartOffset = null;
              _itemStartOffset = null;
              _isOverDeleteZone = false;
            });
          } else {
            // Just reset dragging state
            setState(() {
              _draggingId = null;
              _draggingType = null;
              _dragStartOffset = null;
              _itemStartOffset = null;
              _isOverDeleteZone = false;
            });
          }
        },
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _draggingId == photo.id
                  ? (_isOverDeleteZone ? Colors.red : const Color(0xFF8b5cf6))
                  : Colors.white.withValues(alpha: 0.5),
              width: _draggingId == photo.id ? 3 : 2,
            ),
            boxShadow: _draggingId == photo.id
                ? [
                    BoxShadow(
                      color: (_isOverDeleteZone ? Colors.red : const Color(0xFF8b5cf6)).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(
            File(photo.imagePath),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildSentences() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.englishSentence.isNotEmpty) ...[
              Text(
                widget.englishSentence,
                style: GoogleFonts.lexend(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1f2937),
                  height: 1.4,
                ),
              ),
              if (widget.thaiSentence.isNotEmpty) const SizedBox(height: 8),
            ],
            if (widget.thaiSentence.isNotEmpty)
              Text(
                widget.thaiSentence,
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6b7280),
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabularyWords() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.vocabularyWords.map((vocab) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFDE68A), Color(0xFFFBCFE8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8b5cf6).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  vocab.word,
                  style: GoogleFonts.lexend(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1f2937),
                  ),
                ),
                Text(
                  vocab.thaiTranslation,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6b7280),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildToolbarItem(
                  icon: Icons.text_fields_rounded,
                  label: 'Text',
                  index: 0,
                  onTap: _addText,
                ),
                _buildToolbarItem(
                  icon: Icons.emoji_emotions_outlined,
                  label: 'Sticker',
                  index: 1,
                  onTap: _showStickerPicker,
                ),
                _buildToolbarItem(
                  icon: Icons.photo_library_rounded,
                  label: 'Photo',
                  index: 2,
                  onTap: _pickNewPhoto,
                ),
                _buildToolbarItem(
                  icon: Icons.format_color_fill_rounded,
                  label: 'Color',
                  index: 3,
                  onTap: _showBackgroundColorPicker,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarItem({
    required IconData icon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedToolbarIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedToolbarIndex = isSelected ? -1 : index;
        });
        if (!isSelected) onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8b5cf6).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8b5cf6)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF8b5cf6)
                  : const Color(0xFF6b7280),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF8b5cf6)
                    : const Color(0xFF6b7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteZone() {
    return Positioned(
      bottom: 80, // Above the toolbar
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _isOverDeleteZone
                ? Colors.red.withValues(alpha: 0.95)
                : Colors.red.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: _isOverDeleteZone ? 0.4 : 0.2),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isOverDeleteZone ? Icons.delete_forever : Icons.delete_outline,
                color: Colors.white,
                size: _isOverDeleteZone ? 28 : 24,
              ),
              const SizedBox(width: 12),
              Text(
                _isOverDeleteZone ? 'Release to delete' : 'Drag here to delete',
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============= Actions =============

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            childAspectRatio: 1,
          ),
          itemCount: _availableEmojis.length,
          itemBuilder: (context, index) {
            final emoji = _availableEmojis[index];
            return GestureDetector(
              onTap: () {
                setState(() => _selectedEmoji = emoji);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _selectedEmoji == emoji
                      ? const Color(0xFF8b5cf6).withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _addText() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Text',
          style: GoogleFonts.lexend(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1f2937),
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter text...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _textOverlays.add(ScrapbookTextOverlay(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    text: controller.text,
                    x: 0.1 + (_textOverlays.length * 0.1),
                    y: 0.2 + (_textOverlays.length * 0.1),
                  ));
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8b5cf6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editTextOverlay(ScrapbookTextOverlay overlay) {
    final controller = TextEditingController(text: overlay.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Text',
          style: GoogleFonts.lexend(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1f2937),
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter text...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _removeTextOverlay(overlay.id);
              });
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete',
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  final index = _textOverlays.indexWhere((o) => o.id == overlay.id);
                  if (index != -1) {
                    _textOverlays[index] = overlay.copyWith(text: controller.text);
                  }
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8b5cf6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            childAspectRatio: 1,
          ),
          itemCount: _availableEmojis.length,
          itemBuilder: (context, index) {
            final emoji = _availableEmojis[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _stickers.add(ScrapbookSticker(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    emoji: emoji,
                    x: 0.2 + (_stickers.length * 0.1),
                    y: 0.3 + (_stickers.length * 0.1),
                  ));
                });
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickNewPhoto() async {
    try {
      final photoStatus = await Permission.photos.request();
      if (!photoStatus.isGranted) {
        _showPermissionDialog('Photo Library');
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (image != null && mounted) {
        setState(() {
          // Add photo with a default position (staggered)
          _additionalPhotos.add(ScrapbookPhoto(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            imagePath: image.path,
            x: 0.05 + (_additionalPhotos.length * 0.05), // Stagger horizontally
            y: 0.60 + (_additionalPhotos.length * 0.05), // Start from bottom area
            width: 0.25, // 25% of canvas width
            height: 0.25, // 25% of canvas height
          ));
        });
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to pick image: ${e.toString()}');
    }
  }

  void _showBackgroundColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background Color',
              style: GoogleFonts.lexend(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1f2937),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1,
                ),
                itemCount: _backgroundColorOptions.length,
                itemBuilder: (context, index) {
                  final color = _backgroundColorOptions[index];
                  final isSelected = _backgroundColor == color;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _backgroundColor = color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Color(color),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8b5cf6)
                              : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeTextOverlay(String id) {
    setState(() {
      _textOverlays.removeWhere((overlay) => overlay.id == id);
    });
  }

  Future<void> _saveScrapbook() async {
    setState(() => _isSaving = true);

    try {
      // Get existing scrapbook data to preserve createdAt
      final existingScrapbook = widget.scrapbookId != null
          ? ref.read(scrapbookStateProvider).scrapbooks
              .where((s) => s.id == widget.scrapbookId)
              .firstOrNull
          : null;

      final scrapbook = ScrapbookModel(
        id: widget.scrapbookId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date: widget.date ?? DateTime.now(),
        imagePath: widget.imagePath,
        vocabularyWords: widget.vocabularyWords,
        englishSentence: widget.englishSentence,
        thaiSentence: widget.thaiSentence,
        selectedEmoji: _selectedEmoji,
        backgroundColor: _backgroundColor,
        textOverlays: _textOverlays,
        stickers: _stickers,
        additionalPhotos: _additionalPhotos,
        createdAt: existingScrapbook?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Use update if editing existing scrapbook, add if new
      if (widget.scrapbookId != null) {
        await ref.read(scrapbookStateProvider.notifier).updateScrapbook(scrapbook);
      } else {
        await ref.read(scrapbookStateProvider.notifier).addScrapbook(scrapbook);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.scrapbookId != null ? '✓ Scrapbook updated!' : '✓ Scrapbook saved!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to home
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✗ Failed to save: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ============= Helpers =============

  void _showPermissionDialog(String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '$type Permission Required',
          style: GoogleFonts.lexend(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1f2937),
          ),
        ),
        content: Text(
          'Please grant $type permission to continue.',
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6b7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8b5cf6),
            ),
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.lexend(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1f2937),
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6b7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8b5cf6),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Check if a position is over the delete zone (bottom of screen)
  bool _isPositionOverDeleteZone(Offset globalPosition) {
    final screenHeight = MediaQuery.of(context).size.height;
    final deleteZoneTop = screenHeight - 150; // Delete zone is in bottom 150px
    return globalPosition.dy > deleteZoneTop;
  }

  String _getWeekday(int day) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return weekdays[day - 1];
  }

  String _getMonth(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[month - 1];
  }
}
