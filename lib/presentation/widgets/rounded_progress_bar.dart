import 'package:flutter/material.dart';

/// Progress bar with rounded ends on both the track and the filled portion.
class RoundedProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color trackColor;
  final Color valueColor;

  const RoundedProgressBar({
    super.key,
    required this.value,
    required this.trackColor,
    required this.valueColor,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0).toDouble();
    final radius = BorderRadius.circular(height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: radius,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: valueColor,
              borderRadius: radius,
            ),
          ),
        ),
      ),
    );
  }
}
