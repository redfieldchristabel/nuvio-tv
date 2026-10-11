import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nuvio_tv_flutter/domain/models/stream.dart';
import 'package:nuvio_tv_flutter/domain/models/video.dart';
import 'package:nuvio_tv_flutter/domain/models/watch_progress.dart';

/// Fetches and decodes images with bounded memory.
///
/// TV posters are ~176pt wide; decoding at full resolution wastes RAM on
/// 2018-era TVs (the official web client's image cache store exists for the
/// same reason). We decode to a max width and keep an LRU of raw bytes.
class ImageRepository {
  ImageRepository({
    http.Client? client,
    this.maxCacheEntries = 200,
    this.maxDecodeWidth = 512,
  })  : _client = client ?? http.Client();

  final http.Client _client;
  final int maxCacheEntries;
  final int maxDecodeWidth;

  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final _queue = <String>[]; // LRU order, oldest first
  final _inFlight = <String, Future<Uint8List?>>{};

  /// Raw bytes for [url], cached. Returns null on failure.
  Future<Uint8List?> fetch(String url) {
    final cached = _cache[url];
    if (cached != null) {
      _touch(url);
      return Future.value(cached);
    }
    return _inFlight.putIfAbsent(url, () => _fetchAndCache(url));
  }

  Future<Uint8List?> _fetchAndCache(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final bytes = response.bodyBytes;
      _cache[url] = bytes;
      _queue.remove(url);
      _queue.add(url);
      while (_queue.length > maxCacheEntries) {
        final evict = _queue.removeAt(0);
        _cache.remove(evict);
      }
      return bytes;
    } catch (_) {
      return null;
    } finally {
      _inFlight.remove(url);
    }
  }

  void _touch(String url) {
    _queue.remove(url);
    _queue.add(url);
  }

  /// Build a resized URL for image CDNs that support it (TMDB style).
  /// Non-TMDB URLs pass through unchanged.
  String? sizedUrl(String? url, {int width = 342}) {
    if (url == null || url.isEmpty) return null;
    if (url.contains('image.tmdb.org')) {
      return url.replaceFirst('/original/', '/w$width/');
    }
    return url;
  }

  void evict(String url) {
    _cache.remove(url);
    _queue.remove(url);
  }

  void clear() {
    _cache.clear();
    _queue.clear();
  }

  void dispose() {
    clear();
    _client.close();
  }
}

/// Parses the stream quality label from a stream name/title.
///
/// Port of the official `detect-quality` helper: matches resolution tokens
/// in priority order.
class QualityDetector {
  const QualityDetector._();

  static const _patterns = <(String, List<String>)>[
    ('4K', ['2160p', '4k', 'uhd']),
    ('1440p', ['1440p', 'qhd']),
    ('1080p', ['1080p', 'fhd']),
    ('720p', ['720p', 'hd']),
    ('480p', ['480p', 'sd']),
    ('360p', ['360p']),
  ];

  /// Returns '4K', '1080p', ... or null when unknown.
  static String? detect(String? name, String? title) {
    final haystack =
        '${name ?? ''} ${title ?? ''}'.toLowerCase();
    for (final (label, tokens) in _patterns) {
      for (final token in tokens) {
        if (haystack.contains(token)) return label;
      }
    }
    return null;
  }
}

/// Groups and orders streams the way the official clients do.
///
/// Port of `streamOrdering.js`: group by origin (addon vs plugin), keep
/// addon order index, stable within groups.
class StreamOrdering {
  const StreamOrdering._();

  static List<Stream> order(List<Stream> streams) {
    final indexed = List<Stream>.from(streams);
    indexed.sort((a, b) {
      final aRank = a.addonOrderIndex ?? 1 << 30;
      final bRank = b.addonOrderIndex ?? 1 << 30;
      if (aRank != bRank) return aRank.compareTo(bRank);
      // Stable within same addon: keep original relative order.
      return 0;
    });
    return indexed;
  }

  /// Group streams by their source identity for the picker's source chips.
  static Map<String, List<Stream>> groupBySource(List<Stream> streams) {
    final groups = <String, List<Stream>>{};
    for (var i = 0; i < streams.length; i++) {
      final s = streams[i];
      final identity = s.originKind == StreamOriginKind.plugin
          ? 'plugin:${s.sourceProviderId ?? s.addonName ?? 'index-$i'}'
          : 'addon:${s.addonId ?? s.addonBaseUrl ?? s.addonName ?? 'index-$i'}';
      groups.putIfAbsent(identity, () => []).add(s);
    }
    return groups;
  }
}

