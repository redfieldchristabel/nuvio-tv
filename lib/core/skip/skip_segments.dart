import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';
import 'package:nuvio_tv_flutter/state/settings_controller.dart';

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

/// AnimeSkip — GraphQL API for fine-grained anime segment timestamps.
/// Requires a registered X-Client-ID header.
///
/// Episode lookup: AnimeSkip keys episodes by its own episode ids, so we
/// first search shows by the title's MAL id via the `searchShows` query
/// (MAL ids are indexed as `anilist/mal` external mappings), then fetch
/// the season episode's segments. Nothing found / no mapping -> empty.
class AnimeSkipProvider implements SkipSegmentProvider {
  AnimeSkipProvider({HttpClient? http, required this.clientId})
      : _http = http ?? HttpClient();

  final HttpClient _http;
  final String clientId;
  static const _endpoint = 'https://api.anime-skip.com/graphql';

  @override
  String get name => 'anime-skip';

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

    // 1. Find the show by MAL external mapping.
    final showResult = await _query('''
query(\$mal: String!) {
  searchShows(search: {externalId: {id: \$mal, source: MAL}}) {
    shows { id }
  }
}''', {'mal': '$malId'});
    if (showResult.isErr) return const [];
    final showId = _extractShowId(showResult.valueOrNull);
    if (showId == null || showId.isEmpty) return const [];

    // 2. Fetch the episode's segments (season-absolute episode number).
    final epResult = await _query('''
query(\$show: String!, \$ep: Int!) {
  episodes(showId: \$show, filter: {isSeason: false, number: \$ep}) {
    episodes { id segments { type start end } }
  }
}''', {'show': showId, 'ep': episode});
    if (epResult.isErr) return const [];
    final segmentsRaw = _extractSegments(epResult.valueOrNull);

    // 3. Map AnimeSkip segment types to ours.
    final out = <SkipSegment>[];
    for (final s in segmentsRaw.whereType<Map<String, dynamic>>()) {
      final start = (s['start'] as num?)?.toDouble();
      final end = (s['end'] as num?)?.toDouble();
      if (start == null || end == null || end <= start) continue;
      out.add(SkipSegment(
        type: _typeFrom(s['type'] as String?),
        startMs: (start * 1000).round(),
        endMs: (end * 1000).round(),
        source: name,
      ));
    }
    return out;
  }

  /// Debug hook: last raw response body (set when debugCapture is set).
  static String? Function(String)? debugCapture;

  Future<Result<dynamic>> _query(
      String query, Map<String, dynamic> variables) async {
    final result = await _http.postJson(
      Uri.parse(_endpoint),
      body: {'query': query, 'variables': variables},
      headers: {'X-Client-ID': clientId},
      timeout: const Duration(seconds: 8),
    );
    if (debugCapture != null) {
      debugCapture!(result.isOk ? 'OK: \${result.valueOrNull.toString().substring(0, 80)}' : 'ERR: \${result.errorOrNull?.kind.name} \${result.errorOrNull?.message}');
    }
    return result;
  }

  /// Extract the show id from a searchShows GraphQL response.
  String? _extractShowId(dynamic value) {
    final shows = _digList(value, ['data', 'searchShows', 'shows']);
    if (shows.isEmpty) return null;
    return shows.first['id']?.toString();
  }

  /// Extract the raw segments list from an episodes GraphQL response.
  List<dynamic> _extractSegments(dynamic value) {
    final episodes = _digList(value, ['data', 'episodes', 'episodes']);
    if (episodes.isEmpty) return const [];
    final segments = episodes.first['segments'];
    return segments is List ? segments : const [];
  }

  /// Walk a path of map keys; returns the list at the end (empty on any
  /// shape mismatch).
  List<Map<String, dynamic>> _digList(dynamic node, List<String> path) {
    dynamic current = node;
    for (final key in path) {
      if (current is! Map) return const [];
      current = current[key];
    }
    if (current is! List) return const [];
    return current.whereType<Map<String, dynamic>>().toList();
  }

  SkipSegmentType _typeFrom(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'intro':
      case 'op':
        return SkipSegmentType.intro;
      case 'credits':
      case 'ed':
        return SkipSegmentType.outro;
      case 'recap':
        return SkipSegmentType.recap;
      case 'preview':
        return SkipSegmentType.preview;
      case 'mixed-op':
        return SkipSegmentType.mixedOp;
      case 'mixed-ed':
        return SkipSegmentType.mixedEd;
      default:
        return SkipSegmentType.intro;
    }
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
        // A failing provider must never break the others (or playback):
        // wait all, swallow individual errors, keep successful results.
        final settled = await Future.wait(providers.map((p) async {
          try {
            return await p.resolve(
              type: type,
              imdbId: imdbId,
              season: season,
              episode: episode,
              malId: malId,
              episodeLengthSec: episodeLengthSec,
            );
          } catch (_) {
            return const <SkipSegment>[];
          }
        }));
        final merged = settled.expand((r) => r).toList();
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


/// App-wired skip service: rebuilds when skip settings change so provider
/// membership (IntroDB on/off, AnimeSkip + client ID) follows the user's
/// playback settings — mirroring the official Nuvio toggle behaviour.
final skipSegmentsProvider = Provider<SkipSegmentsService>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
  final providers = <SkipSegmentProvider>[];
  if (settings.skipIntroEnabled) {
    providers.add(IntroDbProvider());
    providers.add(AniSkipProvider());
  }
  if (settings.animeSkipEnabled) {
    final clientId = settings.animeSkipClientId;
    if (clientId != null && clientId.isNotEmpty) {
      providers.add(AnimeSkipProvider(clientId: clientId));
    }
  }
  return SkipSegmentsService(providers: providers);
});
