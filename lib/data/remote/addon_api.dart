import 'dart:convert';

import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';
import 'package:nuvio_tv_flutter/domain/models/addon.dart';
import 'package:nuvio_tv_flutter/domain/models/meta.dart';
import 'package:nuvio_tv_flutter/domain/models/stream.dart';

/// Speaks the Stremio addon HTTP protocol.
///
/// Endpoints (all GET, JSON):
///   {base}/manifest.json
///   {base}/catalog/{type}/{id}[/{extra}...].json
///   {base}/meta/{type}/{id}.json
///   {base}/stream/{type}/{id}.json
///   {base}/subtitles/{type}/{id}.json
class AddonApi {
  AddonApi(this._http);

  final HttpClient _http;

  Future<Result<Addon>> getManifest(Uri baseUrl) async {
    final uri = _join(baseUrl, 'manifest.json');
    final result = await _http.getJson(uri);
    return switch (result) {
      Ok(:final value) => _parseManifest(value, baseUrl.toString()),
      Err(:final error) => Result.err(error),
    };
  }

  Future<Result<List<MetaPreview>>> getCatalog(
    Uri baseUrl, {
    required String type,
    required String catalogId,
    Map<String, String> extra = const {},
  }) async {
    final segments = <String>['catalog', type, catalogId];
    final extraPairs = extra.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .toList();
    final path = extraPairs.isEmpty
        ? '${segments.join('/')}.json'
        : '${segments.join('/')}/${extraPairs.join('&')}.json';
    final result = await _http.getJson(_join(baseUrl, path));
    return switch (result) {
      Ok(:final value) => Result.ok(_parseMetas(value)),
      Err(:final error) => Result.err(error),
    };
  }

  Future<Result<Meta>> getMeta(Uri baseUrl, String type, String id) async {
    final result =
        await _http.getJson(_join(baseUrl, 'meta/$type/$id.json'));
    return _metaFromResult(result);
  }

  Result<Meta> _metaFromResult(Result<dynamic> result) {
    final error = result.errorOrNull;
    if (error != null) return Result.err(error);
    var value = result.valueOrNull;
    if (value is Map<String, dynamic> && value['meta'] is Map<String, dynamic>) {
      // Some addons wrap: {"meta": {...}}. Unwrap.
      value = value['meta'] as Map<String, dynamic>;
    }
    if (value is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Meta response not an object'));
    }
    return Result.ok(Meta.fromJson(value));
  }

  Future<Result<List<Stream>>> getStreams(
    Uri baseUrl,
    String type,
    String id,
  ) async {
    final result =
        await _http.getJson(_join(baseUrl, 'stream/$type/$id.json'));
    return switch (result) {
      Ok(:final value) => Result.ok(_parseStreams(value)),
      Err(:final error) => Result.err(error),
    };
  }

  Future<Result<List<Subtitle>>> getSubtitles(
    Uri baseUrl,
    String type,
    String id,
  ) async {
    final result =
        await _http.getJson(_join(baseUrl, 'subtitles/$type/$id.json'));
    return switch (result) {
      Ok(:final value) => Result.ok(_parseSubtitles(value)),
      Err(:final error) => Result.err(error),
    };
  }

  // ---- parsing ----

  Result<Addon> _parseManifest(dynamic value, String url) {
    if (value is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Manifest not an object'));
    }
    if ((value['id'] as String?) == null) {
      return Result.err(AppError.parse('Manifest missing id'));
    }
    return Result.ok(Addon.fromJson(value, url: url));
  }

  List<MetaPreview> _parseMetas(dynamic value) {
    if (value is! Map<String, dynamic>) return const [];
    final list = value['metas'] as List<dynamic>?;
    if (list == null) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(MetaPreview.fromJson)
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  List<Stream> _parseStreams(dynamic value) {
    if (value is! Map<String, dynamic>) return const [];
    final list = value['streams'] as List<dynamic>?;
    if (list == null) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Stream.fromJson)
        .toList();
  }

  List<Subtitle> _parseSubtitles(dynamic value) {
    if (value is! Map<String, dynamic>) return const [];
    final list = value['subtitles'] as List<dynamic>?;
    if (list == null) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Subtitle.fromJson)
        .toList();
  }

  Uri _join(Uri base, String path) {
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$basePath/$path');
  }
}

/// Convenience: parse a manifest JSON string (used by tests and by
/// paste-a-manifest flows).
Addon? parseManifestJson(String raw, String url) {
  try {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic>) return null;
    return Addon.fromJson(value, url: url);
  } catch (_) {
    return null;
  }
}
