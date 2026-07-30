import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/scrapbook_provider.dart';
import '../../data/models/scrapbook_model.dart';
import '../../constants/design_tokens.dart';
import '../widgets/galaxy_screen_background.dart';
import '../../data/sticker_sets.dart';

/// Helper class for background color options
class _BackgroundColorOption {
  final int color;
  final String name;

  const _BackgroundColorOption({
    required this.color,
    required this.name,
  });
}

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
  ConsumerState<EditScrapbookScreen> createState() =>
      _EditScrapbookScreenState();
}

class _EditScrapbookScreenState extends ConsumerState<EditScrapbookScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  // Editable state
  late List<ScrapbookTextOverlay> _textOverlays;
  late List<ScrapbookSticker> _stickers;
  late List<ScrapbookPhoto>
      _additionalPhotos; // Store additional photos with positions
  late int _backgroundColor;
  late String _selectedEmoji;

  // Original state for comparison
  late List<ScrapbookTextOverlay> _originalTextOverlays;
  late List<ScrapbookSticker> _originalStickers;
  late List<ScrapbookPhoto> _originalAdditionalPhotos;
  late int _originalBackgroundColor;
  late String _originalSelectedEmoji;

  // UI state
  bool _isSaving = false;
  int _selectedToolbarIndex =
      -1; // -1 = none, 0 = text, 1 = sticker, 2 = photo, 3 = background
  String? _selectedStickerSetId; // For sticker picker

  // Dragging state
  String? _draggingId; // ID of item being dragged
  String? _draggingType; // 'text', 'sticker', or 'photo'
  Offset? _dragStartOffset;
  Offset? _itemStartOffset;

  // Selection state (for showing resize/rotate controls)
  String? _selectedId; // ID of selected item
  String? _selectedType; // 'text', 'sticker', or 'photo'
  Offset? _lastTapPosition; // Last tap position for control handle detection

  // Resize/rotate state
  String? _resizingId; // ID of item being resized/rotated
  String? _resizingType; // 'text', 'sticker', or 'photo'
  Offset? _resizeStartPos; // Initial pointer position for resize
  double? _initialScale; // Initial scale for resize operation
  double? _initialRotation; // Initial rotation for resize operation
  double? _initialAngle; // Initial angle for rotation calculation

  // Pinch gesture state
  double? _initialPinchScale;
  double? _initialItemScaleForPinch;
  double? _initialItemRotationForPinch;

  // Canvas size for positioning calculations
  Size? _canvasSize;

  // Available emojis for selection
  static const List<String> _availableEmojis = [
    '😊',
    '😍',
    '🥰',
    '😎',
    '🤩',
    '😇',
    '🥳',
    '😋',
    '🤗',
    '😌',
    '🌟',
    '⭐',
    '✨',
    '💫',
    '🌙',
    '☀️',
    '🌈',
    '🎨',
    '🎭',
    '🎪',
    '❤️',
    '💜',
    '💙',
    '💚',
    '💛',
    '🧡',
    '🤍',
    '🖤',
    '💕',
    '💞',
    '🎀',
    '🎈',
    '🎁',
    '🎉',
    '🎊',
    '🏆',
    '🥇',
    '🎯',
    '💎',
    '👑',
    '🍀',
    '🌸',
    '🌺',
    '🌻',
    '🌹',
    '🍄',
    '🌲',
    '🌳',
    '🍁',
    '🍂',
    '☕',
    '🍵',
    '🧸',
    '🎹',
    '🎸',
    '🎧',
    '📚',
    '✏️',
    '🖊️',
    '📷',
  ];

  // Background colors with semantic naming
  static const List<_BackgroundColorOption> _backgroundColorOptions = [
    _BackgroundColorOption(color: 0xFFFFFFFF, name: 'White'),
    _BackgroundColorOption(color: 0xFFFFF8E1, name: 'Cream'),
    _BackgroundColorOption(color: 0xFFF3E5F5, name: 'Lavender'),
    _BackgroundColorOption(color: 0xFFE8F5E9, name: 'Mint'),
    _BackgroundColorOption(color: 0xFFFFEBEE, name: 'Blush'),
    _BackgroundColorOption(color: 0xFFE3F2FD, name: 'Sky'),
    _BackgroundColorOption(color: 0xFFFFF3E0, name: 'Peach'),
    _BackgroundColorOption(color: 0xFFF5F5F5, name: 'Gray'),
    _BackgroundColorOption(color: 0xFF263238, name: 'Charcoal'),
    _BackgroundColorOption(color: 0xFF000000, name: 'Black'),
  ];

  // Touch sandbox extension (pixels beyond canvas edge for touch targets)
  static const double _touchSandbox = 100.0;

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.selectedEmoji;
    _textOverlays = [];
    _stickers = [];
    _additionalPhotos = [];
    _backgroundColor = 0xFFFFFFFF;

    // Store original state for comparison
    _originalTextOverlays = [];
    _originalStickers = [];
    _originalAdditionalPhotos = [];
    _originalBackgroundColor = 0xFFFFFFFF;
    _originalSelectedEmoji = widget.selectedEmoji;

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
        // Create deep copies to avoid modifying the original scrapbook data
        _textOverlays = existingScrapbook.textOverlays
            .map((overlay) => ScrapbookTextOverlay(
                  id: overlay.id,
                  text: overlay.text,
                  x: overlay.x,
                  y: overlay.y,
                  color: overlay.color,
                  fontSize: overlay.fontSize,
                  scale: overlay.scale,
                  rotation: overlay.rotation,
                  flip: overlay.flip,
                ))
            .toList();
        _stickers = existingScrapbook.stickers
            .map((sticker) => ScrapbookSticker(
                  id: sticker.id,
                  emoji: sticker.emoji,
                  x: sticker.x,
                  y: sticker.y,
                  scale: sticker.scale,
                  rotation: sticker.rotation,
                  flip: sticker.flip,
                ))
            .toList();
        _additionalPhotos = existingScrapbook.additionalPhotos
            .map((photo) => ScrapbookPhoto(
                  id: photo.id,
                  imagePath: photo.imagePath,
                  x: photo.x,
                  y: photo.y,
                  width: photo.width,
                  height: photo.height,
                  rotation: photo.rotation,
                  flip: photo.flip,
                ))
            .toList();
        _backgroundColor = existingScrapbook.backgroundColor;
        _selectedEmoji = existingScrapbook.selectedEmoji;

        // Create separate deep copies for original state comparison
        _originalTextOverlays = _textOverlays
            .map((overlay) => ScrapbookTextOverlay(
                  id: overlay.id,
                  text: overlay.text,
                  x: overlay.x,
                  y: overlay.y,
                  color: overlay.color,
                  fontSize: overlay.fontSize,
                  scale: overlay.scale,
                  rotation: overlay.rotation,
                  flip: overlay.flip,
                ))
            .toList();
        _originalStickers = _stickers
            .map((sticker) => ScrapbookSticker(
                  id: sticker.id,
                  emoji: sticker.emoji,
                  x: sticker.x,
                  y: sticker.y,
                  scale: sticker.scale,
                  rotation: sticker.rotation,
                  flip: sticker.flip,
                ))
            .toList();
        _originalAdditionalPhotos = _additionalPhotos
            .map((photo) => ScrapbookPhoto(
                  id: photo.id,
                  imagePath: photo.imagePath,
                  x: photo.x,
                  y: photo.y,
                  width: photo.width,
                  height: photo.height,
                  rotation: photo.rotation,
                  flip: photo.flip,
                ))
            .toList();
        _originalBackgroundColor = existingScrapbook.backgroundColor;
        _originalSelectedEmoji = existingScrapbook.selectedEmoji;
      });
    }
  }

  /// Check if there are unsaved changes
  bool get _hasUnsavedChanges {
    if (_selectedEmoji != _originalSelectedEmoji) return true;
    if (_backgroundColor != _originalBackgroundColor) return true;
    if (_textOverlays.length != _originalTextOverlays.length) return true;
    if (_stickers.length != _originalStickers.length) return true;
    if (_additionalPhotos.length != _originalAdditionalPhotos.length)
      return true;

    // Check for position/content changes in text overlays
    for (int i = 0; i < _textOverlays.length; i++) {
      if (_textOverlays[i].x != _originalTextOverlays[i].x ||
          _textOverlays[i].y != _originalTextOverlays[i].y ||
          _textOverlays[i].text != _originalTextOverlays[i].text ||
          _textOverlays[i].scale != _originalTextOverlays[i].scale ||
          _textOverlays[i].rotation != _originalTextOverlays[i].rotation ||
          _textOverlays[i].flip != _originalTextOverlays[i].flip) {
        return true;
      }
    }

    // Check for position/scale/rotation/flip changes in stickers
    for (int i = 0; i < _stickers.length; i++) {
      if (_stickers[i].x != _originalStickers[i].x ||
          _stickers[i].y != _originalStickers[i].y ||
          _stickers[i].scale != _originalStickers[i].scale ||
          _stickers[i].rotation != _originalStickers[i].rotation ||
          _stickers[i].flip != _originalStickers[i].flip ||
          _stickers[i].emoji != _originalStickers[i].emoji) {
        return true;
      }
    }

    // Check for position/size/rotation/flip changes in additional photos
    for (int i = 0; i < _additionalPhotos.length; i++) {
      if (_additionalPhotos[i].x != _originalAdditionalPhotos[i].x ||
          _additionalPhotos[i].y != _originalAdditionalPhotos[i].y ||
          _additionalPhotos[i].width != _originalAdditionalPhotos[i].width ||
          _additionalPhotos[i].height != _originalAdditionalPhotos[i].height ||
          _additionalPhotos[i].rotation != _originalAdditionalPhotos[i].rotation ||
          _additionalPhotos[i].flip != _originalAdditionalPhotos[i].flip) {
        return true;
      }
    }

    return false;
  }

  /// Show confirmation dialog when leaving with unsaved changes
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFFA000),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Unsaved Changes',
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.fontSizeTitle,
                  fontWeight: DesignTokens.weightSemiBold,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'You have unsaved changes. Are you sure you want to leave without saving?',
          style: GoogleFonts.lexend(
            fontSize: DesignTokens.fontSizeBody,
            fontWeight: DesignTokens.weightRegular,
            color: DesignTokens.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Editing',
              style: GoogleFonts.lexend(
                color: DesignTokens.textSecondary,
                fontWeight: DesignTokens.weightSemiBold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              ),
            ),
            child: Text(
              'Discard',
              style: GoogleFonts.lexend(
                fontWeight: DesignTokens.weightSemiBold,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
                            if (widget.englishSentence.isNotEmpty ||
                                widget.thaiSentence.isNotEmpty)
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingLarge,
        DesignTokens.spacingMedium,
        DesignTokens.spacingLarge,
        DesignTokens.spacingSmall,
      ),
      child: Row(
        children: [
          // Back Button
          _TopBarButton(
            icon: Icons.arrow_back_ios_rounded,
            onTap: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),

          const Spacer(),

          // Edit Title
          Text(
            'Edit',
            style: GoogleFonts.lexend(
              fontSize: DesignTokens.fontSizeHeading,
              fontWeight: DesignTokens.weightSemiBold,
              color: DesignTokens.textPrimary,
            ),
          ),

          const Spacer(),

          // Save Button
          _SaveButton(
            isSaving: _isSaving,
            onTap: _isSaving ? null : _saveScrapbook,
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
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingLarge,
        vertical: DesignTokens.spacingMedium,
      ),
      child: Text(
        '$weekday, $day $month $year',
        style: GoogleFonts.lexend(
          fontSize: DesignTokens.fontSizeSubtitle,
          fontWeight: DesignTokens.weightSemiBold,
          color: DesignTokens.textSecondary,
          letterSpacing: DesignTokens.letterSpacingHeading,
        ),
      ),
    );
  }

  Widget _buildScrapbookCanvas() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingLarge,
      ),
      child: SizedBox(
        height: DesignTokens.scrapbookCanvasHeight,
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
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusCircular),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: DesignTokens.brandColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusCircular),
                  child: _buildPolaroidFrame(),
                ),
              ),
            ),

            // Layout area for items (extends beyond canvas for touch events)
            _buildTouchSandbox(),
          ],
        ),
      ),
    );
  }

  /// Build Polaroid-style frame with white border and bottom writing area
  Widget _buildPolaroidFrame() {
    return Container(
      color: Color(_backgroundColor),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasWidth = constraints.maxWidth;

            // Polaroid aspect ratio (standard Polaroid is roughly 3.5" x 4.2")
            // We want the frame to be centered and smaller
            final polaroidWidth = canvasWidth * 0.65; // 65% of canvas width
            final polaroidHeight = polaroidWidth * 1.2; // Polaroid aspect ratio

            // Polaroid frame dimensions
            final frameBorder = 12.0; // White border around photo
            final bottomArea =
                polaroidHeight * 0.18; // Writing area (18% of height)

            return Container(
              width: polaroidWidth,
              height: polaroidHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Photo area
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(frameBorder),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(1),
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom writing area (empty for now)
                  SizedBox(
                    height: bottomArea,
                    width: double.infinity,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build touch sandbox - oversized area for drag interactions
  Widget _buildTouchSandbox() {
    const touchSandbox = _touchSandbox;
    const canvasSize = DesignTokens.scrapbookCanvasHeight;

    return Positioned(
      left: -touchSandbox,
      right: -touchSandbox,
      top: -touchSandbox,
      bottom: -touchSandbox,
      child: GestureDetector(
        onTap: () {
          // Deselect when tapping outside elements
          if (_selectedId != null) {
            setState(() {
              _selectedId = null;
              _selectedType = null;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: canvasSize + (touchSandbox * 2),
          height: canvasSize + (touchSandbox * 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Update canvas size for positioning calculations
              _canvasSize = const Size(canvasSize, canvasSize);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Emoji overlay (centered in canvas)
                  _buildEmojiSelector(),

                  // Draggable items
                  ..._textOverlays.map((overlay) => _buildTextOverlay(overlay)),
                  ..._stickers.map((sticker) => _buildSticker(sticker)),
                  ..._additionalPhotos
                      .map((photo) => _buildAdditionalPhoto(photo)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build emoji selector button
  Widget _buildEmojiSelector() {
    const touchSandbox = _touchSandbox;
    // Position emoji button in top-left area of canvas (accounting for sandbox offset)
    const emojiOffset = touchSandbox + DesignTokens.spacingLarge;

    return Positioned(
      left: emojiOffset,
      top: emojiOffset,
      child: GestureDetector(
        onTap: _showEmojiPicker,
        child: Container(
          width: DesignTokens.emojiButtonSize,
          height: DesignTokens.emojiButtonSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DesignTokens.whiteWithOpacity(DesignTokens.opacityMostlyOpaque),
                DesignTokens.whiteWithOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radiusCircular),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: DesignTokens.brandColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              _selectedEmoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextOverlay(ScrapbookTextOverlay overlay) {
    if (_canvasSize == null) return const SizedBox.shrink();

    // Calculate actual position based on canvas size
    // Add touchSandbox offset to position relative to canvas, not touch sandbox
    final left = _touchSandbox + (overlay.x * _canvasSize!.width);
    final top = _touchSandbox + (overlay.y * _canvasSize!.height);

    // Offset to center the item (text overlays are ~60-80px wide)
    final centerOffsetX = 50.0;
    final centerOffsetY = 25.0;

    // Base font size with scale applied
    final scaledFontSize = overlay.fontSize * overlay.scale;

    final isSelected = _selectedId == overlay.id;

    return Positioned(
      left: left - centerOffsetX,
      top: top - centerOffsetY,
      child: GestureDetector(
        onTapDown: (details) {
          // Store tap position for control handle detection
          _lastTapPosition = details.localPosition;
        },
        onTap: () {
          // If selected and tap is on control handle, don't toggle selection
          if (isSelected && _lastTapPosition != null && _isOnControlHandle(_lastTapPosition!, Size(100, 50))) {
            _lastTapPosition = null;
            return;
          }
          _lastTapPosition = null;
          // Toggle selection
          setState(() {
            if (_selectedId == overlay.id) {
              _selectedId = null;
              _selectedType = null;
            } else {
              _selectedId = overlay.id;
              _selectedType = 'text';
            }
          });
        },
        onScaleStart: (details) {
          if (details.pointerCount == 1) {
            // Single finger - check if tapping on resize handle
            if (isSelected && _isOnResizeHandle(details.localFocalPoint, Size(100, 50))) {
              setState(() {
                _resizingId = overlay.id;
                _resizingType = 'text';
                _resizeStartPos = details.localFocalPoint;
                _initialScale = overlay.scale;
                _initialRotation = overlay.rotation;
                _initialAngle = _calculateAngle(details.localFocalPoint, Offset(left, top));
              });
            } else {
              // Start dragging
              setState(() {
                _draggingId = overlay.id;
                _draggingType = 'text';
                _selectedId = overlay.id;
                _selectedType = 'text';
                _dragStartOffset = details.localFocalPoint;
                _itemStartOffset = Offset(overlay.x, overlay.y);
              });
            }
          } else if (details.pointerCount > 1) {
            // Two-finger gesture started
            setState(() {
              _selectedId = overlay.id;
              _selectedType = 'text';
              _initialPinchScale = details.localFocalPoint.distance;
              _initialItemScaleForPinch = overlay.scale;
              _initialItemRotationForPinch = overlay.rotation;
            });
          }
        },
        onScaleUpdate: (details) {
          if (_resizingId == overlay.id && _resizingType == 'text') {
            // Handle resize/rotate from corner handle
            _handleResizeRotateUpdate(
              details.localFocalPoint,
              overlay.id,
              'text',
            );
          } else if (details.pointerCount == 1 && _draggingId == overlay.id) {
            // Single finger drag
            setState(() {
              final delta = details.localFocalPoint - _dragStartOffset!;

              // Update position
              // Convert delta to normalized coordinates and add to initial position
              final newX =
                  _itemStartOffset!.dx + (delta.dx / _canvasSize!.width);
              final newY =
                  _itemStartOffset!.dy + (delta.dy / _canvasSize!.height);

              // Clamp to allow some overflow outside canvas (-0.3 to 1.3)
              final clampedX = newX.clamp(-0.3, 1.3);
              final clampedY = newY.clamp(-0.3, 1.3);

              final index = _textOverlays.indexWhere((o) => o.id == overlay.id);
              if (index != -1) {
                _textOverlays[index] =
                    overlay.copyWith(x: clampedX, y: clampedY);
              }
            });
          } else if (details.pointerCount > 1 && _selectedId == overlay.id) {
            // Two-finger gesture in progress - handle pinch and rotate
            setState(() {
              // Calculate new scale based on pinch distance
              final currentDistance = details.localFocalPoint.distance;
              final scaleFactor = _initialPinchScale != null && _initialPinchScale! > 0
                  ? currentDistance / _initialPinchScale!
                  : 1.0;
              final newScale = (_initialItemScaleForPinch! * scaleFactor).clamp(0.5, 3.0);

              // Calculate new rotation based on rotation gesture
              final newRotation = _initialItemRotationForPinch! + details.rotation;

              final index = _textOverlays.indexWhere((o) => o.id == overlay.id);
              if (index != -1) {
                _textOverlays[index] = _textOverlays[index].copyWith(
                  scale: newScale,
                  rotation: newRotation,
                );
              }
            });
          }
        },
        onScaleEnd: (details) {
          if (_resizingId == overlay.id) {
            setState(() {
              _resizingId = null;
              _resizingType = null;
              _resizeStartPos = null;
              _initialScale = null;
              _initialRotation = null;
              _initialAngle = null;
            });
          } else {
            // Just reset dragging state
            setState(() {
              _draggingId = null;
              _draggingType = null;
              _dragStartOffset = null;
              _itemStartOffset = null;
              _initialPinchScale = null;
              _initialItemScaleForPinch = null;
              _initialItemRotationForPinch = null;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Transform.rotate(
          angle: overlay.rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Selection border and content
              Container(
                decoration: BoxDecoration(
                  border: _draggingId == overlay.id
                      ? Border.all(
                          color: DesignTokens.brandColor,
                          width: 2.5,
                        )
                      : Border.all(
                          color: isSelected
                              ? DesignTokens.brandColor
                              : Colors.transparent,
                          width: isSelected ? 2 : 0,
                        ),
                ),
                padding: const EdgeInsets.all(8.0),
                child: Transform.scale(
                  scaleX: overlay.flip ? -overlay.scale : overlay.scale,
                  scaleY: overlay.scale,
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      overlay.text,
                      style: TextStyle(
                        color: Color(overlay.color),
                        fontSize: scaledFontSize,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              // Control handles (show when selected)
              if (isSelected) ..._buildControlHandles(overlay.id, 'text', overlay.flip),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSticker(ScrapbookSticker sticker) {
    if (_canvasSize == null) return const SizedBox.shrink();

    // Calculate actual position based on canvas size
    // Add touchSandbox offset to position relative to canvas, not touch sandbox
    final left = _touchSandbox + (sticker.x * _canvasSize!.width);
    final top = _touchSandbox + (sticker.y * _canvasSize!.height);

    // Offset to center the item (PNG stickers are ~100x100 px)
    final centerOffsetX = 50.0;
    final centerOffsetY = 50.0;

    // Calculate size based on scale
    final stickerSize = 100.0 * sticker.scale;

    final isSelected = _selectedId == sticker.id;

    return Positioned(
      left: left - centerOffsetX,
      top: top - centerOffsetY,
      child: GestureDetector(
        onTapDown: (details) {
          // Store tap position for control handle detection
          _lastTapPosition = details.localPosition;
        },
        onTap: () {
          // If selected and tap is on control handle, don't toggle selection
          if (isSelected && _lastTapPosition != null && _isOnControlHandle(_lastTapPosition!, Size(stickerSize, stickerSize))) {
            _lastTapPosition = null;
            return;
          }
          _lastTapPosition = null;
          // Toggle selection
          setState(() {
            if (_selectedId == sticker.id) {
              _selectedId = null;
              _selectedType = null;
            } else {
              _selectedId = sticker.id;
              _selectedType = 'sticker';
            }
          });
        },
        onScaleStart: (details) {
          if (details.pointerCount == 1) {
            // Single finger - check if tapping on resize handle
            if (isSelected && _isOnResizeHandle(details.localFocalPoint, Size(stickerSize, stickerSize))) {
              setState(() {
                _resizingId = sticker.id;
                _resizingType = 'sticker';
                _resizeStartPos = details.localFocalPoint;
                _initialScale = sticker.scale;
                _initialRotation = sticker.rotation;
                _initialAngle = _calculateAngle(details.localFocalPoint, Offset(left, top));
              });
            } else {
              // Start dragging
              setState(() {
                _draggingId = sticker.id;
                _draggingType = 'sticker';
                _selectedId = sticker.id;
                _selectedType = 'sticker';
                _dragStartOffset = details.localFocalPoint;
                _itemStartOffset = Offset(sticker.x, sticker.y);
              });
            }
          } else if (details.pointerCount > 1) {
            // Two-finger gesture started
            setState(() {
              _selectedId = sticker.id;
              _selectedType = 'sticker';
              _initialPinchScale = details.localFocalPoint.distance;
              _initialItemScaleForPinch = sticker.scale;
              _initialItemRotationForPinch = sticker.rotation;
            });
          }
        },
        onScaleUpdate: (details) {
          if (_resizingId == sticker.id && _resizingType == 'sticker') {
            // Handle resize/rotate from corner handle
            _handleResizeRotateUpdate(
              details.localFocalPoint,
              sticker.id,
              'sticker',
            );
          } else if (details.pointerCount == 1 && _draggingId == sticker.id) {
            // Single finger drag
            setState(() {
              final delta = details.localFocalPoint - _dragStartOffset!;

              // Update position
              // Convert delta to normalized coordinates and add to initial position
              final newX =
                  _itemStartOffset!.dx + (delta.dx / _canvasSize!.width);
              final newY =
                  _itemStartOffset!.dy + (delta.dy / _canvasSize!.height);

              // Clamp to allow some overflow outside canvas (-0.3 to 1.3)
              final clampedX = newX.clamp(-0.3, 1.3);
              final clampedY = newY.clamp(-0.3, 1.3);

              final index = _stickers.indexWhere((s) => s.id == sticker.id);
              if (index != -1) {
                _stickers[index] = sticker.copyWith(x: clampedX, y: clampedY);
              }
            });
          } else if (details.pointerCount > 1 && _selectedId == sticker.id) {
            // Two-finger gesture in progress - handle pinch and rotate
            setState(() {
              // Calculate new scale based on pinch distance
              final currentDistance = details.localFocalPoint.distance;
              final scaleFactor = _initialPinchScale != null && _initialPinchScale! > 0
                  ? currentDistance / _initialPinchScale!
                  : 1.0;
              final newScale = (_initialItemScaleForPinch! * scaleFactor).clamp(0.5, 3.0);

              // Calculate new rotation based on rotation gesture
              final newRotation = _initialItemRotationForPinch! + details.rotation;

              final index = _stickers.indexWhere((s) => s.id == sticker.id);
              if (index != -1) {
                _stickers[index] = _stickers[index].copyWith(
                  scale: newScale,
                  rotation: newRotation,
                );
              }
            });
          }
        },
        onScaleEnd: (details) {
          if (_resizingId == sticker.id) {
            setState(() {
              _resizingId = null;
              _resizingType = null;
              _resizeStartPos = null;
              _initialScale = null;
              _initialRotation = null;
              _initialAngle = null;
            });
          } else {
            // Just reset dragging state
            setState(() {
              _draggingId = null;
              _draggingType = null;
              _dragStartOffset = null;
              _itemStartOffset = null;
              _initialPinchScale = null;
              _initialItemScaleForPinch = null;
              _initialItemRotationForPinch = null;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Transform.rotate(
          angle: sticker.rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Selection border and content
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _draggingId == sticker.id
                        ? DesignTokens.brandColor
                        : (isSelected
                            ? DesignTokens.brandColor
                            : Colors.transparent),
                    width: (_draggingId == sticker.id || isSelected) ? 2.5 : 0,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8.0),
                child: Transform.scale(
                  scaleX: sticker.flip ? -sticker.scale : sticker.scale,
                  scaleY: sticker.scale,
                  alignment: Alignment.center,
                  child: Image.asset(
                    sticker.emoji,
                    width: 100,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) {
                      return Text(sticker.emoji, style: const TextStyle(fontSize: 40));
                    },
                  ),
                ),
              ),
              // Control handles (show when selected)
              if (isSelected) ..._buildControlHandles(sticker.id, 'sticker', sticker.flip),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalPhoto(ScrapbookPhoto photo) {
    if (_canvasSize == null) return const SizedBox.shrink();

    // Calculate actual position and size based on canvas size
    // Add touchSandbox offset to position relative to canvas, not touch sandbox
    final left = _touchSandbox + (photo.x * _canvasSize!.width);
    final top = _touchSandbox + (photo.y * _canvasSize!.height);
    final width = photo.width * _canvasSize!.width;
    final height = photo.height * _canvasSize!.height;

    // Offset to center the item (photos have known width/height)
    final centerOffsetX = width / 2;
    final centerOffsetY = height / 2;

    final isSelected = _selectedId == photo.id;

    return Positioned(
      left: left - centerOffsetX,
      top: top - centerOffsetY,
      child: GestureDetector(
        onTapDown: (details) {
          // Store tap position for control handle detection
          _lastTapPosition = details.localPosition;
        },
        onTap: () {
          // If selected and tap is on control handle, don't toggle selection
          if (isSelected && _lastTapPosition != null && _isOnControlHandle(_lastTapPosition!, Size(width, height))) {
            _lastTapPosition = null;
            return;
          }
          _lastTapPosition = null;
          // Toggle selection
          setState(() {
            if (_selectedId == photo.id) {
              _selectedId = null;
              _selectedType = null;
            } else {
              _selectedId = photo.id;
              _selectedType = 'photo';
            }
          });
        },
        onScaleStart: (details) {
          if (details.pointerCount == 1) {
            // Single finger - check if tapping on resize handle
            if (isSelected && _isOnResizeHandle(details.localFocalPoint, Size(width, height))) {
              setState(() {
                _resizingId = photo.id;
                _resizingType = 'photo';
                _resizeStartPos = details.localFocalPoint;
                _initialScale = 1.0; // Store 1.0 as base for photo size calculation
                _initialRotation = photo.rotation;
                _initialAngle = _calculateAngle(details.localFocalPoint, Offset(left, top));
              });
            } else {
              // Start dragging
              setState(() {
                _draggingId = photo.id;
                _draggingType = 'photo';
                _selectedId = photo.id;
                _selectedType = 'photo';
                _dragStartOffset = details.localFocalPoint;
                _itemStartOffset = Offset(photo.x, photo.y);
              });
            }
          } else if (details.pointerCount > 1) {
            // Two-finger gesture started
            setState(() {
              _selectedId = photo.id;
              _selectedType = 'photo';
              _initialPinchScale = details.localFocalPoint.distance;
              // For photos, store initial width/height
              _initialItemScaleForPinch = photo.width; // Use width as scale reference
              _initialItemRotationForPinch = photo.rotation;
            });
          }
        },
        onScaleUpdate: (details) {
          if (_resizingId == photo.id && _resizingType == 'photo') {
            // Handle resize/rotate from corner handle
            _handleResizeRotateUpdate(
              details.localFocalPoint,
              photo.id,
              'photo',
            );
          } else if (details.pointerCount == 1 && _draggingId == photo.id) {
            // Single finger drag
            setState(() {
              final delta = details.localFocalPoint - _dragStartOffset!;

              // Update position
              // Convert delta to normalized coordinates and add to initial position
              final newX =
                  _itemStartOffset!.dx + (delta.dx / _canvasSize!.width);
              final newY =
                  _itemStartOffset!.dy + (delta.dy / _canvasSize!.height);

              // Clamp to allow some overflow outside canvas (-0.3 to 1.3)
              final clampedX = newX.clamp(-0.3, 1.3);
              final clampedY = newY.clamp(-0.3, 1.3);

              final index =
                  _additionalPhotos.indexWhere((p) => p.id == photo.id);
              if (index != -1) {
                _additionalPhotos[index] =
                    photo.copyWith(x: clampedX, y: clampedY);
              }
            });
          } else if (details.pointerCount > 1 && _selectedId == photo.id) {
            // Two-finger gesture in progress - handle pinch and rotate
            setState(() {
              // Calculate new size based on pinch distance
              final currentDistance = details.localFocalPoint.distance;
              final scaleFactor = _initialPinchScale != null && _initialPinchScale! > 0
                  ? currentDistance / _initialPinchScale!
                  : 1.0;

              // Calculate new rotation based on rotation gesture
              final newRotation = _initialItemRotationForPinch! + details.rotation;

              final index = _additionalPhotos.indexWhere((p) => p.id == photo.id);
              if (index != -1) {
                // Maintain aspect ratio when scaling
                final originalWidth = _initialItemScaleForPinch!;
                final newWidth = (originalWidth * scaleFactor).clamp(0.1, 0.8);
                final originalHeight = _additionalPhotos[index].height;
                final heightRatio = originalHeight / originalWidth;
                final newHeight = newWidth * heightRatio;

                _additionalPhotos[index] = _additionalPhotos[index].copyWith(
                  width: newWidth,
                  height: newHeight,
                  rotation: newRotation,
                );
              }
            });
          }
        },
        onScaleEnd: (details) {
          if (_resizingId == photo.id) {
            setState(() {
              _resizingId = null;
              _resizingType = null;
              _resizeStartPos = null;
              _initialScale = null;
              _initialRotation = null;
              _initialAngle = null;
            });
          } else {
            // Just reset dragging state
            setState(() {
              _draggingId = null;
              _draggingType = null;
              _dragStartOffset = null;
              _itemStartOffset = null;
              _initialPinchScale = null;
              _initialItemScaleForPinch = null;
              _initialItemRotationForPinch = null;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Transform.rotate(
          angle: photo.rotation,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Photo without decoration (original form)
              Transform.scale(
                scaleX: photo.flip ? -1.0 : 1.0,
                scaleY: 1.0,
                alignment: Alignment.center,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Image.file(
                    File(photo.imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Control handles (show when selected) - positioned at corners
              if (isSelected) ..._buildControlHandles(photo.id, 'photo', photo.flip),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentences() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingLarge,
        vertical: DesignTokens.spacingMedium,
      ),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: DesignTokens.brandColor.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: DesignTokens.brandColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.englishSentence.isNotEmpty) ...[
              Text(
                widget.englishSentence,
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.fontSizeBodyLarge,
                  fontWeight: DesignTokens.weightSemiBold,
                  color: DesignTokens.textPrimary,
                  height: 1.4,
                  letterSpacing: -0.2,
                ),
              ),
              if (widget.thaiSentence.isNotEmpty)
                const SizedBox(height: DesignTokens.spacingSmall),
            ],
            if (widget.thaiSentence.isNotEmpty)
              Text(
                widget.thaiSentence,
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.fontSizeBody,
                  fontWeight: DesignTokens.weightMedium,
                  color: DesignTokens.textSecondary,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabularyWords() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacingLarge),
      child: Wrap(
        spacing: DesignTokens.spacingSmall,
        runSpacing: DesignTokens.spacingSmall,
        children: widget.vocabularyWords.map((vocab) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacingLarge,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  DesignTokens.brandColor.withValues(alpha: 0.08),
                  DesignTokens.brandAccent.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
              border: Border.all(
                color: DesignTokens.brandColor.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: DesignTokens.brandColor.withValues(alpha: 0.1),
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
                    fontSize: DesignTokens.fontSizeSubtitle,
                    fontWeight: DesignTokens.weightBold,
                    color: DesignTokens.brandColor,
                  ),
                ),
                Text(
                  vocab.thaiTranslation,
                  style: GoogleFonts.lexend(
                    fontSize: DesignTokens.fontSizeSmall,
                    fontWeight: DesignTokens.weightMedium,
                    color: DesignTokens.textSecondary,
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
          color:
              DesignTokens.whiteWithOpacity(DesignTokens.opacityMostlyOpaque),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusCircular),
          ),
          boxShadow: [
            BoxShadow(
              color: DesignTokens.blackWithOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacingXLarge,
              vertical: DesignTokens.spacingLarge,
            ),
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
        // Don't toggle selection - just highlight briefly then reset
        setState(() {
          _selectedToolbarIndex = index;
        });
        onTap();
        HapticFeedback.lightImpact();
        // Reset after action completes
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _selectedToolbarIndex = -1;
            });
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: DesignTokens.durationMedium,
        ),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingMedium,
          vertical: DesignTokens.spacingSmall,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DesignTokens.brandColor.withValues(alpha: 0.15),
                    DesignTokens.brandAccent.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: !isSelected ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          border: Border.all(
            color: isSelected ? DesignTokens.brandColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: DesignTokens.brandColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? DesignTokens.brandColor
                  : DesignTokens.textSecondary,
              size: 22,
            ),
            const SizedBox(width: DesignTokens.spacingBase),
            Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.fontSizeCaption,
                fontWeight: DesignTokens.weightSemiBold,
                color: isSelected
                    ? DesignTokens.brandColor
                    : DesignTokens.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
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
          color: DesignTokens.surfacePrimary,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusCircular),
          ),
        ),
        child: GridView.builder(
          padding: const EdgeInsets.all(DesignTokens.spacingLarge),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            childAspectRatio: 1,
          ),
          itemCount: _availableEmojis.length,
          itemBuilder: (context, index) {
            final emoji = _availableEmojis[index];
            final isSelected = _selectedEmoji == emoji;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedEmoji = emoji);
                Navigator.pop(context);
                // Add haptic feedback
                HapticFeedback.lightImpact();
              },
              child: Container(
                margin: const EdgeInsets.all(DesignTokens.spacingBase),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DesignTokens.brandWithOpacity(
                          DesignTokens.opacityVerySubtle,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusMedium,
                  ),
                  border: isSelected
                      ? Border.all(
                          color: DesignTokens.brandColor,
                          width: 2,
                        )
                      : null,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
        ),
        title: Text(
          'Add Text',
          style: GoogleFonts.lexend(
            fontSize: DesignTokens.fontSizeTitle,
            fontWeight: DesignTokens.weightSemiBold,
            color: DesignTokens.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter text...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lexend(
                color: DesignTokens.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  // Position text at center of canvas
                  // x and y are normalized coordinates (0.0 to 1.0)
                  _textOverlays.add(ScrapbookTextOverlay(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    text: controller.text,
                    x: 0.5, // Center horizontally
                    y: 0.5, // Center vertically
                  ));
                });
                HapticFeedback.lightImpact();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.brandColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showStickerPicker() {
    // Initialize with first set if not set
    if (_selectedStickerSetId == null) {
      _selectedStickerSetId = stickerSets.first.id;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Use parent state instead
          String? selectedSetId = _selectedStickerSetId;

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: DesignTokens.surfacePrimary,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(DesignTokens.radiusCircular),
              ),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(DesignTokens.spacingLarge),
                  child: Row(
                    children: [
                      Text(
                        'Stickers',
                        style: GoogleFonts.lexend(
                          fontSize: DesignTokens.fontSizeTitle,
                          fontWeight: DesignTokens.weightSemiBold,
                          color: DesignTokens.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Set selector tabs
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacingLarge,
                    ),
                    itemCount: stickerSets.length,
                    itemBuilder: (context, index) {
                      final set = stickerSets[index];
                      final isSelected = selectedSetId == set.id;

                      return Padding(
                        padding: const EdgeInsets.only(
                          right: DesignTokens.spacingMedium,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedStickerSetId = set.id;
                            });
                            setModalState(() {
                              selectedSetId = set.id;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: DesignTokens.spacingLarge,
                              vertical: DesignTokens.spacingSmall,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        DesignTokens.brandColor,
                                        DesignTokens.brandAccent,
                                      ],
                                    )
                                  : null,
                              color: !isSelected ? Colors.grey.shade100 : null,
                              borderRadius: BorderRadius.circular(
                                DesignTokens.radiusXLarge,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? DesignTokens.brandColor
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (set.isLocked) ...[
                                  const Icon(
                                    Icons.lock,
                                    size: 16,
                                    color: DesignTokens.textSecondary,
                                  ),
                                  const SizedBox(
                                      width: DesignTokens.spacingSmall),
                                ],
                                Text(
                                  set.name,
                                  style: GoogleFonts.lexend(
                                    fontSize: DesignTokens.fontSizeBody,
                                    fontWeight: DesignTokens.weightSemiBold,
                                    color: isSelected
                                        ? Colors.white
                                        : DesignTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 1),

                // Stickers grid
                Expanded(
                  child: selectedSetId == null
                      // Empty state - select a set first
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.collections_outlined,
                                size: 64,
                                color: DesignTokens.textSecondary
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(
                                  height: DesignTokens.spacingMedium),
                              Text(
                                'Select a sticker set',
                                style: GoogleFonts.lexend(
                                  fontSize: DesignTokens.fontSizeBody,
                                  color: DesignTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildStickerGrid(
                          stickerSets.firstWhere(
                            (s) => s.id == selectedSetId,
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStickerGrid(StickerSet set) {
    if (set.isLocked) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: DesignTokens.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: DesignTokens.spacingMedium),
            Text(
              'Locked',
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.fontSizeTitle,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.textSecondary,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingSmall),
            Text(
              'Collect for ${set.requiredStreakDays} days to unlock',
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.fontSizeBody,
                color: DesignTokens.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(DesignTokens.spacingLarge),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
        mainAxisSpacing: DesignTokens.spacingMedium,
        crossAxisSpacing: DesignTokens.spacingMedium,
      ),
      itemCount: set.count,
      itemBuilder: (context, index) {
        final assetPath = getStickerAsset(set.id, index);

        return GestureDetector(
          onTap: () {
            setState(() {
              _stickers.add(ScrapbookSticker(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                emoji: assetPath, // Store asset path instead of emoji
                x: 0.5,
                y: 0.5,
              ));
            });
            Navigator.pop(context);
            HapticFeedback.lightImpact();
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: 32,
                      color: DesignTokens.textSecondary.withValues(alpha: 0.3),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
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
          // Position photo at center of canvas
          // x and y are normalized coordinates (0.0 to 1.0)
          _additionalPhotos.add(ScrapbookPhoto(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            imagePath: image.path,
            x: 0.5, // Center horizontally
            y: 0.5, // Center vertically
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
          color: DesignTokens.surfacePrimary,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusCircular),
          ),
        ),
        padding: const EdgeInsets.all(DesignTokens.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background Color',
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.fontSizeTitle,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingMedium),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1,
                ),
                itemCount: _backgroundColorOptions.length,
                itemBuilder: (context, index) {
                  final option = _backgroundColorOptions[index];
                  final isSelected = _backgroundColor == option.color;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _backgroundColor = option.color);
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                    child: Semantics(
                      label: 'Background color ${option.name}',
                      selected: isSelected,
                      child: Container(
                        margin: const EdgeInsets.all(DesignTokens.spacingBase),
                        decoration: BoxDecoration(
                          color: Color(option.color),
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusMedium,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? DesignTokens.brandColor
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

  Future<void> _saveScrapbook() async {
    setState(() => _isSaving = true);

    try {
      // Get existing scrapbook data to preserve createdAt
      final existingScrapbook = widget.scrapbookId != null
          ? ref
              .read(scrapbookStateProvider)
              .scrapbooks
              .where((s) => s.id == widget.scrapbookId)
              .firstOrNull
          : null;

      final scrapbook = ScrapbookModel(
        id: widget.scrapbookId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
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
        await ref
            .read(scrapbookStateProvider.notifier)
            .updateScrapbook(scrapbook);
      } else {
        await ref.read(scrapbookStateProvider.notifier).addScrapbook(scrapbook);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: DesignTokens.spacingSmall),
              Text(
                widget.scrapbookId != null
                    ? 'Scrapbook updated!'
                    : 'Scrapbook saved!',
                style: GoogleFonts.lexend(
                  fontWeight: DesignTokens.weightSemiBold,
                ),
              ),
            ],
          ),
          backgroundColor: DesignTokens.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
        ),
      );

      // Navigate back to home
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: DesignTokens.spacingSmall),
              Expanded(
                child: Text(
                  'Failed to save: ${e.toString()}',
                  style: GoogleFonts.lexend(),
                ),
              ),
            ],
          ),
          backgroundColor: DesignTokens.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
        ),
        title: Text(
          '$type Permission Required',
          style: GoogleFonts.lexend(
            fontSize: DesignTokens.fontSizeTitle,
            fontWeight: DesignTokens.weightSemiBold,
            color: DesignTokens.textPrimary,
          ),
        ),
        content: Text(
          'Please grant $type permission to continue.',
          style: GoogleFonts.lexend(
            fontSize: DesignTokens.fontSizeBody,
            fontWeight: DesignTokens.weightRegular,
            color: DesignTokens.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.lexend(
                color: DesignTokens.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: TextButton.styleFrom(
              foregroundColor: DesignTokens.brandColor,
            ),
            child: Text(
              'Settings',
              style: GoogleFonts.lexend(
                fontWeight: DesignTokens.weightSemiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
        ),
        title: Text(
          title,
          style: GoogleFonts.lexend(
            fontSize: DesignTokens.fontSizeTitle,
            fontWeight: DesignTokens.weightSemiBold,
            color: DesignTokens.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.lexend(
            fontSize: DesignTokens.fontSizeBody,
            fontWeight: DesignTokens.weightRegular,
            color: DesignTokens.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: DesignTokens.brandColor,
            ),
            child: Text(
              'OK',
              style: GoogleFonts.lexend(
                fontWeight: DesignTokens.weightSemiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Check if a local position is on the resize/rotate handle (bottom-right corner)
  bool _isOnResizeHandle(Offset localPosition, Size itemSize) {
    const handleSize = 30.0;
    final handleArea = Rect.fromPoints(
      Offset(itemSize.width - handleSize, itemSize.height - handleSize),
      Offset(itemSize.width, itemSize.height),
    );
    return handleArea.contains(localPosition);
  }

  // Check if a local position is on any control handle
  bool _isOnControlHandle(Offset localPosition, Size itemSize) {
    const handleSize = 32.0;
    const offset = 12.0;
    const touchPadding = 4.0;
    final totalHandleSize = handleSize + (touchPadding * 2);
    final handleOffset = offset + touchPadding;

    // Check all 4 corners
    // Top-left (delete button)
    final topLeftHandle = Rect.fromCircle(
      center: Offset(-handleOffset, -handleOffset),
      radius: totalHandleSize / 2,
    );
    if (topLeftHandle.contains(localPosition)) return true;

    // Top-right (duplicate button)
    final topRightHandle = Rect.fromCircle(
      center: Offset(itemSize.width + handleOffset, -handleOffset),
      radius: totalHandleSize / 2,
    );
    if (topRightHandle.contains(localPosition)) return true;

    // Bottom-left (flip button)
    final bottomLeftHandle = Rect.fromCircle(
      center: Offset(-handleOffset, itemSize.height + handleOffset),
      radius: totalHandleSize / 2,
    );
    if (bottomLeftHandle.contains(localPosition)) return true;

    // Bottom-right (resize/rotate handle)
    final bottomRightHandle = Rect.fromCircle(
      center: Offset(itemSize.width + handleOffset, itemSize.height + handleOffset),
      radius: totalHandleSize / 2,
    );
    if (bottomRightHandle.contains(localPosition)) return true;

    return false;
  }

  // Calculate angle between two points
  double _calculateAngle(Offset point1, Offset point2) {
    return (point2 - point1).direction;
  }

  // Handle resize and rotate updates from drag gesture
  void _handleResizeRotateUpdate(Offset globalPosition, String itemId, String type) {
    if (_resizeStartPos == null || _initialScale == null || _initialRotation == null) return;

    // Calculate distance change for scale
    final currentDist = (globalPosition - (_canvasSize == null
        ? Offset.zero
        : Offset(_canvasSize!.width / 2, _canvasSize!.height / 2))).distance;
    final initialDist = (_resizeStartPos! - (_canvasSize == null
        ? Offset.zero
        : Offset(_canvasSize!.width / 2, _canvasSize!.height / 2))).distance;
    final scaleFactor = currentDist / initialDist;
    final newScale = (_initialScale! * scaleFactor).clamp(0.5, 3.0);

    // Calculate rotation change
    final currentAngle = _calculateAngle(
      globalPosition,
      _canvasSize == null ? Offset.zero : Offset(_canvasSize!.width / 2, _canvasSize!.height / 2),
    );
    final angleDelta = currentAngle - (_initialAngle ?? 0.0);
    final newRotation = _initialRotation! + angleDelta;

    setState(() {
      if (type == 'text') {
        final index = _textOverlays.indexWhere((o) => o.id == itemId);
        if (index != -1) {
          _textOverlays[index] = _textOverlays[index].copyWith(
            scale: newScale,
            rotation: newRotation,
          );
        }
      } else if (type == 'sticker') {
        final index = _stickers.indexWhere((s) => s.id == itemId);
        if (index != -1) {
          _stickers[index] = _stickers[index].copyWith(
            scale: newScale,
            rotation: newRotation,
          );
        }
      } else if (type == 'photo') {
        final index = _additionalPhotos.indexWhere((p) => p.id == itemId);
        if (index != -1) {
          // For photos, we adjust width/height instead of scale
          _additionalPhotos[index] = _additionalPhotos[index].copyWith(
            width: (_additionalPhotos[index].width * scaleFactor).clamp(0.1, 0.8),
            height: (_additionalPhotos[index].height * scaleFactor).clamp(0.1, 0.8),
            rotation: newRotation,
          );
        }
      }
    });
  }

  // Build control handles for selected elements
  List<Widget> _buildControlHandles(String itemId, String type, bool isFlipped) {
    const handleSize = 32.0; // Larger touch target
    const offset = 12.0; // Reduced spacing from element edge
    const touchPadding = 4.0; // Extra padding for better touch recognition

    return [
      // Delete button (top-left)
      Positioned(
        left: -offset,
        top: -offset,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            // Prevent parent GestureDetector from handling this tap
          },
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() {
              if (type == 'text') {
                _textOverlays.removeWhere((o) => o.id == itemId);
              } else if (type == 'sticker') {
                _stickers.removeWhere((s) => s.id == itemId);
              } else if (type == 'photo') {
                _additionalPhotos.removeWhere((p) => p.id == itemId);
              }
              _selectedId = null;
              _selectedType = null;
            });
          },
          child: Padding(
            padding: EdgeInsets.all(touchPadding),
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ),

      // Duplicate button (top-right)
      Positioned(
        right: -offset,
        top: -offset,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            // Prevent parent GestureDetector from handling this tap
          },
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (type == 'text') {
                final original = _textOverlays.firstWhere((o) => o.id == itemId);
                _textOverlays.add(ScrapbookTextOverlay(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  text: original.text,
                  x: original.x + 0.05,
                  y: original.y + 0.05,
                  color: original.color,
                  fontSize: original.fontSize,
                  scale: original.scale,
                  rotation: original.rotation,
                  flip: original.flip,
                ));
              } else if (type == 'sticker') {
                final original = _stickers.firstWhere((s) => s.id == itemId);
                _stickers.add(ScrapbookSticker(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  emoji: original.emoji,
                  x: original.x + 0.05,
                  y: original.y + 0.05,
                  scale: original.scale,
                  rotation: original.rotation,
                  flip: original.flip,
                ));
              } else if (type == 'photo') {
                final original = _additionalPhotos.firstWhere((p) => p.id == itemId);
                _additionalPhotos.add(ScrapbookPhoto(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  imagePath: original.imagePath,
                  x: original.x + 0.05,
                  y: original.y + 0.05,
                  width: original.width,
                  height: original.height,
                  rotation: original.rotation,
                  flip: original.flip,
                ));
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.all(touchPadding),
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.copy,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ),

      // Flip button (bottom-left)
      Positioned(
        left: -offset,
        bottom: -offset,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            // Prevent parent GestureDetector from handling this tap
          },
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (type == 'text') {
                final index = _textOverlays.indexWhere((o) => o.id == itemId);
                if (index != -1) {
                  _textOverlays[index] = _textOverlays[index].copyWith(
                    flip: !_textOverlays[index].flip,
                  );
                }
              } else if (type == 'sticker') {
                final index = _stickers.indexWhere((s) => s.id == itemId);
                if (index != -1) {
                  _stickers[index] = _stickers[index].copyWith(
                    flip: !_stickers[index].flip,
                  );
                }
              } else if (type == 'photo') {
                final index = _additionalPhotos.indexWhere((p) => p.id == itemId);
                if (index != -1) {
                  _additionalPhotos[index] = _additionalPhotos[index].copyWith(
                    flip: !_additionalPhotos[index].flip,
                  );
                }
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.all(touchPadding),
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isFlipped ? Icons.flip_rounded : Icons.flip_to_back,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ),

      // Resize/Rotate handle (bottom-right)
      Positioned(
        right: -offset,
        bottom: -offset,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // This is visual-only, actual resize/rotate handled by onScaleStart
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: EdgeInsets.all(touchPadding),
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.open_in_full,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  String _getWeekday(int day) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return weekdays[day - 1];
  }

  String _getMonth(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month - 1];
  }

  // ============= Helper Widgets =============
}

/// Reusable top bar button widget
class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: DesignTokens.iconButtonSize,
        height: DesignTokens.iconButtonSize,
        decoration: BoxDecoration(
          color:
              DesignTokens.whiteWithOpacity(DesignTokens.opacityMostlyOpaque),
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          boxShadow: DesignTokens.shadowSubtle,
        ),
        child: Icon(
          icon,
          color: DesignTokens.textPrimary,
          size: 18,
        ),
      ),
    );
  }
}

/// Reusable save button with loading state
class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback? onTap;

  const _SaveButton({
    required this.isSaving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: DesignTokens.iconButtonSize,
        height: DesignTokens.iconButtonSize,
        decoration: BoxDecoration(
          color: isSaving ? Colors.grey.shade300 : DesignTokens.brandColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          boxShadow: DesignTokens.shadowStrong,
        ),
        child: Center(
          child: isSaving
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
                    fontWeight: DesignTokens.weightSemiBold,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}
