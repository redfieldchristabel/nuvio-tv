import 'dart:async';

import 'package:nuvio_tv_flutter/core/network/http_client.dart';import 'package:nuvio_tv_flutter/core/util/result.dart';

/// A skippable segment of a video (intro, recap, outro, …).
class SkipSegment {
  const SkipSegment({
    required this.type,
    required this.startMs,
    required this.endMs,
    required this.source,
    this.confidence = 1.0,
  });

  final SkipSegmentType type;
  final int startMs;
  final int endMs;
  final String source;
  final double confidence;

  bool contains(Duration position) =>
      position.inMilliseconds >= startMs && position.inMilliseconds < endMs;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'startMs': startMs,
        'endMs': endMs,
        'source': source,
        'confidence': confidence,
      };

  factory SkipSegment.fromJson(Map<String, dynamic> json) => SkipSegment(
        type: SkipSegmentType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => SkipSegmentType.intro,
        ),
        startMs: json['startMs'] as int,
        endMs: json['endMs'] as int,
        source: json['source'] as String? ?? 'unknown',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      );
}

enum SkipSegmentType { intro, recap, outro, postCredits, op, ed, mixedOp, mixedEd, preview }

/// Resolves skip segments for a title/episode from external databases.
abstract class SkipSegmentProvider {
  String get name;

  /// Returns segments for the given identifiers; empty list when nothing found.
  Future<List<SkipSegment>> resolve({
    required String type,
    required String? imdbId,
    required int? season,
    required int? episode,
    required int? malId,
    required int? episodeLengthSec,
  });
}

/// AniSkip — anime OP/ED/recap/preview timestamps by MyAnimeList id.
/// GET https://api.aniskip.com/v2/skip-times/{malId}/{episodeNumber}?types=...
class AniSkipProvider implements SkipSegmentProvider {
  AniSkipProvider({HttpClient? http}) : _http = http ?? HttpClient();

  final HttpClient _http;
  static const _base = 'https://api.aniskip.com/v2/skip-times';

  @override
  String get name => 'aniskip';

  @override
  Future<List<SkipSegment>> resolve({
    required String type,
    required String? imdbId,
    required int? season,
    required int? episode,
    required int? malId,
    required int? episodeLengthSec,
  }) async {
    if (malId == null || episode == null) return const [];
    final types = <String>['op', 'ed', 'recap', 'mixed-op', 'mixed-ed', 'preview'];
    final url = Uri.parse('$_base/$malId/$episode').replace(queryParameters: {
      ...{for (final t in types) 'types': t},
      if (episodeLengthSec != null) 'episodeLength': '$episodeLengthSec',
    });
    final result = await _http.getJson(url, timeout: const Duration(seconds: 8));
    return switch (result) {
      Err() => const [],
      Ok(:final value) => _parse(value),
    };
  }

  List<SkipSegment> _parse(dynamic value) {
    if (value is! Map<String, dynamic> || value['found'] != true) return const [];
    final results = value['results'];
    if (results is! List) return const [];
    final segments = <SkipSegment>[];
    for (final r in results.whereType<Map<String, dynamic>>()) {
      final interval = r['interval'];
      if (interval is! Map<String, dynamic>) continue;
      final start = (interval['startTime'] as num?)?.toDouble();
      final end = (interval['endTime'] as num?)?.toDouble();
      if (start == null || end == null || end <= start) continue;
      segments.add(SkipSegment(
        type: _typeFrom(r['skipType'] as String?),
        startMs: (start * 1000).round(),
        endMs: (end * 1000).round(),
        source: name,
      ));
    }
    return segments;
  }

  SkipSegmentType _typeFrom(String? raw) => switch (raw) {
        'op' => SkipSegmentType.op,
        'ed' => SkipSegmentType.ed,
        'recap' => SkipSegmentType.recap,
        'preview' => SkipSegmentType.preview,
        'mixed-op' => SkipSegmentType.mixedOp,
        'mixed-ed' => SkipSegmentType.mixedEd,
        _ => SkipSegmentType.intro,
      };
}

