import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../pages/image_preview_screen.dart';

/// Shared image-selection flow used wherever users can add a new photo.
class PhotoPickerFlow {
  PhotoPickerFlow._();

  static Future<void> showSourceSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFEFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6D1E8),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Add a photo', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF302858))),
              const SizedBox(height: 6),
              const Text('Choose where your new memory comes from', style: TextStyle(fontSize: 13, color: Color(0xFF6A6385))),
              const SizedBox(height: 22),
              _sourceOption(
                context: sheetContext,
                source: ImageSource.camera,
                icon: Icons.camera_alt_rounded,
                title: 'Take a photo',
                subtitle: 'Capture a new moment',
                colors: const [Color(0xFF79B8FF), Color(0xFF5E86E9)],
              ),
              const SizedBox(height: 12),
              _sourceOption(
                context: sheetContext,
                source: ImageSource.gallery,
                icon: Icons.photo_library_rounded,
                title: 'Choose from library',
                subtitle: 'Use a photo already on your device',
                colors: const [Color(0xFFB7A9FF), Color(0xFF8D79E6)],
              ),
            ],
          ),
        ),
      ),
    );

    if (source != null && context.mounted) {
      await pickAndPreview(context, source);
    }
  }

  static Widget _sourceOption({
    required BuildContext context,
    required ImageSource source,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, source),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F5FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1DBFF)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF39305F))),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF746D8D))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8276B8)),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> pickAndPreview(BuildContext context, ImageSource source) async {
    try {
      final permission = source == ImageSource.camera
          ? await Permission.camera.request()
          : await Permission.photos.request();
      if (!permission.isGranted) {
        if (context.mounted) _showPermissionDialog(context, source == ImageSource.camera ? 'Camera' : 'Photo Library');
        return;
      }

      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (image == null || !context.mounted) return;

      final imagePath = image.path.toLowerCase();
      if (imagePath.endsWith('.gif') || imagePath.endsWith('.webp') || image.mimeType == 'image/gif' || image.mimeType == 'image/webp') {
        _showErrorDialog(
          context,
          'Unsupported Format',
          'Only JPEG and PNG images are supported. Please select a different photo.',
        );
        return;
      }

      final permanentPath = await _saveImagePermanently(image.path);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ImagePreviewScreen(imagePath: permanentPath)),
      );
    } catch (error) {
      if (context.mounted) {
        _showErrorDialog(context, 'Error', 'Failed to pick image: $error');
      }
    }
  }

  static Future<String> _saveImagePermanently(String sourcePath) async {
    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      final vocabularyDirectory = Directory('${appDirectory.path}/vocabulary_images');
      if (!await vocabularyDirectory.exists()) await vocabularyDirectory.create(recursive: true);
      final fileName = 'vocab_${DateTime.now().millisecondsSinceEpoch}${path.extension(sourcePath)}';
      final targetPath = '${vocabularyDirectory.path}/$fileName';
      await File(sourcePath).copy(targetPath);
      return targetPath;
    } catch (_) {
      return sourcePath;
    }
  }

  static void _showPermissionDialog(BuildContext context, String type) {
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
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF9ca3af)),
            child: Text('Cancel', style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF8b5cf6)),
            child: Text('Settings', style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  static void _showErrorDialog(BuildContext context, String title, String message) {
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
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF8b5cf6)),
            child: Text('OK', style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
