import 'package:flutter/material.dart';
import '../constants/tv_constants.dart';
import 'tv_focusable_widget.dart';

/// TV-optimized button with focus support
class TvButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool autofocus;
  final FocusNode? focusNode;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const TvButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.autofocus = false,
    this.focusNode,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusableWidget(
      autofocus: autofocus,
      focusNode: focusNode,
      onTap: onPressed,
      child: Container(
        height: TvConstants.tvButtonHeight,
        constraints: const BoxConstraints(
          minWidth: TvConstants.tvButtonMinWidth,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? Color(TvConstants.tvFocusColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TvConstants.tvSpacingMedium,
                vertical: TvConstants.tvSpacingSmall,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: TvConstants.tvIconSize,
                      color: foregroundColor ?? Colors.white,
                    ),
                    SizedBox(width: TvConstants.tvSpacingSmall),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: TvConstants.tvFontSizeBody,
                      fontWeight: FontWeight.bold,
                      color: foregroundColor ?? Colors.white,
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

