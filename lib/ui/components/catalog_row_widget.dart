import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme.dart';

/// A horizontal catalog row: title + lazy poster list with edge fades.
///
/// D-pad behavior: up/down moves between rows (handled by parent),
/// left/right scrolls through items, focus moves card to card. When focus
/// reaches the edge, the list scrolls smoothly.
class CatalogRowWidget extends StatefulWidget {
  const CatalogRowWidget({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.onItemFocused,
    this.rowHeight = NuvioSpacing.posterHeight + 24,
    this.autofocusFirst = false,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onItemFocused;
  final double rowHeight;
  final bool autofocusFirst;

  @override
  State<CatalogRowWidget> createState() => CatalogRowWidgetState();
}

class CatalogRowWidgetState extends State<CatalogRowWidget> {
  final ScrollController _controller = ScrollController();
  int _focusedIndex = 0;

  int get focusedIndex => _focusedIndex;

  static const _cardWidth = NuvioSpacing.posterWidth;
  static const _gap = NuvioSpacing.cardGap;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Move focus highlight to [index] and scroll it into view.
  void focusItem(int index) {
    if (index < 0 || index >= widget.itemCount) return;
    setState(() => _focusedIndex = index);
    widget.onItemFocused?.call(index);
    _scrollTo(index);
  }

  void _scrollTo(int index) {
    if (!_controller.hasClients) return;
    final target = index * (_cardWidth + _gap);
    final viewport = _controller.position.viewportDimension;
    final current = _controller.offset;
    // Keep the focused card comfortably in view.
    if (target < current + _cardWidth) {
      _controller.animateTo(
        (target - _cardWidth).clamp(0.0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else if (target > current + viewport - _cardWidth * 2) {
      _controller.animateTo(
        (target - viewport + _cardWidth * 2)
            .clamp(0.0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.rowHeight + 44, // title + row
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: NuvioSpacing.safeGutter, bottom: 10),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: NuvioColors.text,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.03, 0.97, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: NuvioSpacing.safeGutter),
                itemExtent: _cardWidth + _gap,
                itemCount: widget.itemCount,
                addAutomaticKeepAlives: false,
                // ignore: deprecated_member_use
                cacheExtent: 800,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: _gap),
                    child: Focus(
                      autofocus: widget.autofocusFirst && index == 0,
                      onFocusChange: (f) {
                        if (f) focusItem(index);
                      },
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent &&
                            event is! KeyRepeatEvent) {
                          return KeyEventResult.ignored;
                        }
                        final key = event.logicalKey;
                        if (key == LogicalKeyboardKey.arrowRight) {
                          focusItem(index + 1);
                          return KeyEventResult.handled;
                        }
                        if (key == LogicalKeyboardKey.arrowLeft) {
                          focusItem(index - 1);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: widget.itemBuilder(context, index),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
