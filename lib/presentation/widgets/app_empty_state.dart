import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared empty-state card styled after the Review "All caught up" state.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconContainerSize = compact ? 60.0 : 72.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEBE6FC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: const BoxDecoration(
              color: Color(0xFFF1EDFF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                icon,
                color: const Color(0xFF7C5CFC),
                size: compact ? 30 : 38,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
              fontSize: compact ? 16 : 22,
              fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
              color: const Color(0xFF221F33),
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.lexend(
              fontSize: compact ? 12 : 14,
              color: const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}
