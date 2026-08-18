import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_pkg;
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
  final GlobalKey _canvasAreaKey = GlobalKey();
  final GlobalKey _toolbarKey = GlobalKey();
  final LayerLink _canvasLayerLink = LayerLink();

  // Permanent ID for new scrapbooks (generated once, used throughout)
  late String _permanentScrapbookId;
  // Store the timestamp when ID was generated for consistent createdAt
  late DateTime _generatedTime;

  // Cache for file existence check to avoid repeated checks during rebuilds
  final Set<String> _existingFilePaths = {};
  final Set<String> _checkedFilePaths = {};

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
  late List<String> _originalElementLayerOrder;

  // UI state
  bool _isSaving = false;
  int _selectedToolbarIndex =
      -1; // -1 = none, 0 = text, 1 = sticker, 2 = photo, 3 = background
  String? _selectedStickerSetId; // For sticker picker

  // Language flip state for sentences only
  bool _showThaiSentences = false; // false = show English, true = show Thai for sentences

  // Flip animation
  bool _isFlipping = false;

  // Dragging state
  String? _draggingId; // ID of item being dragged
  String? _draggingType; // 'text', 'sticker', or 'photo'
  Offset? _dragStartOffset;
  Offset? _itemStartOffset;

  // Selection state (for showing resize/rotate controls)
  String? _selectedId; // ID of selected item
  String? _selectedType; // 'text', 'sticker', or 'photo'
  Offset? _lastTapPosition; // Last tap position for control handle detection
  late List<String> _elementLayerOrder;

  // Resize/rotate state
  String? _resizingId; // ID of item being resized/rotated
  String? _resizingType; // 'text', 'sticker', or 'photo'
  String?
      _resizingHandle; // 'left', 'right', or 'corner' for horizontal resizing
  Offset? _resizeStartPos; // Initial pointer position for resize
  double? _initialScale; // Initial scale for resize operation
  double? _initialRotation; // Initial rotation for resize operation
  double? _initialAngle; // Initial angle for rotation calculation
  Offset? _resizeCenterGlobal;
  Size? _initialPhotoSize;
  double? _initialWidth; // Initial width for horizontal resize

  // Pinch gesture state
  double? _initialPinchScale;
  double? _initialItemScaleForPinch;
  double? _initialItemRotationForPinch;

  // Canvas size for positioning calculations
  Size? _canvasSize;

  // Touch sandbox extension (pixels beyond canvas edge for touch targets)
  static const double _touchSandbox = 100.0;

  // Available emojis for selection
  static const List<String> _availableEmojis = [
    // Happy and playful
    '\u{1F600}',
    '\u{1F603}',
    '\u{1F604}',
    '\u{1F601}',
    '\u{1F606}',
    '\u{1F602}',
    '\u{1F923}',
    '\u{1F642}',
    '\u{1F643}',
    '\u{1F609}',
    '\u{1F61C}',
    '\u{1F92A}',
    '\u{1F60B}',

    // Love, warmth, and pride
    '\u{1F970}',
    '\u{1F60D}',
    '\u{1F618}',
    '\u{1F917}',
    '\u{1F607}',
    '\u{1F60E}',
    '\u{1F929}',
    '\u{1F973}',
    '\u{1F924}',

    // Calm, shy, and thoughtful
    '\u{1F60C}',
    '\u{1F60F}',
    '\u{1F92D}',
    '\u{1FAE3}',
    '\u{1F92B}',
    '\u{1F914}',
    '\u{1F928}',
    '\u{1F633}',
    '\u{1F97A}',
    '\u{1F979}',

    // Neutral, confused, and bored
    '\u{1F610}',
    '\u{1F611}',
    '\u{1F636}',
    '\u{1F644}',
    '\u{1F612}',
    '\u{1F615}',
    '\u{1FAE4}',
    '\u{1F61F}',
    '\u{1F614}',
    '\u{1F62C}',

    // Sad, hurt, and crying
    '\u{1F61E}',
    '\u{1F622}',
    '\u{1F62D}',
    '\u{1F625}',
    '\u{1F613}',
    '\u{1F629}',
    '\u{1F62B}',
    '\u{1F623}',
    '\u{1F616}',
    '\u{1F494}',

    // Worried, afraid, and shocked
    '\u{1F628}',
    '\u{1F630}',
    '\u{1F631}',
    '\u{1F632}',
    '\u{1FAE2}',
    '\u{1FAE8}',
    '\u{1F635}',

    // Tired and unwell
    '\u{1F634}',
    '\u{1F971}',
    '\u{1F62A}',
    '\u{1F912}',
    '\u{1F915}',
    '\u{1F922}',
    '\u{1F92E}',

    // Frustrated and angry
    '\u{1F624}',
    '\u{1F620}',
    '\u{1F621}',
    '\u{1F92C}',
    '\u{1F608}',
    '\u{1F47F}',

    // Existing decorative choices
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

  @override
  void initState() {
    super.initState();
    // Generate permanent ID for new scrapbooks, or use existing ID
    _generatedTime = DateTime.now().toUtc();
    _permanentScrapbookId =
        widget.scrapbookId ?? _generatedTime.millisecondsSinceEpoch.toString();
    _selectedEmoji = widget.selectedEmoji;
    _textOverlays = [];
    _stickers = [];
    _additionalPhotos = [];
    _elementLayerOrder = [];
    _backgroundColor = 0xFFFFFFFF;

    // Store original state for comparison
    _originalTextOverlays = [];
    _originalStickers = [];
    _originalAdditionalPhotos = [];
    _originalBackgroundColor = 0xFFFFFFFF;
    _originalSelectedEmoji = widget.selectedEmoji;
    _originalElementLayerOrder = [];

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
                  fontFamily: overlay.fontFamily,
                  scale: overlay.scale,
                  rotation: overlay.rotation,
                  flip: overlay.flip,
                  backgroundColor: overlay.backgroundColor,
                  width: overlay.width,
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
        // Load saved layer order or initialize from current elements
        if (existingScrapbook.elementLayerOrder.isNotEmpty) {
          _elementLayerOrder = List.from(existingScrapbook.elementLayerOrder);
        } else {
          _initializeElementLayerOrder();
        }
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
                  fontFamily: overlay.fontFamily,
                  scale: overlay.scale,
                  rotation: overlay.rotation,
                  flip: overlay.flip,
                  backgroundColor: overlay.backgroundColor,
                  width: overlay.width,
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
        _originalElementLayerOrder = List.from(_elementLayerOrder);
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
    // Check if layer order has changed
    if (_elementLayerOrder.length != _originalElementLayerOrder.length) return true;
    for (int i = 0; i < _elementLayerOrder.length; i++) {
      if (_elementLayerOrder[i] != _originalElementLayerOrder[i]) return true;
    }

    // Check for position/content changes in text overlays
    for (int i = 0; i < _textOverlays.length; i++) {
      if (_textOverlays[i].x != _originalTextOverlays[i].x ||
          _textOverlays[i].y != _originalTextOverlays[i].y ||
          _textOverlays[i].text != _originalTextOverlays[i].text ||
          _textOverlays[i].color != _originalTextOverlays[i].color ||
          _textOverlays[i].fontSize != _originalTextOverlays[i].fontSize ||
          _textOverlays[i].fontFamily != _originalTextOverlays[i].fontFamily ||
          _textOverlays[i].backgroundColor !=
              _originalTextOverlays[i].backgroundColor ||
          _textOverlays[i].scale != _originalTextOverlays[i].scale ||
          _textOverlays[i].rotation != _originalTextOverlays[i].rotation ||
          _textOverlays[i].flip != _originalTextOverlays[i].flip ||
          _textOverlays[i].width != _originalTextOverlays[i].width) {
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
          _additionalPhotos[i].rotation !=
              _originalAdditionalPhotos[i].rotation ||
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
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_selectedId != null) {
                            setState(() {
                              _selectedId = null;
                              _selectedType = null;
                            });
                          }
                        },
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
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Element layer follows the canvas but can receive gestures
                // anywhere between the date and the bottom toolbar.
                _buildElementOverlay(),

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
        DesignTokens.spacingSmall,
        DesignTokens.spacingLarge,
        DesignTokens.spacingMedium,
      ),
      child: Row(
        children: [
          _TopBarButton(
            icon: Icons.arrow_back_rounded,
            onTap: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: DesignTokens.spacingMedium),
          Expanded(
            child: Text(
              widget.scrapbookId == null ? 'Create a memory' : 'Edit memory',
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.fontSizeHeading,
                fontWeight: DesignTokens.weightBold,
                color: DesignTokens.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spacingMedium),
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
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingLarge,
        0,
        DesignTokens.spacingLarge,
        DesignTokens.spacingLarge,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: Color(0xFF6D4BD1),
              ),
              const SizedBox(width: 7),
              Text(
                '$weekday, $day $month $year',
                style: GoogleFonts.lexend(
                  fontSize: DesignTokens.fontSizeSmall,
                  fontWeight: DesignTokens.weightSemiBold,
                  color: const Color(0xFF5036A6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrapbookCanvas() {
    return Padding(
      padding: const EdgeInsets.only(
        left: DesignTokens.spacingLarge,
        right: DesignTokens.spacingLarge,
        bottom: DesignTokens.spacingXLarge,
      ),
      child: Column(
        children: [
          CompositedTransformTarget(
            link: _canvasLayerLink,
            child: SizedBox(
              key: _canvasAreaKey,
              height: DesignTokens.scrapbookCanvasHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                child: _buildPolaroidFrame(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build Polaroid-style frame with colored border and bottom writing area
  Widget _buildPolaroidFrame() {
    return Container(
      // No background color - transparent to show nothing behind polaroid
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
                color: Color(_backgroundColor), // Use color picker for frame
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
                          child: _buildMainImage(),
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

  /// Build the main scrapbook image (supports both local path and HTTP URL)
  Widget _buildMainImage() {
    // Check if path is HTTP/HTTPS URL
    final isNetworkUrl = widget.imagePath.startsWith('http://') ||
        widget.imagePath.startsWith('https://');

    if (isNetworkUrl) {
      // Network URL - use Image.network
      return Image.network(
        widget.imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey, size: 48),
                  SizedBox(height: 8),
                  Text('Failed to load image',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    } else {
      // Local file - use Image.file
      return Image.file(
        File(widget.imagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.red, size: 48),
                  SizedBox(height: 8),
                  Text('File not found',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildElementOverlay() {
    const canvasSize = DesignTokens.scrapbookCanvasHeight;

    _canvasSize = const Size(canvasSize, canvasSize);

    return Positioned.fill(
      child: CompositedTransformFollower(
        link: _canvasLayerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.topLeft,
        child: Transform.translate(
          offset: const Offset(-_touchSandbox, -_touchSandbox),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Emoji overlay (centered in canvas)
              _buildEmojiSelector(),

              // Draggable items follow the persistent bring-to-front order.
              ..._buildDraggableItems(),

              // Controls live in their own overlay so their complete hit
              // targets are not clipped by the selected item's bounds.
              _buildSelectedControlOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDraggableItems() {
    final itemsByKey = <String, Widget>{};

    for (final overlay in _textOverlays) {
      itemsByKey[_elementKey('text', overlay.id)] = _buildTextOverlay(overlay);
    }

    for (final sticker in _stickers) {
      itemsByKey[_elementKey('sticker', sticker.id)] = _buildSticker(sticker);
    }

    for (final photo in _additionalPhotos) {
      itemsByKey[_elementKey('photo', photo.id)] = _buildAdditionalPhoto(photo);
    }

    final orderedItems = <Widget>[];
    for (final key in _elementLayerOrder) {
      final item = itemsByKey.remove(key);
      if (item != null) orderedItems.add(item);
    }
    orderedItems.addAll(itemsByKey.values);
    return orderedItems;
  }

  String _elementKey(String type, String id) => '$type:$id';

  void _initializeElementLayerOrder() {
    _elementLayerOrder = [
      ..._textOverlays.map((item) => _elementKey('text', item.id)),
      ..._stickers.map((item) => _elementKey('sticker', item.id)),
      ..._additionalPhotos.map((item) => _elementKey('photo', item.id)),
    ];
  }

  void _bringElementToFront(String id, String type) {
    final key = _elementKey(type, id);
    _elementLayerOrder
      ..remove(key)
      ..add(key);
  }

  double _dragMinYFor(double halfElementHeight) =>
      halfElementHeight / DesignTokens.scrapbookCanvasHeight;

  double _dragMaxYFor(double halfElementHeight) {
    final canvasBox =
        _canvasAreaKey.currentContext?.findRenderObject() as RenderBox?;
    final toolbarBox =
        _toolbarKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null || toolbarBox == null) {
      return 1.75 - _dragMinYFor(halfElementHeight);
    }

    final canvasTop = canvasBox.localToGlobal(Offset.zero).dy;
    final toolbarTop = toolbarBox.localToGlobal(Offset.zero).dy;
    const toolbarGap = DesignTokens.spacingMedium;
    return ((toolbarTop - toolbarGap - halfElementHeight - canvasTop) /
            DesignTokens.scrapbookCanvasHeight)
        .clamp(_dragMinYFor(halfElementHeight), 3.0);
  }

  /// Build emoji selector button
  Widget _buildEmojiSelector() {
    const touchSandbox = _touchSandbox;
    const emojiLeft = touchSandbox +
        ((DesignTokens.scrapbookCanvasWidth - DesignTokens.emojiButtonSize) /
            2);
    const emojiTop = touchSandbox + DesignTokens.spacingLarge;

    return Positioned(
      left: emojiLeft,
      top: emojiTop,
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

    // Base size (before scaling)
    final baseWidth = overlay.width != null
        ? overlay.width! * _canvasSize!.width
        : 100.0 * overlay.scale;
    final baseHeight = 50.0 * overlay.scale;

    // Use width directly if set, otherwise use scale-based width
    final scaledWidth = baseWidth;
    final scaledHeight = baseHeight;
    final contentScale = overlay.scale;

    // Offset to center the item
    final centerOffsetX = scaledWidth / 2;
    final centerOffsetY = scaledHeight / 2;

    final isSelected = _selectedId == overlay.id;

    return Positioned(
      key: ValueKey('text:${overlay.id}'),
      left: left - centerOffsetX,
      top: top - centerOffsetY,
      child: GestureDetector(
        onTapDown: (details) {
          // Store tap position for control handle detection
          _lastTapPosition = details.localPosition;
        },
        onTap: () {
          // If selected and tap is on control handle, don't toggle selection
          if (isSelected &&
              _lastTapPosition != null &&
              _isOnControlHandle(
                  _lastTapPosition!, Size(scaledWidth, scaledHeight),
                  type: 'text')) {
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
              _bringElementToFront(overlay.id, 'text');
              _selectedId = overlay.id;
              _selectedType = 'text';
            }
          });
        },
        onDoubleTap: () {
          _editText(overlay);
        },
        onScaleStart: (details) {
          if (details.pointerCount == 1) {
            // Check if tapping on any handle
            if (isSelected) {
              // Check for corner resize/rotate handle
              if (_isOnResizeHandle(
                  details.localFocalPoint, Size(scaledWidth, scaledHeight))) {
                setState(() {
                  _resizingId = overlay.id;
                  _resizingType = 'text';
                  _resizingHandle = 'corner';
                  _resizeStartPos = details.localFocalPoint;
                  _initialScale = overlay.scale;
                  _initialRotation = overlay.rotation;
                  _initialAngle = _calculateAngle(
                      details.localFocalPoint, Offset(left, top));
                });
                return;
              }
              // Check for left center handle (horizontal resize)
              final itemCenterY = scaledHeight / 2;
              if (_isOnLeftCenterHandle(
                  details.localFocalPoint, Size(scaledWidth, scaledHeight))) {
                setState(() {
                  _resizingId = overlay.id;
                  _resizingType = 'text';
                  _resizingHandle = 'left';
                  _resizeStartPos = details.localFocalPoint;
                  _initialWidth =
                      overlay.width ?? (baseWidth / _canvasSize!.width);
                });
                return;
              }
              // Check for right center handle (horizontal resize)
              if (_isOnRightCenterHandle(
                  details.localFocalPoint, Size(scaledWidth, scaledHeight))) {
                setState(() {
                  _resizingId = overlay.id;
                  _resizingType = 'text';
                  _resizingHandle = 'right';
                  _resizeStartPos = details.localFocalPoint;
                  _initialWidth =
                      overlay.width ?? (baseWidth / _canvasSize!.width);
                });
                return;
              }
            }
            // Start dragging
            setState(() {
              _draggingId = overlay.id;
              _draggingType = 'text';
              _bringElementToFront(overlay.id, 'text');
              _selectedId = overlay.id;
              _selectedType = 'text';
              _dragStartOffset = details.localFocalPoint;
              _itemStartOffset = Offset(overlay.x, overlay.y);
            });
          } else if (details.pointerCount > 1) {
            // Two-finger gesture started
            setState(() {
              _bringElementToFront(overlay.id, 'text');
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
            if (_resizingHandle == 'left' || _resizingHandle == 'right') {
              // Handle horizontal resize from left/right handles
              _handleHorizontalResizeUpdate(
                details.localFocalPoint,
                overlay.id,
                _resizingHandle!,
              );
            } else {
              // Handle resize/rotate from corner handle
              _handleResizeRotateUpdate(
                details.localFocalPoint,
                overlay.id,
                'text',
              );
            }
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

              // Keep the element centre within the full touch sandbox.
              final clampedX = newX.clamp(-0.3, 1.3);
              final clampedY = newY.clamp(
                _dragMinYFor(centerOffsetY),
                _dragMaxYFor(centerOffsetY),
              );

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
              final scaleFactor =
                  _initialPinchScale != null && _initialPinchScale! > 0
                      ? currentDistance / _initialPinchScale!
                      : 1.0;
              final newScale =
                  (_initialItemScaleForPinch! * scaleFactor).clamp(0.5, 3.0);

              // Calculate new rotation based on rotation gesture
              final newRotation =
                  _initialItemRotationForPinch! + details.rotation;

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
              _resizingHandle = null;
              _resizeStartPos = null;
              _initialScale = null;
              _initialRotation = null;
              _initialAngle = null;
              _initialWidth = null;
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
        child: SizedBox(
          width: scaledWidth,
          height: scaledHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Everything inside rotates together
              Center(
                child: Transform.rotate(
                  angle: overlay.rotation,
                  child: SizedBox(
                    width: scaledWidth,
                    height: scaledHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Text content container with background
                        Center(
                          child: Container(
                            constraints: BoxConstraints(
                              minWidth: scaledWidth > 0
                                  ? math.min(30.0, scaledWidth)
                                  : 30,
                              maxWidth: scaledWidth > 0
                                  ? scaledWidth
                                  : double.infinity,
                            ),
                            padding: overlay.backgroundColor != null
                                ? EdgeInsets.symmetric(
                                    horizontal: 12.0 * contentScale,
                                    vertical: 8.0 * contentScale,
                                  )
                                : EdgeInsets.symmetric(
                                    horizontal: 8.0 * contentScale,
                                    vertical: 4.0 * contentScale,
                                  ),
                            decoration: BoxDecoration(
                              color: overlay.backgroundColor != null
                                  ? Color(overlay.backgroundColor!)
                                      .withValues(alpha: 0.95)
                                  : Colors.transparent,
                            ),
                            child: Text(
                              overlay.text,
                              style: _getFontStyle(overlay.fontFamily).copyWith(
                                color: Color(overlay.color),
                                fontSize: overlay.fontSize * contentScale,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                        // Selection border (rotates and scales with the whole container)
                        if (isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
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

    // Base sticker size (100x100) scaled by sticker.scale
    final baseSize = 100.0;
    final stickerSize = baseSize * sticker.scale;

    // Offset to center the item
    final centerOffsetX = stickerSize / 2;
    final centerOffsetY = stickerSize / 2;

    final isSelected = _selectedId == sticker.id;

    return Positioned(
      key: ValueKey('sticker:${sticker.id}'),
      left: left - centerOffsetX,
      top: top - centerOffsetY,
      child: SizedBox(
        width: stickerSize,
        height: stickerSize,
        child: GestureDetector(
          onTapDown: (details) {
            // Store tap position for control handle detection
            _lastTapPosition = details.localPosition;
          },
          onTap: () {
            // If selected and tap is on control handle, don't toggle selection
            if (isSelected &&
                _lastTapPosition != null &&
                _isOnControlHandle(
                    _lastTapPosition!, Size(stickerSize, stickerSize),
                    type: 'sticker')) {
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
                _bringElementToFront(sticker.id, 'sticker');
                _selectedId = sticker.id;
                _selectedType = 'sticker';
              }
            });
          },
          onScaleStart: (details) {
            if (details.pointerCount == 1) {
              // Single finger - check if tapping on resize handle
              if (isSelected &&
                  _isOnResizeHandle(details.localFocalPoint,
                      Size(stickerSize, stickerSize))) {
                setState(() {
                  _resizingId = sticker.id;
                  _resizingType = 'sticker';
                  _resizeStartPos = details.localFocalPoint;
                  _initialScale = sticker.scale;
                  _initialRotation = sticker.rotation;
                  _initialAngle = _calculateAngle(
                      details.localFocalPoint, Offset(left, top));
                });
              } else {
                // Start dragging
                setState(() {
                  _draggingId = sticker.id;
                  _draggingType = 'sticker';
                  _bringElementToFront(sticker.id, 'sticker');
                  _selectedId = sticker.id;
                  _selectedType = 'sticker';
                  _dragStartOffset = details.localFocalPoint;
                  _itemStartOffset = Offset(sticker.x, sticker.y);
                });
              }
            } else if (details.pointerCount > 1) {
              // Two-finger gesture started
              setState(() {
                _bringElementToFront(sticker.id, 'sticker');
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

                // Keep the element centre within the full touch sandbox.
                final clampedX = newX.clamp(-0.3, 1.3);
                final clampedY = newY.clamp(
                  _dragMinYFor(centerOffsetY),
                  _dragMaxYFor(centerOffsetY),
                );

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
                final scaleFactor =
                    _initialPinchScale != null && _initialPinchScale! > 0
                        ? currentDistance / _initialPinchScale!
                        : 1.0;
                final newScale =
                    (_initialItemScaleForPinch! * scaleFactor).clamp(0.5, 3.0);

                // Calculate new rotation based on rotation gesture
                final newRotation =
                    _initialItemRotationForPinch! + details.rotation;

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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Everything inside rotates together
              Center(
                child: Transform.rotate(
                  angle: sticker.rotation,
                  child: SizedBox(
                    width: stickerSize,
                    height: stickerSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Sticker content with flip
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Transform.scale(
                            scaleX: sticker.flip ? -1.0 : 1.0,
                            scaleY: 1.0,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: stickerSize,
                              height: stickerSize,
                              child: Image.asset(
                                sticker.emoji,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Text(sticker.emoji,
                                      style: const TextStyle(fontSize: 40));
                                },
                              ),
                            ),
                          ),
                        ),
                        // Selection border
                        if (isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build widget for additional photo (supports both local path and HTTP URL)
  Widget _buildAdditionalPhotoWidget(ScrapbookPhoto photo) {
    // Check if path is HTTP/HTTPS URL (do this first, before cache check)
    final isNetworkUrl = photo.imagePath.startsWith('http://') ||
        photo.imagePath.startsWith('https://');

    if (isNetworkUrl) {
      // Network URL - use Image.network
      return Image.network(
        photo.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey, size: 32),
                  SizedBox(height: 4),
                  Text('Failed to load',
                      style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    // Local file path - check if we've already confirmed this file doesn't exist
    if (_existingFilePaths.contains(photo.imagePath)) {
      // File exists - show it with FileImage for better caching
      return Image(
        image: FileImage(File(photo.imagePath)),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If loading fails after we thought it existed, remove from cache and show error
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _existingFilePaths.remove(photo.imagePath);
                _checkedFilePaths.add(photo.imagePath);
              });
            }
          });
          return Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.red, size: 32),
                  SizedBox(height: 4),
                  Text('Failed to load',
                      style: TextStyle(color: Colors.red, fontSize: 10)),
                ],
              ),
            ),
          );
        },
      );
    }

    // If we've confirmed this file doesn't exist, show error
    if (_checkedFilePaths.contains(photo.imagePath)) {
      return Container(
        color: Colors.grey.shade300,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, color: Colors.red, size: 32),
              SizedBox(height: 4),
              Text('File not found',
                  style: TextStyle(color: Colors.red, fontSize: 10)),
            ],
          ),
        ),
      );
    }

    // First time seeing this file - check existence asynchronously
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final file = File(photo.imagePath);
      final exists = await file.exists();

      print('🔍 File check result for ${photo.imagePath}: ${exists ? "EXISTS" : "NOT FOUND"}');

      if (mounted) {
        setState(() {
          _checkedFilePaths.add(photo.imagePath);
          if (exists) {
            _existingFilePaths.add(photo.imagePath);
          }
        });
      }
    });

    // Show loading while checking
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
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
      key: ValueKey('photo:${photo.id}'),
      left: left - centerOffsetX,
      top: top - centerOffsetY,
      child: SizedBox(
        width: width,
        height: height,
        child: GestureDetector(
          onTapDown: (details) {
            // Store tap position for control handle detection
            _lastTapPosition = details.localPosition;
          },
          onTap: () {
            // If selected and tap is on control handle, don't toggle selection
            if (isSelected &&
                _lastTapPosition != null &&
                _isOnControlHandle(_lastTapPosition!, Size(width, height),
                    type: 'photo')) {
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
                _bringElementToFront(photo.id, 'photo');
                _selectedId = photo.id;
                _selectedType = 'photo';
              }
            });
          },
          onScaleStart: (details) {
            if (details.pointerCount == 1) {
              // Single finger - check if tapping on resize handle
              if (isSelected &&
                  _isOnResizeHandle(
                      details.localFocalPoint, Size(width, height))) {
                setState(() {
                  _resizingId = photo.id;
                  _resizingType = 'photo';
                  _resizeStartPos = details.localFocalPoint;
                  _initialScale =
                      1.0; // Store 1.0 as base for photo size calculation
                  _initialRotation = photo.rotation;
                  _initialAngle = _calculateAngle(
                      details.localFocalPoint, Offset(left, top));
                });
              } else {
                // Start dragging
                setState(() {
                  _draggingId = photo.id;
                  _draggingType = 'photo';
                  _bringElementToFront(photo.id, 'photo');
                  _selectedId = photo.id;
                  _selectedType = 'photo';
                  _dragStartOffset = details.localFocalPoint;
                  _itemStartOffset = Offset(photo.x, photo.y);
                });
              }
            } else if (details.pointerCount > 1) {
              // Two-finger gesture started
              setState(() {
                _bringElementToFront(photo.id, 'photo');
                _selectedId = photo.id;
                _selectedType = 'photo';
                _initialPinchScale = details.localFocalPoint.distance;
                // For photos, store initial width/height
                _initialItemScaleForPinch =
                    photo.width; // Use width as scale reference
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

                // Keep the element centre within the full touch sandbox.
                final clampedX = newX.clamp(-0.3, 1.3);
                final clampedY = newY.clamp(
                  _dragMinYFor(centerOffsetY),
                  _dragMaxYFor(centerOffsetY),
                );

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
                final scaleFactor =
                    _initialPinchScale != null && _initialPinchScale! > 0
                        ? currentDistance / _initialPinchScale!
                        : 1.0;

                // Calculate new rotation based on rotation gesture
                final newRotation =
                    _initialItemRotationForPinch! + details.rotation;

                final index =
                    _additionalPhotos.indexWhere((p) => p.id == photo.id);
                if (index != -1) {
                  // Maintain aspect ratio when scaling
                  final originalWidth = _initialItemScaleForPinch!;
                  final newWidth =
                      (originalWidth * scaleFactor).clamp(0.1, 0.8);
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Everything inside rotates together
              Center(
                child: Transform.rotate(
                  angle: photo.rotation,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Photo with flip applied
                        Transform.scale(
                          scaleX: photo.flip ? -1.0 : 1.0,
                          scaleY: 1.0,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: _buildAdditionalPhotoWidget(photo),
                          ),
                        ),
                        // Selection border
                        if (isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build highlighted text with vocabulary words
  Widget _buildHighlightedText({
    required String text,
    required List<String> highlightWords,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    if (highlightWords.isEmpty) {
      return Text(text, style: baseStyle);
    }

    // Sort by length (longest first) to handle word boundaries correctly
    final sortedWords = highlightWords.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    // Build text spans with highlights
    final spans = <TextSpan>[];
    int currentIndex = 0;

    while (currentIndex < text.length) {
      bool foundMatch = false;
      String matchedWord = '';
      int earliestMatchIndex = text.length;

      // Find the earliest match among all highlight words
      for (final word in sortedWords) {
        final matchIndex =
            text.toLowerCase().indexOf(word.toLowerCase(), currentIndex);
        if (matchIndex != -1 && matchIndex < earliestMatchIndex) {
          earliestMatchIndex = matchIndex;
          matchedWord = word;
          foundMatch = true;
        }
      }

      if (foundMatch && matchedWord.isNotEmpty) {
        // Add text before the match
        if (earliestMatchIndex > currentIndex) {
          spans.add(TextSpan(
            text: text.substring(currentIndex, earliestMatchIndex),
            style: baseStyle,
          ));
        }

        // Add the highlighted word
        final actualWord = text.substring(
          earliestMatchIndex,
          earliestMatchIndex + matchedWord.length,
        );
        spans.add(TextSpan(
          text: actualWord,
          style: highlightStyle,
        ));

        currentIndex = earliestMatchIndex + matchedWord.length;
      } else {
        // No more matches, add remaining text
        spans.add(TextSpan(
          text: text.substring(currentIndex),
          style: baseStyle,
        ));
        break;
      }
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Widget _buildSentences() {
    // Split sentences by newlines or periods followed by space
    final englishSentences = widget.englishSentence
        .split(RegExp(r'\n|\.\s+(?=[A-Z])'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final thaiSentences = widget.thaiSentence
        .split(RegExp(r'\n|\.\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Select sentences based on current language state
    final selectedSentences =
        _showThaiSentences ? thaiSentences : englishSentences;
    final isEnglish = !_showThaiSentences;

    // Get vocabulary words for highlighting (English only)
    final englishWords = widget.vocabularyWords
        .map((v) => v.word)
        .where((w) => w.isNotEmpty)
        .toList();

    if (selectedSentences.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        left: DesignTokens.spacingLarge,
        right: DesignTokens.spacingLarge,
        bottom: DesignTokens.spacingLarge,
      ),
      child: GestureDetector(
        onTap: () {
          if (!_isFlipping) {
            setState(() {
              _isFlipping = true;
            });
            // Pop animation: scale down -> change -> scale up with bounce
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                setState(() {
                  _showThaiSentences = !_showThaiSentences;
                });
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) {
                    setState(() {
                      _isFlipping = false;
                    });
                  }
                });
              }
            });
          }
          HapticFeedback.lightImpact();
        },
        child: AnimatedScale(
          scale: _isFlipping ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: Container(
            padding: const EdgeInsets.all(DesignTokens.spacingLarge),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
              boxShadow: _isFlipping
                  ? [
                      BoxShadow(
                        color: DesignTokens.brandColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact header - just icon and language indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.language_rounded,
                      size: 14,
                      color: DesignTokens.brandColor.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isEnglish ? 'EN' : 'TH',
                      style: GoogleFonts.lexend(
                        fontSize: 11,
                        fontWeight: DesignTokens.weightSemiBold,
                        color: DesignTokens.brandColor.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.spacingSmall),
                // Sentences - English and Thai same size
                for (int i = 0; i < selectedSentences.length; i++) ...[
                  _buildHighlightedText(
                    text: selectedSentences[i],
                    highlightWords: isEnglish ? englishWords : [],
                    baseStyle: GoogleFonts.lexend(
                      fontSize: DesignTokens.fontSizeBodyLarge,
                      fontWeight: DesignTokens.weightSemiBold,
                      color: DesignTokens.textPrimary,
                      height: 1.4,
                      letterSpacing: isEnglish ? -0.2 : 0,
                    ),
                    highlightStyle: GoogleFonts.lexend(
                      fontSize: DesignTokens.fontSizeBodyLarge,
                      fontWeight: DesignTokens.weightBold,
                      color: DesignTokens.brandColor,
                      height: 1.4,
                      letterSpacing: isEnglish ? -0.2 : 0,
                      backgroundColor:
                          DesignTokens.brandColor.withValues(alpha: 0.15),
                    ),
                  ),
                  if (i < selectedSentences.length - 1)
                    const SizedBox(height: DesignTokens.spacingSmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVocabularyWords() {
    if (widget.vocabularyWords.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        left: DesignTokens.spacingLarge,
        right: DesignTokens.spacingLarge,
        bottom: DesignTokens.spacingXXLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: DesignTokens.spacingSmall,
            runSpacing: DesignTokens.spacingSmall,
            children: widget.vocabularyWords.map((vocab) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingMedium,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      vocab.word,
                      style: GoogleFonts.lexend(
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: DesignTokens.weightBold,
                        color: const Color(0xFF5B3CC4),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacingSmall),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: Color(0xFFA89DBF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacingSmall),
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
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Positioned(
      bottom: DesignTokens.spacingSmall,
      left: DesignTokens.spacingMedium,
      right: DesignTokens.spacingMedium,
      child: Container(
        key: _toolbarKey,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: DesignTokens.blackWithOpacity(0.14),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacingSmall,
              vertical: DesignTokens.spacingSmall,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildToolbarItem(
                    icon: Icons.text_fields_rounded,
                    label: 'Text',
                    index: 0,
                    onTap: _addText,
                  ),
                ),
                Expanded(
                  child: _buildToolbarItem(
                    icon: Icons.emoji_emotions_outlined,
                    label: 'Sticker',
                    index: 1,
                    onTap: _showStickerPicker,
                  ),
                ),
                Expanded(
                  child: _buildToolbarItem(
                    icon: Icons.photo_library_rounded,
                    label: 'Photo',
                    index: 2,
                    onTap: _pickNewPhoto,
                  ),
                ),
                Expanded(
                  child: _buildToolbarItem(
                    icon: Icons.format_color_fill_rounded,
                    label: 'Color',
                    index: 3,
                    onTap: _showBackgroundColorPicker,
                  ),
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

    return Semantics(
      button: true,
      label: '$label tool',
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
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
          curve: DesignTokens.curveEaseOutQuart,
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacingBase,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEDE9FE) : Colors.transparent,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? DesignTokens.brandColor
                    : DesignTokens.textSecondary,
                size: 22,
              ),
              const SizedBox(height: DesignTokens.spacingBase),
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
    // Create a temporary overlay with default values (no background)
    final tempOverlay = ScrapbookTextOverlay(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: '',
      x: 0.5,
      y: 0.5,
      backgroundColor: null, // No background by default
    );

    // Add the overlay immediately
    setState(() {
      _textOverlays.add(tempOverlay);
      _bringElementToFront(tempOverlay.id, 'text');
    });

    // Show the text edit sheet for this new overlay
    _showTextEditSheet(tempOverlay);
  }

  void _editText(ScrapbookTextOverlay overlay) {
    _showTextEditSheet(overlay);
  }

  void _showTextEditSheet(ScrapbookTextOverlay overlay) {
    final controller = TextEditingController(text: overlay.text);
    int? selectedBackgroundColor = overlay.backgroundColor;
    int selectedTextColor = overlay.color;
    String selectedFont = overlay.fontFamily;

    // Track which tool is selected (default: 'font')
    String selectedTool = 'font'; // 'font', 'textColor', 'bgColor'

    // Focus node for the text field
    final focusNode = FocusNode();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: DesignTokens.surfacePrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DesignTokens.radiusCircular),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(
                      top: DesignTokens.spacingMedium,
                      bottom: DesignTokens.spacingSmall,
                    ),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Text input area
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacingLarge,
                    vertical: DesignTokens.spacingMedium,
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Enter text...',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusMedium),
                      ),
                      contentPadding: const EdgeInsets.all(
                        DesignTokens.spacingMedium,
                      ),
                    ),
                    autofocus: true,
                    maxLines: null,
                    maxLength: 200,
                    style: TextStyle(
                      color: DesignTokens.textPrimary,
                      fontSize: 18,
                      fontFamily: selectedFont,
                    ),
                    onChanged: (value) {
                      // Auto-save on change
                      if (!mounted) return;
                      setState(() {
                        final index =
                            _textOverlays.indexWhere((o) => o.id == overlay.id);
                        if (index != -1) {
                          _textOverlays[index] = _textOverlays[index].copyWith(
                            text: value,
                            color: selectedTextColor,
                            fontFamily: selectedFont,
                            backgroundColor: selectedBackgroundColor,
                          );
                        }
                      });
                    },
                  ),
                ),

                // Divider
                const Divider(height: 1),

                // Options row (based on selected tool)
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacingMedium,
                    vertical: DesignTokens.spacingSmall,
                  ),
                  child: _buildOptionsRow(
                    selectedTool: selectedTool,
                    selectedFont: selectedFont,
                    selectedTextColor: selectedTextColor,
                    selectedBackgroundColor: selectedBackgroundColor,
                    onFontChanged: (font) {
                      setModalState(() {
                        selectedFont = font;
                      });
                      if (!mounted) return;
                      setState(() {
                        final index =
                            _textOverlays.indexWhere((o) => o.id == overlay.id);
                        if (index != -1) {
                          _textOverlays[index] = _textOverlays[index].copyWith(
                            fontFamily: font,
                          );
                        }
                      });
                      HapticFeedback.lightImpact();
                    },
                    onTextColorChanged: (color) {
                      setModalState(() {
                        selectedTextColor = color;
                      });
                      if (!mounted) return;
                      setState(() {
                        final index =
                            _textOverlays.indexWhere((o) => o.id == overlay.id);
                        if (index != -1) {
                          _textOverlays[index] = _textOverlays[index].copyWith(
                            color: color,
                          );
                        }
                      });
                      HapticFeedback.lightImpact();
                    },
                    onBgColorChanged: (color) {
                      setModalState(() {
                        selectedBackgroundColor = color;
                      });
                      if (!mounted) return;
                      setState(() {
                        final index =
                            _textOverlays.indexWhere((o) => o.id == overlay.id);
                        if (index != -1) {
                          _textOverlays[index] = _textOverlays[index].copyWith(
                            backgroundColor: color,
                          );
                        }
                      });
                      HapticFeedback.lightImpact();
                    },
                  ),
                ),

                // Tool selector row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacingMedium,
                    vertical: DesignTokens.spacingSmall,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildToolButton(
                        icon: Icons.text_fields,
                        iconColor: DesignTokens.textSecondary,
                        isSelected: selectedTool == 'font',
                        onTap: () {
                          setModalState(() {
                            selectedTool = 'font';
                          });
                        },
                      ),
                      const SizedBox(width: DesignTokens.spacingSmall),
                      _buildToolButton(
                        icon: Icons.color_lens,
                        iconColor: DesignTokens.textSecondary,
                        isSelected: selectedTool == 'textColor',
                        onTap: () {
                          setModalState(() {
                            selectedTool = 'textColor';
                          });
                        },
                      ),
                      const SizedBox(width: DesignTokens.spacingSmall),
                      _buildToolButton(
                        icon: Icons.format_color_fill,
                        iconColor: DesignTokens.textSecondary,
                        isSelected: selectedTool == 'bgColor',
                        onTap: () {
                          setModalState(() {
                            selectedTool = 'bgColor';
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Keyboard padding
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      focusNode.dispose();
      controller.dispose();

      // If text is still empty, remove the overlay (user cancelled without typing)
      final index = _textOverlays.indexWhere((o) => o.id == overlay.id);
      if (index != -1 && _textOverlays[index].text.isEmpty) {
        setState(() {
          _textOverlays.removeAt(index);
        });
      }
    });
  }

  // Build options row based on selected tool
  Widget _buildOptionsRow({
    required String selectedTool,
    required String selectedFont,
    required int selectedTextColor,
    required int? selectedBackgroundColor,
    required Function(String) onFontChanged,
    required Function(int) onTextColorChanged,
    required Function(int?) onBgColorChanged,
  }) {
    switch (selectedTool) {
      case 'font':
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _availableFonts.map((font) {
              final isSelected = selectedFont == font['family'];
              return GestureDetector(
                onTap: () => onFontChanged(font['family']),
                child: Container(
                  margin:
                      const EdgeInsets.only(right: DesignTokens.spacingSmall),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacingMedium,
                    vertical: DesignTokens.spacingSmall,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF9C27B0).withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusMedium),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF9C27B0).withValues(alpha: 0.4)
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    font['name'],
                    style: _getFontStyle(font['family']).copyWith(
                      fontSize: DesignTokens.fontSizeSmall,
                      fontWeight: DesignTokens.weightSemiBold,
                      color: isSelected
                          ? const Color(0xFF7B1FA2)
                          : DesignTokens.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

      case 'textColor':
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildColorWheelButton(
                label: 'Choose custom text color',
                onTap: () async {
                  final color = await _showColorWheelPicker(
                    title: 'Text Color',
                    initialColor: Color(selectedTextColor),
                  );
                  if (color != null) onTextColorChanged(color);
                },
              ),
              ..._textColorOptions.map((option) {
                final color = option['color'] as int;
                final isSelected = selectedTextColor == color;
                return GestureDetector(
                  onTap: () => onTextColorChanged(color),
                  child: Container(
                    margin: const EdgeInsets.only(
                      right: DesignTokens.spacingSmall,
                    ),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(color),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMedium),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF9C27B0)
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF9C27B0)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }),
            ],
          ),
        );

      case 'bgColor':
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildColorWheelButton(
                label: 'Choose custom text background color',
                onTap: () async {
                  final color = await _showColorWheelPicker(
                    title: 'Text Background',
                    initialColor: Color(
                      selectedBackgroundColor ?? 0xFFFFFFFF,
                    ),
                  );
                  if (color != null) onBgColorChanged(color);
                },
              ),
              ..._textBackgroundOptions.map((option) {
                final color = option['color'] as int?;
                final isSelected = selectedBackgroundColor == color;
                return GestureDetector(
                  onTap: () => onBgColorChanged(color),
                  child: Container(
                    margin: const EdgeInsets.only(
                      right: DesignTokens.spacingSmall,
                    ),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color != null ? Color(color) : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusMedium),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF9C27B0)
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF9C27B0)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: color == null
                        ? Icon(Icons.close,
                            size: 18, color: Colors.grey.shade600)
                        : isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                  ),
                );
              }),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildColorWheelButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(right: DesignTokens.spacingSmall),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFFF3B30),
                Color(0xFFFFCC00),
                Color(0xFF34C759),
                Color(0xFF00C7BE),
                Color(0xFF007AFF),
                Color(0xFFAF52DE),
                Color(0xFFFF3B30),
              ],
            ),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.colorize_rounded,
            size: 18,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  Future<int?> _showColorWheelPicker({
    required String title,
    required Color initialColor,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    var selectedColor = initialColor;

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.spacingSmall,
            DesignTokens.spacingBase,
            DesignTokens.spacingSmall,
            DesignTokens.spacingXLarge,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF242424),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(DesignTokens.radiusLarge),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFD7D7D7),
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: DesignTokens.weightMedium,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Apply color',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(
                        sheetContext,
                        selectedColor.toARGB32(),
                      );
                    },
                    icon: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFFD7D7D7),
                      size: 22,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingXXLarge,
                ),
                child: _ColorWheelPicker(
                  initialColor: initialColor,
                  onChanged: (color) {
                    setSheetState(() => selectedColor = color);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build tool selector button
  Widget _buildToolButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9C27B0).withValues(alpha: 0.5)
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium - 1),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF9C27B0).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius:
                    BorderRadius.circular(DesignTokens.radiusMedium - 1),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? const Color(0xFF7B1FA2) : iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingMedium,
          vertical: DesignTokens.spacingSmall,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: DesignTokens.textSecondary),
            const SizedBox(width: DesignTokens.spacingSmall),
            Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.fontSizeSmall,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to build option row with label
  Widget _buildOptionRow({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.lexend(
            fontSize: DesignTokens.fontSizeSmall,
            fontWeight: DesignTokens.weightSemiBold,
            color: DesignTokens.textSecondary,
          ),
        ),
        const SizedBox(height: DesignTokens.spacingSmall),
        child,
      ],
    );
  }

  // Available fonts for text selection
  static const List<Map<String, dynamic>> _availableFonts = [
    {'name': 'Lexend', 'family': 'Lexend'},
    {'name': 'Roboto', 'family': 'Roboto'},
    {'name': 'Pacifico', 'family': 'Pacifico'},
    {'name': 'Dancing', 'family': 'Dancing Script'},
    {'name': 'Satisfy', 'family': 'Satisfy'},
  ];

  // Text color options
  static const List<Map<String, dynamic>> _textColorOptions = [
    {'color': 0xFF000000, 'name': 'Black'},
    {'color': 0xFFFFFFFF, 'name': 'White'},
    {'color': 0xFFEF4444, 'name': 'Red'},
    {'color': 0xFFF59E0B, 'name': 'Orange'},
    {'color': 0xFF10B981, 'name': 'Green'},
    {'color': 0xFF3B82F6, 'name': 'Blue'},
    {'color': 0xFF8B5CF6, 'name': 'Purple'},
    {'color': 0xFFEC4899, 'name': 'Pink'},
  ];

  // Background color options (including transparent)
  static const List<Map<String, dynamic>> _textBackgroundOptions = [
    {'color': null, 'name': 'None'},
    ..._textColorOptions,
  ];

  void _showFontPicker(
      ScrapbookTextOverlay overlay, Function(String) onFontSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
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
                    'Select Font',
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
            const Divider(height: 1),
            // Font list
            Expanded(
              child: ListView.builder(
                itemCount: _availableFonts.length,
                itemBuilder: (context, index) {
                  final font = _availableFonts[index];
                  final isSelected = overlay.fontFamily == font['family'];

                  return ListTile(
                    onTap: () {
                      onFontSelected(font['family']);
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                    title: Text(
                      font['name'],
                      style: GoogleFonts.lexend(
                        fontSize: DesignTokens.fontSizeBody,
                        fontWeight: DesignTokens.weightMedium,
                      ),
                    ),
                    subtitle: Text(
                      'Sample',
                      style: _getFontStyle(font['family']),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check,
                            color: DesignTokens.brandColor)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextColorPicker(
      ScrapbookTextOverlay overlay, Function(int) onColorSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
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
              'Text Color',
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.fontSizeTitle,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingMedium),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final color = await _showColorWheelPicker(
                    title: 'Text Color',
                    initialColor: Color(overlay.color),
                  );
                  if (color == null || !mounted) return;
                  onColorSelected(color);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFFFF3B30),
                        Color(0xFFFFCC00),
                        Color(0xFF34C759),
                        Color(0xFF007AFF),
                        Color(0xFFAF52DE),
                        Color(0xFFFF3B30),
                      ],
                    ),
                  ),
                ),
                label: const Text('Choose from color wheel'),
              ),
            ),
            const SizedBox(height: DesignTokens.spacingMedium),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1,
                ),
                itemCount: _textColorOptions.length,
                itemBuilder: (context, index) {
                  final option = _textColorOptions[index];
                  final color = option['color'] as int;
                  final isSelected = overlay.color == color;

                  return GestureDetector(
                    onTap: () {
                      onColorSelected(color);
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      margin: const EdgeInsets.all(DesignTokens.spacingBase),
                      decoration: BoxDecoration(
                        color: Color(color),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusMedium),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextBackgroundPicker(
      ScrapbookTextOverlay overlay, Function(int?) onColorSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
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
                  crossAxisCount: 4,
                  childAspectRatio: 1,
                ),
                itemCount: _textBackgroundOptions.length,
                itemBuilder: (context, index) {
                  final option = _textBackgroundOptions[index];
                  final color = option['color'] as int?;
                  final isSelected = overlay.backgroundColor == color;

                  return GestureDetector(
                    onTap: () {
                      onColorSelected(color);
                      Navigator.pop(context);
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      margin: const EdgeInsets.all(DesignTokens.spacingBase),
                      decoration: BoxDecoration(
                        color:
                            color != null ? Color(color) : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusMedium),
                        border: Border.all(
                          color: isSelected
                              ? DesignTokens.brandColor
                              : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: color == null
                          ? const Icon(
                              Icons.close,
                              color: Colors.grey,
                              size: 20,
                            )
                          : isSelected
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

  // Helper to get TextStyle from font family name
  TextStyle _getFontStyle(String fontFamily) {
    switch (fontFamily) {
      case 'Lexend':
        return GoogleFonts.lexend();
      case 'Roboto':
        return GoogleFonts.roboto();
      case 'Pacifico':
        return GoogleFonts.pacifico();
      case 'Dancing Script':
        return GoogleFonts.dancingScript();
      case 'Satisfy':
        return GoogleFonts.satisfy();
      default:
        return GoogleFonts.lexend();
    }
  }

  Widget _buildColorPickerButton({
    required int color,
    required String label,
    bool isTransparent = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spacingMedium,
          vertical: DesignTokens.spacingSmall,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTransparent)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(color),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
              ),
            const SizedBox(width: DesignTokens.spacingSmall),
            Text(
              label,
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.fontSizeSmall,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStickerPicker() {
    _selectedStickerSetId ??= stickerSets.first.id;
    var selectedSetId = _selectedStickerSetId!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final selectedSet = stickerSets.firstWhere(
            (set) => set.id == selectedSetId,
          );

          return Container(
            height: MediaQuery.sizeOf(context).height * 0.78,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF9F8FC),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(DesignTokens.radiusXLarge),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: DesignTokens.spacingMedium),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1CED8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.spacingXLarge,
                    DesignTokens.spacingLarge,
                    DesignTokens.spacingMedium,
                    DesignTokens.spacingMedium,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add a sticker',
                          style: GoogleFonts.lexend(
                            fontSize: DesignTokens.fontSizeTitle,
                            fontWeight: DesignTokens.weightBold,
                            color: DesignTokens.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close sticker picker',
                        icon: const Icon(Icons.close_rounded),
                        color: DesignTokens.textSecondary,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacingXLarge,
                    ),
                    itemCount: stickerSets.length,
                    itemBuilder: (context, index) {
                      final set = stickerSets[index];
                      final isSelected = selectedSetId == set.id;

                      return Padding(
                        padding: const EdgeInsets.only(
                          right: DesignTokens.spacingSmall,
                        ),
                        child: Semantics(
                          button: true,
                          selected: isSelected,
                          label: '${set.name} sticker pack',
                          child: InkWell(
                            key: ValueKey('sticker-pack-${set.id}'),
                            borderRadius: BorderRadius.circular(
                              DesignTokens.radiusMedium,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                selectedSetId = set.id;
                              });
                              setState(() => _selectedStickerSetId = set.id);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(
                                milliseconds: DesignTokens.durationFast,
                              ),
                              curve: DesignTokens.curveEaseOut,
                              width: 56,
                              height: 56,
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFEDE9FE)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  DesignTokens.radiusMedium,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? DesignTokens.brandColor
                                      : Colors.transparent,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Image.asset(
                                getStickerAsset(set.id, 0),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.emoji_emotions_outlined,
                                  color: DesignTokens.textMuted,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: DesignTokens.spacingMedium),
                const Divider(height: 1, color: Color(0xFFE7E5EB)),
                Expanded(
                  child: _buildStickerGrid(selectedSet),
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
      return Semantics(
        label: '${set.name} sticker pack is locked',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingXLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDE9FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 28,
                    color: DesignTokens.brandColor,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacingLarge),
                Text(
                  'This sticker pack is locked',
                  style: GoogleFonts.lexend(
                    fontSize: DesignTokens.fontSizeTitle,
                    fontWeight: DesignTokens.weightSemiBold,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacingSmall),
                Text(
                  'Keep your learning streak for ${set.requiredStreakDays ?? 0} days to unlock this pack.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: DesignTokens.fontSizeBody,
                    color: DesignTokens.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scrollbar(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.spacingXLarge,
          DesignTokens.spacingLarge,
          DesignTokens.spacingXLarge,
          DesignTokens.spacingXXLarge,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 112,
          childAspectRatio: 1,
          mainAxisSpacing: DesignTokens.spacingMedium,
          crossAxisSpacing: DesignTokens.spacingMedium,
        ),
        itemCount: set.count,
        itemBuilder: (context, index) {
          final assetPath = getStickerAsset(set.id, index);

          return Semantics(
            button: true,
            label: '${set.name} sticker ${index + 1}',
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  setState(() {
                    final stickerId =
                        DateTime.now().microsecondsSinceEpoch.toString();
                    _stickers.add(ScrapbookSticker(
                      id: stickerId,
                      emoji: assetPath,
                      x: 0.5,
                      y: 0.5,
                    ));
                    _bringElementToFront(stickerId, 'sticker');
                  });
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 28,
                          color: DesignTokens.textMuted,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Copy image to app's permanent storage directory
  /// Returns the permanent path where the image was copied
  /// Throws exception if copy fails
  Future<String> _copyImageToPermanentStorage(
      String sourcePath, String scrapbookId) async {
    // Get app's document directory
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String scrapbookDir = '${appDir.path}/scrapbooks/$scrapbookId';

    // Create directory if it doesn't exist
    await Directory(scrapbookDir).create(recursive: true);

    // Generate unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path_pkg.extension(sourcePath);
    final filename = 'additional_$timestamp$extension';
    final String newPath = '$scrapbookDir/$filename';

    try {
      // Copy the file
      final File sourceFile = File(sourcePath);
      final File newFile = await sourceFile.copy(newPath);

      // Ensure the file is fully written to disk
      // by reading it back to verify it exists
      await newFile.length();

      // Small delay to ensure OS has flushed the file to disk
      await Future.delayed(const Duration(milliseconds: 50));

      print('✅ Image copied to permanent storage: $newPath');
      return newPath;
    } catch (e) {
      // Clean up partial file if it exists
      try {
        final file = File(newPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      print('❌ Failed to copy image to permanent storage: $e');
      // Re-throw so caller knows the operation failed
      throw Exception('Failed to copy image: $e');
    }
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
        try {
          // Copy image to permanent storage before adding
          final permanentPath = await _copyImageToPermanentStorage(
              image.path, _permanentScrapbookId);

          setState(() {
            // Position photo at center of canvas
            // x and y are normalized coordinates (0.0 to 1.0)
            final photoId = DateTime.now().millisecondsSinceEpoch.toString();
            _additionalPhotos.add(ScrapbookPhoto(
              id: photoId,
              imagePath: permanentPath,
              x: 0.5, // Center horizontally
              y: 0.5, // Center vertically
              width: 0.25, // 25% of canvas width
              height: 0.25, // 25% of canvas height
            ));
            _bringElementToFront(photoId, 'photo');
          });
        } catch (e) {
          // Failed to copy - show error to user
          if (mounted) {
            _showErrorDialog('Error', 'Failed to save photo: ${e.toString()}');
          }
        }
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to pick image: ${e.toString()}');
    }
  }

  void _showBackgroundColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AnimatedContainer(
        duration: const Duration(milliseconds: DesignTokens.durationMedium),
        curve: DesignTokens.curveEaseOutQuart,
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
              'Polaroid Color',
              style: GoogleFonts.lexend(
                fontSize: DesignTokens.fontSizeTitle,
                fontWeight: DesignTokens.weightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingMedium),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final color = await _showColorWheelPicker(
                    title: 'Polaroid Color',
                    initialColor: Color(_backgroundColor),
                  );
                  if (color == null || !mounted) return;
                  setState(() => _backgroundColor = color);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFFFF3B30),
                        Color(0xFFFFCC00),
                        Color(0xFF34C759),
                        Color(0xFF007AFF),
                        Color(0xFFAF52DE),
                        Color(0xFFFF3B30),
                      ],
                    ),
                  ),
                ),
                label: const Text('Choose from color wheel'),
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
        id: _permanentScrapbookId,
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
        elementLayerOrder: _elementLayerOrder,
        createdAt: existingScrapbook?.createdAt ?? _generatedTime,
        updatedAt: DateTime.now().toUtc(),
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

  // Check if position is on left center handle
  bool _isOnLeftCenterHandle(Offset localPosition, Size itemSize) {
    const handleSize = 32.0;
    const offset = 12.0;
    const touchPadding = 4.0;
    final totalHandleSize = handleSize + (touchPadding * 2);
    final handleOffset = offset + touchPadding;

    final leftCenterHandle = Rect.fromCircle(
      center: Offset(-handleOffset, itemSize.height / 2),
      radius: totalHandleSize / 2,
    );
    return leftCenterHandle.contains(localPosition);
  }

  // Check if position is on right center handle
  bool _isOnRightCenterHandle(Offset localPosition, Size itemSize) {
    const handleSize = 32.0;
    const offset = 12.0;
    const touchPadding = 4.0;
    final totalHandleSize = handleSize + (touchPadding * 2);
    final handleOffset = offset + touchPadding;

    final rightCenterHandle = Rect.fromCircle(
      center: Offset(itemSize.width + handleOffset, itemSize.height / 2),
      radius: totalHandleSize / 2,
    );
    return rightCenterHandle.contains(localPosition);
  }

  // Check if a local position is on any control handle
  bool _isOnControlHandle(Offset localPosition, Size itemSize,
      {String type = 'text'}) {
    const handleSize = 32.0;
    const offset = 12.0;
    const touchPadding = 4.0;
    final totalHandleSize = handleSize + (touchPadding * 2);
    final handleOffset = offset + touchPadding;

    // Top-left (delete button) - always present
    final topLeftHandle = Rect.fromCircle(
      center: Offset(-handleOffset, -handleOffset),
      radius: totalHandleSize / 2,
    );
    if (topLeftHandle.contains(localPosition)) return true;

    // For text, check left and right center handles
    if (type == 'text') {
      // Left center handle (horizontal resize)
      final leftCenterHandle = Rect.fromCircle(
        center: Offset(-handleOffset, itemSize.height / 2),
        radius: totalHandleSize / 2,
      );
      if (leftCenterHandle.contains(localPosition)) return true;

      // Right center handle (horizontal resize)
      final rightCenterHandle = Rect.fromCircle(
        center: Offset(itemSize.width + handleOffset, itemSize.height / 2),
        radius: totalHandleSize / 2,
      );
      if (rightCenterHandle.contains(localPosition)) return true;
    }

    // For stickers and photos, check all 4 corners
    if (type != 'text') {
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
    }

    // Bottom-right (resize/rotate handle) - always present
    final bottomRightHandle = Rect.fromCircle(
      center:
          Offset(itemSize.width + handleOffset, itemSize.height + handleOffset),
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
  void _handleResizeRotateUpdate(
      Offset globalPosition, String itemId, String type) {
    if (_resizeStartPos == null ||
        _initialScale == null ||
        _initialRotation == null) return;

    // Calculate distance change for scale
    final currentDist = (globalPosition -
            (_canvasSize == null
                ? Offset.zero
                : Offset(_canvasSize!.width / 2, _canvasSize!.height / 2)))
        .distance;
    final initialDist = (_resizeStartPos! -
            (_canvasSize == null
                ? Offset.zero
                : Offset(_canvasSize!.width / 2, _canvasSize!.height / 2)))
        .distance;
    final scaleFactor = currentDist / initialDist;
    final newScale = (_initialScale! * scaleFactor).clamp(0.5, 3.0);

    // Calculate rotation change
    final currentAngle = _calculateAngle(
      globalPosition,
      _canvasSize == null
          ? Offset.zero
          : Offset(_canvasSize!.width / 2, _canvasSize!.height / 2),
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
            width:
                (_additionalPhotos[index].width * scaleFactor).clamp(0.1, 0.8),
            height:
                (_additionalPhotos[index].height * scaleFactor).clamp(0.1, 0.8),
            rotation: newRotation,
          );
        }
      }
    });
  }

  // Handle horizontal resize from left/right handles
  void _handleHorizontalResizeUpdate(
      Offset currentPosition, String itemId, String handle) {
    if (_resizeStartPos == null || _initialWidth == null || _canvasSize == null)
      return;

    // Calculate horizontal distance change
    final deltaX = currentPosition.dx - _resizeStartPos!.dx;

    // For left handle, dragging left increases width, dragging right decreases
    // For right handle, dragging right increases width, dragging left decreases
    final widthChange = handle == 'right' ? deltaX : -deltaX;

    // Convert pixel change to normalized width change
    final normalizedChange = widthChange / _canvasSize!.width;
    final newWidth = (_initialWidth! + normalizedChange).clamp(0.05, 0.8);

    setState(() {
      final index = _textOverlays.indexWhere((o) => o.id == itemId);
      if (index != -1) {
        _textOverlays[index] = _textOverlays[index].copyWith(
          width: newWidth,
        );
      }
    });
  }

  // Build control handles for selected elements
  void _startOverlayResize(
      DragStartDetails details, String itemId, String type) {
    if (_canvasSize == null) return;

    late final Size itemSize;
    late final double rotation;

    if (type == 'text') {
      final item = _textOverlays.firstWhere((item) => item.id == itemId);
      final width = item.width != null
          ? item.width! * _canvasSize!.width
          : 100.0 * item.scale;
      itemSize = Size(width, 50.0 * item.scale);
      _initialScale = item.scale;
      _initialWidth = item.width;
      rotation = item.rotation;
    } else if (type == 'sticker') {
      final item = _stickers.firstWhere((item) => item.id == itemId);
      final size = 100.0 * item.scale;
      itemSize = Size.square(size);
      _initialScale = item.scale;
      rotation = item.rotation;
    } else {
      final item = _additionalPhotos.firstWhere((item) => item.id == itemId);
      itemSize = Size(
        item.width * _canvasSize!.width,
        item.height * _canvasSize!.height,
      );
      _initialScale = 1.0;
      _initialPhotoSize = Size(item.width, item.height);
      rotation = item.rotation;
    }

    // The drag detector is a 36 px square centred on the frame corner.
    // Recover the item's global centre from the exact point the finger hit.
    const targetCenter = Offset(18, 18);
    final vectorFromCenter = (details.localPosition - targetCenter) +
        Offset(itemSize.width / 2, itemSize.height / 2);
    final cosine = math.cos(rotation);
    final sine = math.sin(rotation);
    final rotatedVector = Offset(
      (vectorFromCenter.dx * cosine) - (vectorFromCenter.dy * sine),
      (vectorFromCenter.dx * sine) + (vectorFromCenter.dy * cosine),
    );

    _resizeCenterGlobal = details.globalPosition - rotatedVector;
    _resizeStartPos = details.globalPosition;
    _initialRotation = rotation;
    _initialAngle = (details.globalPosition - _resizeCenterGlobal!).direction;
    _resizingId = itemId;
    _resizingType = type;
  }

  void _updateOverlayResize(
      DragUpdateDetails details, String itemId, String type) {
    if (_resizeCenterGlobal == null ||
        _resizeStartPos == null ||
        _initialScale == null ||
        _initialRotation == null ||
        _initialAngle == null) return;

    final initialDistance = (_resizeStartPos! - _resizeCenterGlobal!).distance;
    if (initialDistance == 0) return;

    final currentVector = details.globalPosition - _resizeCenterGlobal!;
    final scaleFactor = currentVector.distance / initialDistance;
    final rotation =
        _initialRotation! + currentVector.direction - _initialAngle!;

    setState(() {
      if (type == 'text') {
        final index = _textOverlays.indexWhere((item) => item.id == itemId);
        if (index != -1) {
          _textOverlays[index] = _textOverlays[index].copyWith(
            scale: (_initialScale! * scaleFactor).clamp(0.5, 3.0),
            width: _initialWidth == null
                ? null
                : (_initialWidth! * scaleFactor).clamp(0.05, 0.8),
            rotation: rotation,
          );
        }
      } else if (type == 'sticker') {
        final index = _stickers.indexWhere((item) => item.id == itemId);
        if (index != -1) {
          _stickers[index] = _stickers[index].copyWith(
            scale: (_initialScale! * scaleFactor).clamp(0.5, 3.0),
            rotation: rotation,
          );
        }
      } else if (_initialPhotoSize != null) {
        final index = _additionalPhotos.indexWhere((item) => item.id == itemId);
        if (index != -1) {
          _additionalPhotos[index] = _additionalPhotos[index].copyWith(
            width: (_initialPhotoSize!.width * scaleFactor).clamp(0.1, 0.8),
            height: (_initialPhotoSize!.height * scaleFactor).clamp(0.1, 0.8),
            rotation: rotation,
          );
        }
      }
    });
  }

  void _endOverlayResize() {
    _resizingId = null;
    _resizingType = null;
    _resizingHandle = null;
    _resizeStartPos = null;
    _resizeCenterGlobal = null;
    _initialScale = null;
    _initialRotation = null;
    _initialAngle = null;
    _initialPhotoSize = null;
    _initialWidth = null;
  }

  Widget _buildSelectedControlOverlay() {
    if (_canvasSize == null || _selectedId == null || _selectedType == null) {
      return const SizedBox.shrink();
    }

    late final Offset center;
    late final Size itemSize;
    late final double rotation;
    late final bool isFlipped;

    if (_selectedType == 'text') {
      final index = _textOverlays.indexWhere((item) => item.id == _selectedId);
      if (index == -1) return const SizedBox.shrink();
      final item = _textOverlays[index];
      center = Offset(
        _touchSandbox + (item.x * _canvasSize!.width),
        _touchSandbox + (item.y * _canvasSize!.height),
      );
      final baseHeight = 50.0;
      final baseWidth = item.width != null
          ? item.width! * _canvasSize!.width
          : 100.0 * item.scale;
      itemSize = Size(baseWidth, baseHeight * item.scale);
      rotation = item.rotation;
      isFlipped = item.flip;
    } else if (_selectedType == 'sticker') {
      final index = _stickers.indexWhere((item) => item.id == _selectedId);
      if (index == -1) return const SizedBox.shrink();
      final item = _stickers[index];
      center = Offset(
        _touchSandbox + (item.x * _canvasSize!.width),
        _touchSandbox + (item.y * _canvasSize!.height),
      );
      final size = 100.0 * item.scale;
      itemSize = Size.square(size);
      rotation = item.rotation;
      isFlipped = item.flip;
    } else if (_selectedType == 'photo') {
      final index =
          _additionalPhotos.indexWhere((item) => item.id == _selectedId);
      if (index == -1) return const SizedBox.shrink();
      final item = _additionalPhotos[index];
      center = Offset(
        _touchSandbox + (item.x * _canvasSize!.width),
        _touchSandbox + (item.y * _canvasSize!.height),
      );
      itemSize = Size(
        item.width * _canvasSize!.width,
        item.height * _canvasSize!.height,
      );
      rotation = item.rotation;
      isFlipped = item.flip;
    } else {
      return const SizedBox.shrink();
    }

    // Half of the 48 px target on every side puts each target's centre
    // exactly on a frame corner while keeping the whole target in this layer.
    const targetRadius = 24.0;
    final paddedSize = Size(
      itemSize.width + (targetRadius * 2),
      itemSize.height + (targetRadius * 2),
    );

    // Give the overlay the axis-aligned bounds of its rotated child. This is
    // what prevents Flutter from rejecting taps at rotated outer corners.
    final cosine = math.cos(rotation).abs();
    final sine = math.sin(rotation).abs();
    final overlaySize = Size(
      (paddedSize.width * cosine) + (paddedSize.height * sine),
      (paddedSize.width * sine) + (paddedSize.height * cosine),
    );

    return Positioned(
      left: center.dx - (overlaySize.width / 2),
      top: center.dy - (overlaySize.height / 2),
      width: overlaySize.width,
      height: overlaySize.height,
      child: Center(
        child: Transform.rotate(
          angle: rotation,
          child: SizedBox(
            width: paddedSize.width,
            height: paddedSize.height,
            child: Stack(
              children: _buildControlHandles(
                _selectedId!,
                _selectedType!,
                isFlipped,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildControlHandles(
      String itemId, String type, bool isFlipped) {
    final handleSize = 24.0; // Medium handles
    // The overlay adds 24 px around the item. Inset each 36 px touch target
    // so its centre lands exactly on the corresponding frame corner.
    const invisibleTouchPadding = 6.0;
    const targetRadius = 24.0; // Padding around item in the overlay stack
    // Offset to center the handle on the border
    // For left/top: handle center should be at targetRadius from the edge
    // SizedBox width is handleSize + 2*invisibleTouchPadding = 36
    // Container center is at offset + 18, so offset = targetRadius - 18 = 6
    final handleOffset =
        targetRadius - invisibleTouchPadding - (handleSize / 2);

    // Build the list of handles - text has only 2, stickers/photos have 4
    final List<Widget> handles = [];

    // Delete button (top-left) - always present
    handles.add(
      Positioned(
        left: handleOffset,
        top: handleOffset,
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
          child: SizedBox(
            width: handleSize + (invisibleTouchPadding * 2),
            height: handleSize + (invisibleTouchPadding * 2),
            child: Center(
              child: Container(
                width: handleSize,
                height: handleSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444), // Red for delete
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Semantics(
                  button: true,
                  label: 'Delete element',
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Left center handle (horizontal resize) - only for text
    if (type == 'text') {
      handles.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 13),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                setState(() {
                  _resizingId = itemId;
                  _resizingType = 'text';
                  _resizingHandle = 'left';
                  _resizeStartPos = details.globalPosition;
                  final index = _textOverlays.indexWhere((o) => o.id == itemId);
                  if (index != -1) {
                    _initialWidth = _textOverlays[index].width ?? 0.1;
                  }
                });
              },
              onPanUpdate: (details) {
                if (_resizingId == itemId && _resizingHandle == 'left') {
                  _handleHorizontalResizeUpdate(
                    details.globalPosition,
                    itemId,
                    'left',
                  );
                }
              },
              onPanEnd: (_) {
                setState(() {
                  _resizingId = null;
                  _resizingType = null;
                  _resizingHandle = null;
                  _resizeStartPos = null;
                  _initialWidth = null;
                });
              },
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Right center handle (horizontal resize) - only for text
    if (type == 'text') {
      handles.add(
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 13),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                setState(() {
                  _resizingId = itemId;
                  _resizingType = 'text';
                  _resizingHandle = 'right';
                  _resizeStartPos = details.globalPosition;
                  final index = _textOverlays.indexWhere((o) => o.id == itemId);
                  if (index != -1) {
                    _initialWidth = _textOverlays[index].width ?? 0.1;
                  }
                });
              },
              onPanUpdate: (details) {
                if (_resizingId == itemId && _resizingHandle == 'right') {
                  _handleHorizontalResizeUpdate(
                    details.globalPosition,
                    itemId,
                    'right',
                  );
                }
              },
              onPanEnd: (_) {
                setState(() {
                  _resizingId = null;
                  _resizingType = null;
                  _resizingHandle = null;
                  _resizeStartPos = null;
                  _initialWidth = null;
                });
              },
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Duplicate button (top-right) - only for stickers and photos
    if (type != 'text') {
      handles.add(
        Positioned(
          right: handleOffset,
          top: handleOffset,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              // Prevent parent GestureDetector from handling this tap
            },
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                String? newElementId;

                if (type == 'sticker') {
                  final original = _stickers.firstWhere((s) => s.id == itemId);
                  newElementId =
                      DateTime.now().millisecondsSinceEpoch.toString();
                  _stickers.add(ScrapbookSticker(
                    id: newElementId,
                    emoji: original.emoji,
                    x: original.x + 0.05,
                    y: original.y + 0.05,
                    scale: original.scale,
                    rotation: original.rotation,
                    flip: original.flip,
                  ));
                } else if (type == 'photo') {
                  final original =
                      _additionalPhotos.firstWhere((p) => p.id == itemId);
                  newElementId =
                      DateTime.now().millisecondsSinceEpoch.toString();
                  _additionalPhotos.add(ScrapbookPhoto(
                    id: newElementId,
                    imagePath: original.imagePath,
                    x: original.x + 0.05,
                    y: original.y + 0.05,
                    width: original.width,
                    height: original.height,
                    rotation: original.rotation,
                    flip: original.flip,
                  ));
                }

                // Select the newly duplicated element
                if (newElementId != null) {
                  _bringElementToFront(newElementId, type);
                  _selectedId = newElementId;
                  _selectedType = type;
                }
              });
            },
            child: SizedBox(
              width: handleSize + (invisibleTouchPadding * 2),
              height: handleSize + (invisibleTouchPadding * 2),
              child: Center(
                child: Container(
                  width: handleSize,
                  height: handleSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Semantics(
                    button: true,
                    label: 'Duplicate element',
                    child: const Icon(
                      Icons.copy,
                      color: Colors.black54,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Flip button (bottom-left) - only for stickers and photos
    if (type != 'text') {
      handles.add(
        Positioned(
          left: handleOffset,
          bottom: handleOffset,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              // Prevent parent GestureDetector from handling this tap
            },
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (type == 'sticker') {
                  final index = _stickers.indexWhere((s) => s.id == itemId);
                  if (index != -1) {
                    _stickers[index] = _stickers[index].copyWith(
                      flip: !_stickers[index].flip,
                    );
                  }
                } else if (type == 'photo') {
                  final index =
                      _additionalPhotos.indexWhere((p) => p.id == itemId);
                  if (index != -1) {
                    _additionalPhotos[index] =
                        _additionalPhotos[index].copyWith(
                      flip: !_additionalPhotos[index].flip,
                    );
                  }
                }
              });
            },
            child: SizedBox(
              width: handleSize + (invisibleTouchPadding * 2),
              height: handleSize + (invisibleTouchPadding * 2),
              child: Center(
                child: Container(
                  width: handleSize,
                  height: handleSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Semantics(
                    button: true,
                    label: isFlipped ? 'Unflip element' : 'Flip element',
                    child: Icon(
                      isFlipped ? Icons.flip_rounded : Icons.flip_rounded,
                      color: Colors.black54,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Resize/Rotate handle (bottom-right) - always present
    handles.add(
      Positioned(
        right: handleOffset,
        bottom: handleOffset,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _startOverlayResize(details, itemId, type),
          onPanUpdate: (details) => _updateOverlayResize(details, itemId, type),
          onPanEnd: (_) => _endOverlayResize(),
          onTap: () {
            HapticFeedback.lightImpact();
          },
          child: SizedBox(
            width: handleSize + (invisibleTouchPadding * 2),
            height: handleSize + (invisibleTouchPadding * 2),
            child: Center(
              child: Container(
                width: handleSize,
                height: handleSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Semantics(
                  button: true,
                  label: 'Resize and rotate',
                  child: const Icon(
                    Icons.open_in_full,
                    color: Colors.black54,
                    size: 10,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return handles;
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

/// Reusable top bar button widget with pressed state feedback
class _TopBarButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_TopBarButton> createState() => _TopBarButtonState();
}

class _TopBarButtonState extends State<_TopBarButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: DesignTokens.durationFast,
          ),
          curve: DesignTokens.curveEaseOut,
          width: DesignTokens.iconButtonSize,
          height: DesignTokens.iconButtonSize,
          decoration: BoxDecoration(
            color: _isPressed
                ? const Color(0xFFEDE9FE)
                : Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: const Color(0xFFD8D3E8)),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: DesignTokens.durationFast),
            curve: DesignTokens.curveEaseOut,
            scale: _isPressed ? 0.95 : 1.0,
            child: Icon(
              widget.icon,
              color: DesignTokens.textPrimary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable save button with loading state and pressed feedback
class _SaveButton extends StatefulWidget {
  final bool isSaving;
  final VoidCallback? onTap;

  const _SaveButton({
    required this.isSaving,
    required this.onTap,
  });

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !widget.isSaving && widget.onTap != null;

    return Semantics(
      button: true,
      label: widget.isSaving ? 'Saving scrapbook' : 'Save scrapbook',
      enabled: isEnabled,
      child: GestureDetector(
        onTap: isEnabled ? widget.onTap : null,
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel:
            isEnabled ? () => setState(() => _isPressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: DesignTokens.durationFast,
          ),
          curve: DesignTokens.curveEaseOut,
          width: 78,
          height: DesignTokens.iconButtonSize,
          decoration: BoxDecoration(
            color: isEnabled
                ? _isPressed
                    ? const Color(0xFF7549E8)
                    : DesignTokens.brandColor
                : const Color(0xFFD1CBDD),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: DesignTokens.brandColor.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : AnimatedScale(
                    duration: const Duration(
                      milliseconds: DesignTokens.durationFast,
                    ),
                    curve: DesignTokens.curveEaseOut,
                    scale: _isPressed ? 0.97 : 1.0,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            size: 17, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: DesignTokens.weightSemiBold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ColorWheelPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;

  const _ColorWheelPicker({
    required this.initialColor,
    required this.onChanged,
  });

  @override
  State<_ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<_ColorWheelPicker> {
  late HSVColor _color;

  @override
  void initState() {
    super.initState();
    _color = HSVColor.fromColor(widget.initialColor);
  }

  void _updateSaturationAndValue(Offset position, Size size) {
    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - (position.dy / size.height)).clamp(0.0, 1.0);
    setState(() {
      _color = _color.withSaturation(saturation).withValue(value);
    });
    widget.onChanged(_color.toColor());
  }

  void _updateHue(double positionX, double width) {
    final hue = ((positionX / width).clamp(0.0, 1.0)) * 360;
    setState(() => _color = _color.withHue(hue));
    widget.onChanged(_color.toColor());
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Color spectrum and hue control',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final panelSize = Size(constraints.maxWidth, 92);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _updateSaturationAndValue(
                  details.localPosition,
                  panelSize,
                ),
                onPanStart: (details) => _updateSaturationAndValue(
                  details.localPosition,
                  panelSize,
                ),
                onPanUpdate: (details) => _updateSaturationAndValue(
                  details.localPosition,
                  panelSize,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radiusSmall,
                  ),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: panelSize,
                      painter: _SaturationValuePainter(color: _color),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: DesignTokens.spacingSmall),
          SizedBox(
            height: 40,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sliderSize = Size(constraints.maxWidth, 40);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _updateHue(details.localPosition.dx, sliderSize.width),
                  onPanStart: (details) =>
                      _updateHue(details.localPosition.dx, sliderSize.width),
                  onPanUpdate: (details) =>
                      _updateHue(details.localPosition.dx, sliderSize.width),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: sliderSize,
                      painter: _HueSliderPainter(hue: _color.hue),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  final HSVColor color;

  const _SaturationValuePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()..color = HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
          ],
        ).createShader(bounds),
    );

    final marker = Offset(
      color.saturation * size.width,
      (1 - color.value) * size.height,
    );
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..color = color.toColor()
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      marker,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HueSliderPainter extends CustomPainter {
  final double hue;

  const _HueSliderPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    const trackHeight = 14.0;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          0, (size.height - trackHeight) / 2, size.width, trackHeight),
      const Radius.circular(trackHeight / 2),
    );
    canvas.drawRRect(
      track,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ).createShader(track.outerRect),
    );

    final marker = Offset(
      (hue / 360) * size.width,
      size.height / 2,
    );
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor()
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      marker,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      marker,
      9.25,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _HueSliderPainter oldDelegate) =>
      oldDelegate.hue != hue;
}
