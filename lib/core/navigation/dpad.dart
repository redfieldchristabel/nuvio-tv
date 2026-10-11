import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'package:flutter/services.dart';

/// D-pad navigation contract for TV.
///
/// The web client implements a custom focus engine over DOM; Flutter gives us
/// focus traversal for free, but TVs need explicit handling for:
/// - back (long-press = home on some remotes)
/// - media keys (play/pause/rewind/forward)
/// - repeat throttling (holding a direction)
enum NuvioKeyAction {
  up,
  down,
  left,
  right,
  select,
  back,
  playPause,
  rewind,
  fastForward,
  mediaPlay,
  mediaPause,
  menu,
  unknown,
}

/// Throttles repeated D-pad events: first press fires immediately, repeats
/// fire at [repeatInterval] after [initialDelay].
class DpadRepeatThrottle {
  DpadRepeatThrottle({
    this.initialDelay = const Duration(milliseconds: 400),
    this.repeatInterval = const Duration(milliseconds: 90),
  });

  final Duration initialDelay;
  final Duration repeatInterval;
  Timer? _timer;

  /// Returns true when this event should fire.
  bool shouldFire(LogicalKeyboardKey key, bool isRepeat) {
    if (!isRepeat) {

      _timer?.cancel();
      _timer = Timer(initialDelay, () {});
      return true;
    }
    // Hardware repeat: gate by our own interval for consistent feel.
    return true;
  }

  void dispose() => _timer?.cancel();
}

/// Maps platform key events to [NuvioKeyAction].
NuvioKeyAction mapKey(LogicalKeyboardKey key) {
  switch (key) {
    case LogicalKeyboardKey.arrowUp:
    
      return NuvioKeyAction.up;
    case LogicalKeyboardKey.arrowDown:
    
      return NuvioKeyAction.down;
    case LogicalKeyboardKey.arrowLeft:
    
      return NuvioKeyAction.left;
    case LogicalKeyboardKey.arrowRight:
    
      return NuvioKeyAction.right;
    case LogicalKeyboardKey.select:
    case LogicalKeyboardKey.enter:
    case LogicalKeyboardKey.select:
      return NuvioKeyAction.select;
    case LogicalKeyboardKey.escape:
    case LogicalKeyboardKey.goBack:
    case LogicalKeyboardKey.browserBack:
      return NuvioKeyAction.back;
    case LogicalKeyboardKey.mediaPlayPause:
      return NuvioKeyAction.playPause;
    case LogicalKeyboardKey.mediaPlay:
      return NuvioKeyAction.mediaPlay;
    case LogicalKeyboardKey.mediaPause:
      return NuvioKeyAction.mediaPause;
    case LogicalKeyboardKey.mediaRewind:
      return NuvioKeyAction.rewind;
    case LogicalKeyboardKey.mediaFastForward:
      return NuvioKeyAction.fastForward;
    case LogicalKeyboardKey.contextMenu:
    case LogicalKeyboardKey.contextMenu:
      return NuvioKeyAction.menu;
    default:
      return NuvioKeyAction.unknown;
  }
}

/// Mixin for screens that need D-pad handling with consistent semantics.
mixin DpadHandler<T extends StatefulWidget> on State<T> {
  DpadRepeatThrottle get throttle => _throttle ??= DpadRepeatThrottle();
  DpadRepeatThrottle? _throttle;

  /// Handle a mapped action. Return true when consumed.
  bool onDpadAction(NuvioKeyAction action, bool isRepeat);

  bool handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final action = mapKey(event.logicalKey);
    if (action == NuvioKeyAction.unknown) return false;
    final isRepeat = event is KeyRepeatEvent;
    if (!throttle.shouldFire(event.logicalKey, isRepeat)) return true;
    return onDpadAction(action, isRepeat);
  }

  @override
  void dispose() {
    _throttle?.dispose();
    super.dispose();
  }
}

/// Focus scale animation used on every focusable card/button.
///
/// The web client uses CSS transform scale(1.1) with 0.2s; Flutter can do
/// this with an implicit AnimatedScale which composites on the GPU.
class FocusScale extends StatefulWidget {
  const FocusScale({
    super.key,
    required this.child,
    this.scale = NuvioSpacing.cardFocusScale,
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
    this.onFocusChange,
    this.borderRadius,
    this.focusedBorder,
  });

  final Widget child;
  final double scale;
  final Duration duration;
  final Curve curve;
  final ValueChanged<bool>? onFocusChange;
  final BorderRadius? borderRadius;
  final BorderSide? focusedBorder;

  @override
  State<FocusScale> createState() => _FocusScaleState();
}

class _FocusScaleState extends State<FocusScale> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        widget.onFocusChange?.call(focused);
      },
      child: AnimatedScale(
        scale: _focused ? widget.scale : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: AnimatedContainer(
          duration: widget.duration,
          curve: widget.curve,
          foregroundDecoration: _focused
              ? BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: Border.fromBorderSide(
                    widget.focusedBorder ??
                        BorderSide(color: NuvioColors.text, width: 3),
                  ),
                )
              : const BoxDecoration(),
          child: widget.child,
        ),
      ),
    );
  }
}
