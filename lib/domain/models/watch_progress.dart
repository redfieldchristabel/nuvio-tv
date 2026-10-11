/// Playback progress for a movie or a single episode.
///
/// Thresholds mirror the official clients:
/// - started when > 2% watched
/// - completed when > 90% watched (Simkl reports completion at 80%)
class WatchProgress {
  const WatchProgress({
    required this.contentId,
    required this.contentType,
    this.videoId,
    this.positionMs = 0,
    this.durationMs = 0,
    required this.updatedAt,
    this.source,
  });

  final String contentId;
  final String contentType;
  final String? videoId;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;

  /// 'local' | 'trakt' | 'simkl' | 'simkl_playback' | 'cloud'
  final String? source;

  static const double startedThreshold = 0.02;
  static const double completedThreshold = 0.9;
  static const double simklCompletedThreshold = 0.8;

  double get fraction {
    if (positionMs > 0 && durationMs > 0) {
      return (positionMs / durationMs).clamp(0.0, 1.0);
    }
    return 0;
  }

  double get completedLimit =>
      source == 'simkl_playback' ? simklCompletedThreshold : completedThreshold;

  bool get isStarted => fraction > startedThreshold;
  bool get isCompleted => fraction >= completedLimit;
  bool get isInProgress => isStarted && !isCompleted;

  WatchProgress copyWith({
    String? contentId,
    String? contentType,
    String? videoId,
    int? positionMs,
    int? durationMs,
    DateTime? updatedAt,
    String? source,
  }) {
    return WatchProgress(
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      videoId: videoId ?? this.videoId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'contentType': contentType,
        if (videoId != null) 'videoId': videoId,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt.toIso8601String(),
        if (source != null) 'source': source,
      };

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    return WatchProgress(
      contentId: (json['contentId'] as String?) ?? '',
      contentType: (json['contentType'] as String?) ?? 'movie',
      videoId: json['videoId'] as String?,
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
              DateTime.now(),
      source: json['source'] as String?,
    );
  }
}

/// A watched marker for a whole series item (library "watched" state).
class WatchedItem {
  const WatchedItem({
    required this.contentId,
    required this.contentType,
    required this.watchedAt,
    this.watchedEpisodes = const {},
  });

  final String contentId;
  final String contentType;
  final DateTime watchedAt;

  /// Keys are video ids ("tt123:1:2" style) that are individually watched.
  final Set<String> watchedEpisodes;

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'contentType': contentType,
        'watchedAt': watchedAt.toIso8601String(),
        'watchedEpisodes': watchedEpisodes.toList(),
      };

  factory WatchedItem.fromJson(Map<String, dynamic> json) {
    return WatchedItem(
      contentId: (json['contentId'] as String?) ?? '',
      contentType: (json['contentType'] as String?) ?? 'movie',
      watchedAt:
          DateTime.tryParse(json['watchedAt'] as String? ?? '') ??
              DateTime.now(),
      watchedEpisodes:
          ((json['watchedEpisodes'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toSet(),
    );
  }
}
