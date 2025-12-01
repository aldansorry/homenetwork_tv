import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/tv_constants.dart';

/// Widget wrapper for TV-friendly focusable elements
class TvFocusableWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onFocus;
  final bool autofocus;
  final FocusNode? focusNode;

  const TvFocusableWidget({
    super.key,
    required this.child,
    this.onTap,
    this.onFocus,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<TvFocusableWidget> createState() => _TvFocusableWidgetState();
}

class _TvFocusableWidgetState extends State<TvFocusableWidget> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    widget.onFocus?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap, // <- CLICK / TAP LISTENER DI SINI
        child: Container(
          decoration: _isFocused
              ? BoxDecoration(
                  border: Border.all(
                    color: Color(TvConstants.tvFocusColor),
                    width: TvConstants.tvFocusBorderWidth,
                  ),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