/// IntroDB — community intro/recap/outro/post-credits for TV & movies by IMDb id.
/// GET https://api.introdb.app/segments?imdb_id=...&season=&episode=  (is_movie=true for movies)
class IntroDbProvider implements SkipSegmentProvider {
  IntroDbProvider({HttpClient? http}) : _http = http ?? HttpClient();

  final HttpClient _http;
  static const _base = 'https://api.introdb.app/segments';

  @override
  String get name => 'introdb';

  @override
  Future<List<SkipSegment>> resolve({
    required String type,
    required String? imdbId,
    required int? season,
    required int? episode,
    required int? malId,
    required int? episodeLengthSec,
  }) async {
    if (imdbId == null || imdbId.isEmpty) return const [];
    final isMovie = type == 'movie';
    final params = <String, String>{
      'imdb_id': imdbId,
      if (isMovie) 'is_movie': 'true' else ...{
        'season': '${season ?? 1}',
        'episode': '${episode ?? 1}',
      },
    };
    final url = Uri.parse(_base).replace(queryParameters: params);
    final result = await _http.getJson(url, timeout: const Duration(seconds: 8));
    return switch (result) {
      Err() => const [],
      Ok(:final value) => _parse(value),
    };
  }

  List<SkipSegment> _parse(dynamic value) {
    if (value is! Map<String, dynamic>) return const [];
    const slots = {
      'intro': SkipSegmentType.intro,
      'recap': SkipSegmentType.recap,
      'outro': SkipSegmentType.outro,
      'post_credits': SkipSegmentType.postCredits,
    };
    final segments = <SkipSegment>[];
    for (final entry in slots.entries) {
      final seg = value[entry.key];
      if (seg is! Map<String, dynamic>) continue;
      final startMs = (seg['start_ms'] as num?)?.toInt() ??
          ((seg['start_sec'] as num?)?.toInt())! * 1000;
      final endMs = (seg['end_ms'] as num?)?.toInt() ??
          ((seg['end_sec'] as num?)?.toInt())! * 1000;
      if (endMs <= startMs) continue;
      segments.add(SkipSegment(
        type: entry.value,
        startMs: startMs,
        endMs: endMs,
        source: name,
        confidence: (seg['confidence'] as num?)?.toDouble() ?? 1.0,
      ));
    }
    return segments;
  }
}

/// Aggregates all providers, caches results per (title, season, episode).
class SkipSegmentsService {
  SkipSegmentsService({List<SkipSegmentProvider>? providers})
      : providers = providers ??
            [
              AniSkipProvider(),
              IntroDbProvider(),
            ];

  final List<SkipSegmentProvider> providers;
  final Map<String, List<SkipSegment>> _cache = {};
  final Map<String, Future<List<SkipSegment>>> _inFlight = {};

  String _key(String type, String? imdbId, int? season, int? episode, int? malId) =>
      '$type|$imdbId|$season|$episode|$malId';

  /// Cached lookup; fires all providers in parallel and merges results.
  Future<List<SkipSegment>> getSegments({
    required String type,
    String? imdbId,
    int? season,
    int? episode,
    int? malId,
    int? episodeLengthSec,
  }) {
    final key = _key(type, imdbId, season, episode, malId);
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);
    return _inFlight.putIfAbsent(key, () async {
      try {
        final results = await Future.wait(providers.map((p) => p.resolve(
              type: type,
              imdbId: imdbId,
              season: season,
              episode: episode,
              malId: malId,
              episodeLengthSec: episodeLengthSec,
            )));
        final merged = results.expand((r) => r).toList();
        _cache[key] = merged;
        return merged;
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  /// The segment active at [position], if any.
  SkipSegment? activeAt(List<SkipSegment> segments, Duration position) {
    for (final s in segments) {
      if (s.contains(position)) return s;
    }
    return null;
  }

  /// The next segment starting within [lookahead] of [position], if any.
  SkipSegment? upcoming(List<SkipSegment> segments, Duration position,
      {Duration lookahead = const Duration(seconds: 5)}) {
    final now = position.inMilliseconds;
    SkipSegment? best;
    for (final s in segments) {
      final delta = s.startMs - now;
      if (delta >= 0 && delta <= lookahead.inMilliseconds) {
        if (best == null || s.startMs < best.startMs) best = s;
      }
    }
    return best;
  }

  void clearCache() => _cache.clear();
}
