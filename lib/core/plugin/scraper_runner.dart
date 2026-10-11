import 'dart:async';
import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';

import 'plugin_models.dart';

/// Executes JS scrapers in a QuickJS runtime (via flutter_js).
///
/// Each scraper's code is evaluated once into the runtime; then
/// `loadLinks(type, imdbId, season, episode)` is invoked and its return
/// value is decoded into stream maps.
///
/// Safety limits (ported from the Android client):
/// - 10 concurrent scrapers max
/// - 150 results max per scraper
/// - 120s outer timeout
class ScraperRunner {
  // ignore: prefer_initializing_formals
  ScraperRunner({
    this.maxConcurrent = 10,
    this.maxResultsPerScraper = 150,
    this.timeout = const Duration(seconds: 120),
  });

  final int maxConcurrent;
  final int maxResultsPerScraper;
  final Duration timeout;

  JavascriptRuntime? _runtime;
  final Set<String> _loadedScrapers = {};

  JavascriptRuntime get runtime => _runtime ??= getJavascriptRuntime();

  /// Execute one scraper, returning raw result maps.
  Future<List<Map<String, dynamic>>> execute({
    required Scraper scraper,
    required String type,
    required String imdbId,
    int? season,
    int? episode,
  }) async {
    if (!scraper.enabled || scraper.code.isEmpty) return const [];

    try {
      // Load scraper code once per runtime instance.
      if (!_loadedScrapers.contains(scraper.id)) {
        final loadResult = await runtime.evaluateAsync(scraper.code);
        if (loadResult.isError) return const [];
        _loadedScrapers.add(scraper.id);
      }

      final call = season != null
          ? "JSON.stringify(loadLinks('$type', '$imdbId', $season, $episode))"
          : "JSON.stringify(loadLinks('$type', '$imdbId'))";

      final result = await runtime.evaluateAsync(call).timeout(timeout);
      if (result.isError || result.stringResult == 'null') return const [];

      return decodeScraperResult(result.stringResult)
          .take(maxResultsPerScraper)
          .toList();
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Execute many scrapers with bounded concurrency.
  Future<List<Map<String, dynamic>>> executeAll({
    required List<Scraper> scrapers,
    required String type,
    required String imdbId,
    int? season,
    int? episode,
  }) async {
    final enabled = scrapers
        .where((s) => s.enabled)
        .where((s) => type == 'series' ? s.supportsSeries : s.supportsMovies)
        .toList();

    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < enabled.length; i += maxConcurrent) {
      final batch = enabled.skip(i).take(maxConcurrent).toList();
      final batchResults = await Future.wait(batch.map((s) => execute(
            scraper: s,
            type: type,
            imdbId: imdbId,
            season: season,
            episode: episode,
          )));
      for (final list in batchResults) {
        results.addAll(list);
      }
    }
    return results;
  }

  /// Decode scraper output: array of {name,title,url,infoHash,...} maps.
  /// Public for testing.
  static List<Map<String, dynamic>> decodeScraperResult(String raw) {
    try {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == 'null') return const [];
      final value = trimmed.startsWith('[')
          ? jsonDecode(trimmed)
          : jsonDecode('[$trimmed]');
      if (value is! List) return const [];
      return value.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  void dispose() {
    _loadedScrapers.clear();
    _runtime?.dispose();
    _runtime = null;
  }
}
