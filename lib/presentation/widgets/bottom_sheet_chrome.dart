import 'package:flutter/material.dart';

import '../../constants/design_tokens.dart';

/// Shared drag handle used at the top of draggable bottom sheets.
class AppBottomSheetDragHandle extends StatelessWidget {
  final EdgeInsetsGeometry? margin;

  const AppBottomSheetDragHandle({super.key, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DesignTokens.bottomSheetHandleWidth,
      height: DesignTokens.bottomSheetHandleHeight,
      margin: margin,
      decoration: BoxDecoration(
        color: DesignTokens.bottomSheetHandleColor,
        borderRadius:
            BorderRadius.circular(DesignTokens.bottomSheetHandleHeight / 2),
      ),
    );
  }
}

/// Shared close control used in bottom-sheet headers.
class AppBottomSheetCloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const AppBottomSheetCloseButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Close',
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: DesignTokens.bottomSheetCloseButtonColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: DesignTokens.bottomSheetCloseButtonSize,
            height: DesignTokens.bottomSheetCloseButtonSize,
            child: const Center(
              child: Icon(
                Icons.close_rounded,
                size: DesignTokens.bottomSheetCloseIconSize,
                color: DesignTokens.bottomSheetCloseIconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
