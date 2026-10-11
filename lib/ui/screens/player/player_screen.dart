import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/player/player_controller.dart';
import '../../../core/theme/theme.dart';

/// Full-screen player UI. Owns a [PlayerController]; the actual media
/// rendering is delegated to the platform player (video_player_tizen on
/// Tizen, video_player elsewhere) via [playerBuilder].
///
/// D-pad: OK=play/pause, left/right=skip, up/down=show chrome, back=exit.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.resumeFrom,
    this.playerBuilder,
    this.onPersistProgress,
    this.onFinished,
  });

  final String url;
  final String title;
  final Duration? resumeFrom;

  /// Platform player widget factory (injected for testability and to keep
  /// Tizen-specific code out of this file).
  final Widget Function(PlayerScreenContext context)? playerBuilder;
  final void Function(Duration position, Duration duration)? onPersistProgress;
  final VoidCallback? onFinished;

  @override
  State<PlayerScreen> createState() => PlayerScreenState();
}

@visibleForTesting
class PlayerScreenState extends State<PlayerScreen> {
  late final PlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = PlayerController();
    controller.onPersistProgress = widget.onPersistProgress;
    HardwareKeyboard.instance.addHandler(_globalKeyHandler);
    _start();
  }

  /// Global handler: TV remotes send raw key events that must work
  /// regardless of which widget has focus.
  bool _globalKeyHandler(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      controller.togglePlayPause();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      controller.seekBy(controller.skipSeconds);
      controller.showChrome();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      controller.seekBy(-controller.skipSeconds);
      controller.showChrome();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      controller.showChrome();
      return true;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop();
      return true;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      if (controller.phase == PlayerPhase.paused) controller.togglePlayPause();
      return true;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      if (controller.phase == PlayerPhase.playing) controller.togglePlayPause();
      return true;
    }
    return false;
  }

  Future<void> _start() async {
    await controller.load(
      url: widget.url,
      title: widget.title,
      resumeFrom: widget.resumeFrom,
    );
  }



  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Video surface (platform-injected).
                if (widget.playerBuilder != null)
                  widget.playerBuilder!(PlayerScreenContext(
                    controller: controller,
                  ))
                else
                  _placeholderSurface(),

                // Chrome overlay.
                AnimatedOpacity(
                  opacity: controller.chromeVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !controller.chromeVisible,
                    child: _PlayerChrome(controller: controller),
                  ),
                ),

                // Loading spinner.
                if (controller.phase == PlayerPhase.loading)
                  const Center(
                    child: CircularProgressIndicator(
                        color: NuvioColors.accent, strokeWidth: 3),
                  ),

                // Error.
                if (controller.phase == PlayerPhase.error)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: NuvioColors.error, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          controller.errorMessage ?? 'Playback failed',
                          style: const TextStyle(
                              color: NuvioColors.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
    );
  }

  Widget _placeholderSurface() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie, color: NuvioColors.textTertiary, size: 64),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          const Text(
            'Loading video surface…',
            style: TextStyle(color: NuvioColors.textTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Everything a platform player widget needs from the screen.
class PlayerScreenContext {
  const PlayerScreenContext({required this.controller});

  final PlayerController controller;
}

class _PlayerChrome extends StatelessWidget {
  const _PlayerChrome({required this.controller});

  final PlayerController controller;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.15, 0.75, 1.0],
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black87,
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: title
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: NuvioSpacing.safeGutter, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.currentTitle ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: NuvioColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom: controls + progress
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: NuvioSpacing.safeGutter, vertical: 20),
            child: Column(
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(color: Colors.white24),
                        FractionallySizedBox(
                          widthFactor: controller.fraction,
                          child: Container(color: NuvioColors.accent),
                        ),
                        FractionallySizedBox(
                          widthFactor: controller.duration > Duration.zero
                              ? (controller.buffered.inMilliseconds /
                                      controller.duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                              : 0.0,
                          child: Container(color: Colors.white38),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(_fmt(controller.position),
                        style: const TextStyle(
                            color: NuvioColors.text, fontSize: 13)),
                    const Spacer(),
                    Text(_fmt(controller.duration),
                        style: const TextStyle(
                            color: NuvioColors.textSecondary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                // Control row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ControlButton(
                      icon: Icons.replay_10,
                      onTap: () => controller.seekBy(-controller.skipSeconds),
                    ),
                    const SizedBox(width: 28),
                    _ControlButton(
                      icon: controller.phase == PlayerPhase.playing
                          ? Icons.pause
                          : Icons.play_arrow,
                      big: true,
                      onTap: controller.togglePlayPause,
                    ),
                    const SizedBox(width: 28),
                    _ControlButton(
                      icon: Icons.forward_10,
                      onTap: () => controller.seekBy(controller.skipSeconds),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: big ? 44 : 32),
      color: NuvioColors.text,
      focusColor: NuvioColors.cardFocused,
      autofocus: false,
    );
  }
}
