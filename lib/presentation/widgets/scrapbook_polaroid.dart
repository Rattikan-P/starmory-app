import 'dart:io';

import 'package:flutter/material.dart';

/// Polaroid proportions shared with the scrapbook editor.
///
/// The editor renders the frame at 1:1.2, reserves 18% of its height for the
/// writing area, and uses a border equal to roughly 5.6% of its width.
class ScrapbookPolaroid extends StatelessWidget {
  const ScrapbookPolaroid({
    super.key,
    required this.imagePath,
    required this.backgroundColor,
    this.onTap,
    this.semanticLabel,
    this.vocabularyCount,
    this.width = standardWidth,
  });

  static const double standardWidth = 154;
  static const double heightRatio = 1.2;
  static const double standardHeight = standardWidth * heightRatio;
  static const double listExtent = standardHeight + 14;
  static const double frameBorderRatio = 0.056;
  static const double bottomAreaRatio = 0.18;

  final String imagePath;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final int? vocabularyCount;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * heightRatio;
    final frameBorder = width * frameBorderRatio;
    final bottomArea = height * bottomAreaRatio;

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: backgroundColor,
          elevation: 2,
          borderRadius: BorderRadius.circular(16),
          shadowColor: Colors.black.withValues(alpha: 0.15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(frameBorder),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox.expand(child: _buildImage()),
                        ),
                      ),
                    ),
                    SizedBox(height: bottomArea),
                  ],
                ),
                if (vocabularyCount != null)
                  Positioned(
                    top: frameBorder + 6,
                    right: frameBorder + 6,
                    child: Semantics(
                      label: '$vocabularyCount stars collected in this memory',
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$vocabularyCount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    Widget errorBuilder(BuildContext context, Object error, StackTrace? stack) {
      return Container(
        color: const Color(0xFFE9E7EC),
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: Color(0xFF77717D),
        ),
      );
    }

    return imagePath.startsWith('http')
        ? Image.network(
            imagePath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: errorBuilder,
          )
        : Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: errorBuilder,
          );
  }
}
