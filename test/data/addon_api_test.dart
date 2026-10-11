import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart' show AppErrorKind;
import 'package:nuvio_tv_flutter/data/remote/addon_api.dart';

const _manifestJson = '''
{
  "id": "com.cinemeta",
  "name": "Cinemeta",
  "version": "3.0.10",
  "description": "Official Stremio addon",
  "types": ["movie", "series"],
  "catalogs": [
    {"id": "popular", "type": "movie", "name": "Popular Movies", "genres": ["Action", "Drama"]},
    {"id": "top", "type": "series", "name": "Top Series"}
  ],
  "resources": ["catalog", "meta", "stream", {"name": "subtitles", "types": ["movie"]}],
  "background": "https://cinemeta.test/bg.jpg",
  "logo": "https://cinemeta.test/logo.png",
  "contactEmail": "cinemeta@stremio.com"
}
''';

const _catalogJson = '''
{
  "metas": [
    {"id": "tt0111161", "type": "movie", "name": "The Shawshank Redemption", "poster": "https://img.test/poster1.jpg", "imdbRating": "9.3", "releaseInfo": "1994"},
    {"id": "tt0068646", "type": "movie", "name": "The Godfather", "poster": "https://img.test/poster2.jpg", "imdbRating": "9.2", "releaseInfo": "1972"}
  ]
}
''';

const _streamsJson = '''
{
  "streams": [
    {"name": "4K", "title": "Torrentio 4K", "infoHash": "abc123", "fileIdx": 1, "addonName": "Torrentio"},
    {"name": "1080p", "title": "Direct HTTP", "url": "https://stream.test/movie.mp4", "addonName": "Torrentio"},
    {"name": "YouTube", "title": "Trailer", "ytId": "dQw4w9WgXcQ"}
  ]
}
''';

HttpClient _clientFor(Map<String, String> routes) {
  return HttpClient(
    maxRetries: 0,
    client: MockClient((request) async {
      final path = request.url.path;
      for (final entry in routes.entries) {
        if (path.contains(entry.key)) {
          return http.Response(entry.value, 200);
        }
      }
      return http.Response('not found', 404);
    }),
  );
}

void main() {
  late AddonApi api;

  setUp(() {
    api = AddonApi(_clientFor({
      'manifest.json': _manifestJson,
      'catalog/movie/popular': _catalogJson,
      'stream/movie/tt0111161': _streamsJson,
      'meta/movie/tt0111161': jsonEncode({
        'meta': {
          'id': 'tt0111161',
          'type': 'movie',
          'name': 'The Shawshank Redemption',
          'description': 'Two imprisoned men bond over years.',
          'releaseInfo': '1994',
          'runtime': '142 min',
          'imdbRating': '9.3',
          'genres': ['Drama'],
          'cast': ['Tim Robbins', 'Morgan Freeman'],
          'videos': [
            {'id': 'tt0111161', 'title': 'Full Movie'}
          ]
        }
      }),
      'subtitles/movie/tt0111161': jsonEncode({
        'subtitles': [
          {'id': 'sub1', 'lang': 'eng', 'url': 'https://sub.test/en.srt', 'format': 'srt'}
        ]
      }),
    }));
  });

  group('AddonApi.getManifest', () {
    test('parses full manifest', () async {
      final result = await api.getManifest(Uri.parse('https://cinemeta.test/'));
      final addon = result.valueOrNull!;
      expect(addon.id, 'com.cinemeta');
      expect(addon.name, 'Cinemeta');
      expect(addon.types, ['movie', 'series']);
      expect(addon.catalogs.length, 2);
      expect(addon.catalogs.first.genres, ['Action', 'Drama']);
      expect(addon.resources.map((r) => r.name),
          containsAll(['catalog', 'meta', 'stream', 'subtitles']));
      expect(addon.supportsResource('stream'), isTrue);
      expect(addon.supportsResource('nonexistent'), isFalse);
    });

    test('rejects manifest without id', () async {
      final bad = AddonApi(_clientFor({
        'manifest.json': '{"name": "no id here"}',
      }));
      final result = await bad.getManifest(Uri.parse('https://x.test/'));
      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.kind, AppErrorKind.parse);
    });
  });

  group('AddonApi.getCatalog', () {
    test('parses metas', () async {
      final result = await api.getCatalog(
        Uri.parse('https://cinemeta.test/'),
        type: 'movie',
        catalogId: 'popular',
      );
      final metas = result.valueOrNull!;
      expect(metas.length, 2);
      expect(metas.first.id, 'tt0111161');
      expect(metas.first.name, 'The Shawshank Redemption');
      expect(metas.first.imdbRating, '9.3');
    });

    test('appends extra params to path', () async {
      Uri? captured;
      final api2 = AddonApi(HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(_catalogJson, 200);
        }),
      ));
      await api2.getCatalog(
        Uri.parse('https://cinemeta.test/'),
        type: 'movie',
        catalogId: 'popular',
        extra: {'genre': 'Action', 'skip': '100'},
      );
      expect(captured!.path, contains('genre=Action'));
      expect(captured!.path, contains('skip=100'));
      expect(captured!.path, endsWith('.json'));
    });
  });

  group('AddonApi.getStreams', () {
    test('parses torrent, http and youtube streams', () async {
      final result = await api.getStreams(
        Uri.parse('https://torrentio.test/'),
        'movie',
        'tt0111161',
      );
      final streams = result.valueOrNull!;
      expect(streams.length, 3);
      expect(streams[0].isTorrent, isTrue);
      expect(streams[0].infoHash, 'abc123');
      expect(streams[1].isPlayable, isTrue);
      expect(streams[1].url, 'https://stream.test/movie.mp4');
      expect(streams[2].isYoutube, isTrue);
      expect(streams[2].ytId, 'dQw4w9WgXcQ');
    });
  });

  group('AddonApi.getMeta', () {
    test('parses meta detail with videos', () async {
      final result = await api.getMeta(
        Uri.parse('https://cinemeta.test/'),
        'movie',
        'tt0111161',
      );
      final meta = result.valueOrNull!;
      expect(meta.id, 'tt0111161');
      expect(meta.runtime, '142 min');
      expect(meta.cast, ['Tim Robbins', 'Morgan Freeman']);
      expect(meta.videos.length, 1);
    });

    test('errors on non-object response', () async {
      final bad = AddonApi(_clientFor({
        'meta/': '"just a string"',
      }));
      final result = await bad.getMeta(
        Uri.parse('https://x.test/'),
        'movie',
        'tt1',
      );
      expect(result.isErr, isTrue);
    });
  });

  group('AddonApi.getSubtitles', () {
    test('parses subtitle list', () async {
      final result = await api.getSubtitles(
        Uri.parse('https://cinemeta.test/'),
        'movie',
        'tt0111161',
      );
      final subs = result.valueOrNull!;
      expect(subs.length, 1);
      expect(subs.first.lang, 'eng');
      expect(subs.first.format, 'srt');
    });
  });

  group('URL joining', () {
    test('handles base with and without trailing slash', () async {
      Uri? captured;
      final api2 = AddonApi(HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(_manifestJson, 200);
        }),
      ));
      await api2.getManifest(Uri.parse('https://x.test/sub/dir'));
      expect(captured!.path, '/sub/dir/manifest.json');
      await api2.getManifest(Uri.parse('https://x.test/sub/dir/'));
      expect(captured!.path, '/sub/dir/manifest.json');
    });
  });
}
