import 'dart:async';

// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import 'package:video_player_avplay/video_player.dart' show AudioTrack, TextTrack, Track;

import '../skip/skip_segments.dart';


/// Playback state machine for the player screen.
///
/// Transitions:
///   idle → loading → playing ⇄ paused → ended
///                    ↓
///                  error
class PlayerController extends ChangeNotifier {
  PlayerController({
    PlayerSettings? settings,
    Future<List<AudioTrack>?> Function()? audioTracksLoader,
    Future<List<TextTrack>?> Function()? textTracksLoader,
    Future<bool> Function(Track)? trackSelector,
    SkipSegmentsService? skipService,
  })  : settings = settings ?? const PlayerSettings(),
        _audioTracksLoader = audioTracksLoader,
        _textTracksLoader = textTracksLoader,
        _trackSelector = trackSelector,
        _skipService = skipService ?? SkipSegmentsService();

  // ignore: unused_element

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
  List<AudioTrack> _audioTracks = const [];
  List<TextTrack> _textTracks = const [];
  int? _selectedAudioTrackId;
  int? _selectedTextTrackId;
  final Future<List<AudioTrack>?> Function()? _audioTracksLoader;
  final Future<List<TextTrack>?> Function()? _textTracksLoader;
  final Future<bool> Function(Track)? _trackSelector;
  final SkipSegmentsService _skipService;
  List<SkipSegment> _skipSegments = const [];
  SkipSegment? _activeSkip;
  String? _skipLookupKey;

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
    String? contentType,
    String? imdbId,
    int? season,
    int? episode,
    int? malId,
  }) async {
    _currentUrl = url;
    _currentTitle = title;
    _phase = PlayerPhase.loading;
    _errorMessage = null;
    _position = resumeFrom ?? Duration.zero;
    _activeSkip = null;
    _skipSegments = const [];
    notifyListeners();
    _fetchSkipSegments(
      contentType: contentType,
      imdbId: imdbId,
      season: season,
      episode: episode,
      malId: malId,
    );
  }

  /// Fetch skip windows (intro/OP/ED/recap/outro) from the default providers.
  /// Fire-and-forget: playback never waits on the lookups.
  Future<void> _fetchSkipSegments({
    String? contentType,
    String? imdbId,
    int? season,
    int? episode,
    int? malId,
  }) async {
    final key = '$contentType|$imdbId|$season|$episode|$malId';
    _skipLookupKey = key;
    try {
      final segments = await _skipService.getSegments(
        type: contentType ?? 'series',
        imdbId: imdbId,
        season: season,
        episode: episode,
        malId: malId,
      );
      // Ignore stale results if the user switched media meanwhile.
      if (_skipLookupKey == key && segments.isNotEmpty) {
        _skipSegments = segments;
        notifyListeners();
      }
    } catch (_) {
      // Skip lookups are best-effort; never break playback.
    }
  }

  /// All resolved skip segments for the current media.
  List<SkipSegment> get skipSegments => _skipSegments;

  /// The skip segment covering the current position, if any.
  SkipSegment? get activeSkip => _activeSkip;

  /// The next segment starting within 5s, for pre-showing the skip button.
  SkipSegment? get upcomingSkip => _skipService.upcoming(_skipSegments, _position);

  /// Skip through the currently active (or upcoming) segment.
  void skipActiveSegment() {
    final target = _activeSkip ?? upcomingSkip;
    if (target == null) return;
    seekTo(Duration(milliseconds: target.endMs));
    _activeSkip = null;
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
    // Track the active skip window as playback advances.
    final seg = _skipService.activeAt(_skipSegments, position);
    if (seg?.startMs != _activeSkip?.startMs) {
      _activeSkip = seg;
    }
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

  // ---- track control (via video_player_avplay) ----

  List<AudioTrack> get audioTracks => _audioTracks;
  List<TextTrack> get textTracks => _textTracks;
  int? get selectedAudioTrackId => _selectedAudioTrackId;
  int? get selectedTextTrackId => _selectedTextTrackId;

  /// Refresh the track lists from the platform player.
  Future<void> refreshTracks() async {
    try {
      final audio = await _audioTracksLoader?.call();
      final text = await _textTracksLoader?.call();
      _audioTracks = audio ?? const [];
      _textTracks = text ?? const [];
      notifyListeners();
    } catch (_) {
      // Track listing is best-effort; never break playback.
    }
  }

  /// Select an audio track by its platform track id.
  Future<bool> selectAudioTrack(AudioTrack track) async {
    final selector = _trackSelector;
    if (selector == null) return false;
    final ok = await selector(track);
    if (ok) {
      _selectedAudioTrackId = track.trackId;
      notifyListeners();
    }
    return ok;
  }

  /// Select a subtitle/text track by its platform track id.
  Future<bool> selectTextTrack(TextTrack track) async {
    final selector = _trackSelector;
    if (selector == null) return false;
    final ok = await selector(track);
    if (ok) {
      _selectedTextTrackId = track.trackId;
      notifyListeners();
    }
    return ok;
  }

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