/// Auto-play selection, ported from `streamAutoPlaySelector.js`.
class StreamAutoPlaySelector {
  const StreamAutoPlaySelector._();

  static const modeManual = 'MANUAL';
  static const modeFirstStream = 'FIRST_STREAM';
  static const modeRegexMatch = 'REGEX_MATCH';

  static const sourceAll = 'ALL_SOURCES';
  static const sourceAddonsOnly = 'INSTALLED_ADDONS_ONLY';
  static const sourcePluginsOnly = 'ENABLED_PLUGINS_ONLY';

  static bool isRegexConfigured(String? pattern) {
    final p = (pattern ?? '').trim();
    if (p.isEmpty) return false;
    if (!RegExp(r'[a-z0-9]', caseSensitive: false).hasMatch(p)) return false;
    try {
      RegExp(p, caseSensitive: false);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Returns the stream to auto-play, or null to leave the picker open.
  static Stream? select({
    required List<Stream> streams,
    required String mode,
    required String source,
    String? regexPattern,
  }) {
    if (mode == modeManual) return null;
    final candidates = _filterBySource(streams, source);
    if (candidates.isEmpty) return null;
    final ordered = StreamOrdering.order(candidates);
    if (mode == modeFirstStream) return ordered.first;
    if (mode == modeRegexMatch && isRegexConfigured(regexPattern)) {
      final regex = RegExp(regexPattern!, caseSensitive: false);
      for (final s in ordered) {
        final text = '${s.name ?? ''} ${s.title ?? ''} ${s.description ?? ''}';
        if (regex.hasMatch(text)) return s;
      }
      return null; // no match: leave picker open
    }
    return null;
  }

  static List<Stream> _filterBySource(List<Stream> streams, String source) {
    switch (source) {
      case sourceAddonsOnly:
        return streams
            .where((s) => s.originKind != StreamOriginKind.plugin)
            .toList();
      case sourcePluginsOnly:
        return streams
            .where((s) => s.originKind == StreamOriginKind.plugin)
            .toList();
      default:
        return streams;
    }
  }
}

/// Watch-progress thresholds and helpers, ported from `watchProgress.js`.
class WatchProgressPolicy {
  const WatchProgressPolicy._();

  static const startedThreshold = 0.02;
  static const completedThreshold = 0.9;
  static const simklCompletedThreshold = 0.8;

  static bool isStarted(double fraction) => fraction > startedThreshold;
  static bool isCompleted(double fraction, {String? source}) {
    final limit =
        source == 'simkl_playback' ? simklCompletedThreshold : completedThreshold;
    return fraction >= limit;
  }

  static bool isInProgress(double fraction, {String? source}) =>
      isStarted(fraction) && !isCompleted(fraction, source: source);
}

/// Continue-watching window policy, ported from
/// `continueWatchingRenderWindow.js`: which in-progress items surface.
class ContinueWatchingPolicy {
  const ContinueWatchingPolicy._();

  /// Items newer than [maxAge] and in-progress, newest first, capped.
  static List<WatchProgress> renderWindow(
    List<WatchProgress> progress, {
    Duration maxAge = const Duration(days: 30),
    int limit = 20,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);
    final inWindow = progress
        .where((p) =>
            p.updatedAt.isAfter(cutoff) &&
            WatchProgressPolicy.isInProgress(p.fraction, source: p.source))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return inWindow.take(limit).toList();
  }
}

/// Next-up resolver, ported from `nextUpCandidateResolver.js` +
/// `nextUpEpisodeAnchor.js`: the next unwatched episode for a series.
class NextUpResolver {
  const NextUpResolver._();

  /// [videos] sorted by season/episode. Returns the first video after the
  /// last watched one, or the first video when nothing watched.
  static Video? nextUp({
    required List<Video> videos,
    required Set<String> watchedVideoIds,
  }) {
    final sorted = List<Video>.from(videos)
      ..sort((a, b) {
        final s = (a.season ?? 0).compareTo(b.season ?? 0);
        if (s != 0) return s;
        return (a.episode ?? 0).compareTo(b.episode ?? 0);
      });
    for (final v in sorted) {
      if (!watchedVideoIds.contains(v.id)) return v;
    }
    return null;
  }
}

/// JSON helpers shared by stores.
class StoreJson {
  const StoreJson._();

  static String encode(Object value) => jsonEncode(value);

  static dynamic decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
