import 'dart:async';

import 'package:flutter/foundation.dart';

/// Playback state machine for the player screen.
///
/// Transitions:
///   idle → loading → playing ⇄ paused → ended
///                    ↓
///                  error
class PlayerController extends ChangeNotifier {
  PlayerController({PlayerSettings? settings})
      : settings = settings ?? const PlayerSettings();

  PlayerSettings settings;

  PlayerPhase _phase = PlayerPhase.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  String? _errorMessage;
  String? _currentUrl;
  String? _currentTitle;
  bool _chromeVisible = true;
  Timer? _chromeTimer;
  Timer? _positionSaver;
  final List<Duration?> _seekHistory = [];

  PlayerPhase get phase => _phase;
  Duration get position => _position;
  Duration get duration => _duration;
  Duration get buffered => _buffered;
  String? get errorMessage => _errorMessage;
  String? get currentTitle => _currentTitle;
  String? get currentUrl => _currentUrl;
  bool get chromeVisible => _chromeVisible;
  double get fraction =>
      _duration.inMilliseconds > 0
          ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0, 1)
          : 0;

  /// Called every ~5s by the screen to persist resume position.
  void Function(Duration position, Duration duration)? onPersistProgress;

  // ---- lifecycle ----

  Future<void> load({
    required String url,
    String? title,
    Duration? resumeFrom,
  }) async {
    _currentUrl = url;
    _currentTitle = title;
    _phase = PlayerPhase.loading;
    _errorMessage = null;
    _position = resumeFrom ?? Duration.zero;
    notifyListeners();
  }

  /// The media player implementation calls these:
  void markReady(Duration duration) {
    _duration = duration;
    _phase = PlayerPhase.playing;
    _scheduleChromeHide();
    _startPositionSaver();
    notifyListeners();
  }

  void markError(String message) {
    _phase = PlayerPhase.error;
    _errorMessage = message;
    _positionSaver?.cancel();
    notifyListeners();
  }

  void updatePosition(Duration position, {Duration? buffered}) {
    _position = position;
    if (buffered != null) _buffered = buffered;
    // Notify at most ~4x/sec to keep UI smooth without per-frame rebuilds.
    notifyListeners();
  }

  void markEnded() {
    _phase = PlayerPhase.ended;
    _positionSaver?.cancel();
    notifyListeners();
  }

  // ---- user actions ----

  void togglePlayPause() {
    switch (_phase) {
      case PlayerPhase.playing:
        _phase = PlayerPhase.paused;
        _positionSaver?.cancel();
        _showChrome();
      case PlayerPhase.paused:
        _phase = PlayerPhase.playing;
        _scheduleChromeHide();
        _startPositionSaver();
      default:
        break;
    }
    notifyListeners();
  }

  void seekTo(Duration position) {
    if (_duration <= Duration.zero) return;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > _duration ? _duration : position);
    _position = clamped;
    _seekHistory.add(clamped);
    if (_seekHistory.length > 10) _seekHistory.removeAt(0);
    notifyListeners();
  }

  void seekBy(int seconds) {
    seekTo(Duration(seconds: _position.inSeconds + seconds));
  }

  void showChrome() {
    _showChrome();
    if (_phase == PlayerPhase.playing) _scheduleChromeHide();
  }

  void _showChrome() {
    _chromeVisible = true;
    notifyListeners();
  }

  void _scheduleChromeHide() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (_phase == PlayerPhase.playing) {
        _chromeVisible = false;
        notifyListeners();
      }
    });
  }

  void _startPositionSaver() {
    _positionSaver?.cancel();
    _positionSaver = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_phase == PlayerPhase.playing && onPersistProgress != null) {
        onPersistProgress!(_position, _duration);
      }
    });
  }

  /// Whether to show the resume prompt (started but not finished).
  bool shouldPromptResume() {
    if (_duration <= Duration.zero) return false;
    final f = fraction;
    return f > 0.02 && f < 0.9;
  }

  /// Skip interval from settings.
  int get skipSeconds => settings.skipIntervalSeconds;

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _positionSaver?.cancel();
    super.dispose();
  }
}

enum PlayerPhase { idle, loading, playing, paused, ended, error }

/// Player preferences persisted in settings.
class PlayerSettings {
  const PlayerSettings({
    this.skipIntervalSeconds = 10,
    this.autoPlayNext = true,
    this.defaultSubtitleLanguage,
    this.subtitleTextScale = 1.0,
    this.subtitleDelayMs = 0,
  });

  final int skipIntervalSeconds;
  final bool autoPlayNext;
  final String? defaultSubtitleLanguage;
  final double subtitleTextScale;
  final int subtitleDelayMs;

  PlayerSettings copyWith({
    int? skipIntervalSeconds,
    bool? autoPlayNext,
    String? defaultSubtitleLanguage,
    double? subtitleTextScale,
    int? subtitleDelayMs,
  }) {
    return PlayerSettings(
      skipIntervalSeconds: skipIntervalSeconds ?? this.skipIntervalSeconds,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      defaultSubtitleLanguage:
          defaultSubtitleLanguage ?? this.defaultSubtitleLanguage,
      subtitleTextScale: subtitleTextScale ?? this.subtitleTextScale,
      subtitleDelayMs: subtitleDelayMs ?? this.subtitleDelayMs,
    );
  }
}
