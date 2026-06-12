import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom numeric keypad for OTP input
/// Matches the app's design with gradients, rounded corners, and animations
class OtpKeypad extends StatefulWidget {
  /// Callback when a number is pressed (0-9)
  final void Function(int number) onNumberPressed;

  /// Callback when backspace is pressed
  final VoidCallback? onBackspacePressed;

  /// Enable/disable the keypad
  final bool enabled;

  const OtpKeypad({
    super.key,
    required this.onNumberPressed,
    this.onBackspacePressed,
    this.enabled = true,
  });

  @override
  State<OtpKeypad> createState() => _OtpKeypadState();
}

class _OtpKeypadState extends State<OtpKeypad>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Track which button is being pressed for animation
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPressed(int index, {int? number, bool isBackspace = false}) {
    if (!widget.enabled) return;

    setState(() => _pressedIndex = index);
    _animationController.forward().then((_) {
      _animationController.reverse();
      if (mounted) setState(() => _pressedIndex = null);
    });

    // Vibrate on press
    // HapticFeedback.lightImpact();

    if (isBackspace) {
      widget.onBackspacePressed?.call();
    } else if (number != null) {
      widget.onNumberPressed(number);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keypad layout: 1-9, 0, and backspace
    final keys = [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
      [null, 0, 'backspace'], // null = empty space, 0 = number, 'backspace' = delete
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: List.generate(3, (col) {
                final value = keys[row][col];
                final index = row * 3 + col;

                if (value == null) {
                  // Empty space
                  return const Expanded(child: SizedBox());
                } else if (value == 'backspace') {
                  // Backspace button
                  return Expanded(
                    child: _KeypadButton(
                      index: index,
                      isPressed: _pressedIndex == index,
                      onPressed: () => _onPressed(index, isBackspace: true),
                      isBackspace: true,
                      child: Icon(
                        Icons.backspace_outlined,
                        size: 24,
                        color: widget.enabled
                            ? const Color(0xFF8b5cf6)
                            : const Color(0xFF9ca3af),
                      ),
                    ),
                  );
                } else {
                  // Number button
                  return Expanded(
                    child: _KeypadButton(
                      index: index,
                      isPressed: _pressedIndex == index,
                      onPressed: () => _onPressed(index, number: value as int),
                      isBackspace: false,
                      child: Text(
                        value.toString(),
                        style: GoogleFonts.lexend(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: widget.enabled
                              ? const Color(0xFF1f2937)
                              : const Color(0xFF9ca3af),
                        ),
                      ),
                    ),
                  );
                }
              }),
            ),
          );
        }),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final int index;
  final bool isPressed;
  final VoidCallback onPressed;
  final Widget child;
  final bool isBackspace;

  const _KeypadButton({
    required this.index,
    required this.isPressed,
    required this.onPressed,
    required this.child,
    this.isBackspace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 64,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
