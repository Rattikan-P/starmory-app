import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Branded loading feedback for page-level waits.
class StarLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;
  final String? label;

  const StarLoadingIndicator({
    super.key,
    this.size = 52,
    this.color = const Color(0xFF7C5CFC),
    this.label,
  });

  @override
  State<StarLoadingIndicator> createState() => _StarLoadingIndicatorState();
}

class _StarLoadingIndicatorState extends State<StarLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label ?? 'Loading',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final pulse = Curves.easeInOut.transform(_controller.value);
              return Opacity(
                opacity: 0.62 + (pulse * 0.38),
                child: Transform.scale(
                  scale: 0.88 + (pulse * 0.12),
                  child: child,
                ),
              );
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.star_rounded,
                size: widget.size * 0.62,
                color: widget.color,
              ),
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.label!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5F596D),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Subtle shimmer that reserves the image's final layout while it loads.
class AppImageSkeleton extends StatelessWidget {
  final BorderRadius borderRadius;

  const AppImageSkeleton({
    super.key,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEDE9F6),
      highlightColor: const Color(0xFFFAF9FC),
      period: const Duration(milliseconds: 1400),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEDE9F6),
          borderRadius: borderRadius,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
