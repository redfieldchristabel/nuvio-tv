import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/tracking/more_like_this_service.dart';
import 'package:nuvio_tv_flutter/core/tracking/tracking_services.dart';
import 'package:nuvio_tv_flutter/domain/models/content_type.dart';

const _traktRelatedJson = '''
[
  {
    "title": "The Godfather",
    "year": 1972,
    "ids": {"trakt": 1, "slug": "the-godfather-1972", "imdb": "tt0068646", "tmdb": 238},
    "images": {"poster": {"full": "https://img.test/godfather-poster.jpg"}, "fanart": {"full": "https://img.test/godfather-fanart.jpg"}}
  },
  {
    "title": "The Godfather Part II",
    "year": 1974,
    "ids": {"trakt": 2, "slug": "the-godfather-part-ii-1974", "imdb": "tt0071562", "tmdb": 240},
    "images": {"poster": {"medium": "https://img.test/gf2-poster-m.jpg"}}
  },
  {
    "title": "Self reference",
    "year": 2020,
    "ids": {"trakt": 3, "slug": "self", "imdb": "tt1"},
    "images": {}
  }
]
''';

const _tmdbRecommendationsJson = '''
{
  "results": [
    {"id": 238, "title": "TMDB Movie", "poster_path": "/abc.jpg", "backdrop_path": "/def.jpg", "release_date": "2020-05-01"},
    {"id": 240, "name": "TMDB Show", "poster_path": null, "first_air_date": "2021-03-15"}
  ]
}
''';

HttpClient _httpFor(Map<String, String Function(http.Request)> routes) {
  return HttpClient(
    maxRetries: 0,
    client: MockClient((request) async {
      for (final entry in routes.entries) {
        if (request.url.toString().contains(entry.key)) {
          return http.Response(entry.value(request), 200);
        }
      }
      return http.Response('nf', 404);
    }),
  );
}

void main() {
  group('Trakt related (more like this)', () {
    test('fetches and maps related movies with artwork', () async {
      final httpMock = _httpFor({
        '/movies/tt0111161/related': (_) => _traktRelatedJson,
      });
      final trakt = TraktService(httpMock, clientId: 'cid', clientSecret: 'sec');
      final service = MoreLikeThisService(httpMock, trakt: trakt);

      final result = await service.fetchTraktRelated(
        contentId: 'tt0111161',
        contentType: ContentType.movie,
        accessToken: 'token',
      );

      final items = result.valueOrNull!;
      expect(items.length, 3);
      // First item: full mapping.
      expect(items[0].id, 'tt0068646');
      expect(items[0].name, 'The Godfather');
      expect(items[0].poster, 'https://img.test/godfather-poster.jpg');
      expect(items[0].background, 'https://img.test/godfather-fanart.jpg');
      expect(items[0].releaseInfo, '1972');
      // Second: medium poster used as fallback.
      expect(items[1].poster, 'https://img.test/gf2-poster-m.jpg');
    });

    test('series uses /shows/ endpoint', () async {
      Uri? captured;
      final httpMock = _httpFor({
        '/shows/': (request) {
          captured = request.url;
          return '[]';
        },
      });
      final trakt = TraktService(httpMock, clientId: 'cid', clientSecret: 'sec');
      final service = MoreLikeThisService(httpMock, trakt: trakt);

      await service.fetchTraktRelated(
        contentId: 'tt1',
        contentType: ContentType.series,
        accessToken: 'token',
      );
      expect(captured!.path, contains('/shows/'));
    });

    test('imdb: prefix stripped, trakt: slug used', () async {
      final paths = <String>[];
      final httpMock = _httpFor({
        '/movies/': (request) {
          paths.add(request.url.path);
          return '[]';
        },
      });
      final trakt = TraktService(httpMock, clientId: 'cid', clientSecret: 'sec');
      final service = MoreLikeThisService(httpMock, trakt: trakt);

      await service.fetchTraktRelated(
        contentId: 'imdb:tt123',
        contentType: ContentType.movie,
        accessToken: 't',
      );
      await service.fetchTraktRelated(
        contentId: 'trakt:my-slug',
        contentType: ContentType.movie,
        accessToken: 't',
      );
      expect(paths[0], contains('tt123'));
      expect(paths[1], contains('my-slug'));
    });

    test('404 returns empty (not error)', () async {
      final httpMock = HttpClient(
        maxRetries: 0,
        client: MockClient((request) async => http.Response('nf', 404)),
      );
      final trakt = TraktService(httpMock, clientId: 'cid', clientSecret: 'sec');
      final service = MoreLikeThisService(httpMock, trakt: trakt);

      final result = await service.fetchTraktRelated(
        contentId: 'tt1',
        contentType: ContentType.movie,
        accessToken: 't',
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('tmdb: id without lookup returns empty', () async {
      final httpMock = HttpClient(
        maxRetries: 0,
        client: MockClient((request) async => http.Response('[]', 200)),
      );
      final trakt = TraktService(httpMock, clientId: 'cid', clientSecret: 'sec');
      final service = MoreLikeThisService(httpMock, trakt: trakt);

      final result = await service.fetchTraktRelated(
        contentId: 'tmdb:12345',
        contentType: ContentType.movie,
        accessToken: 't',
      );
      expect(result.valueOrNull, isEmpty);
    });
  });

  group('TMDB recommendations', () {
    test('maps results with image URLs', () async {
      final httpMock = _httpFor({
        '/movie/tt1/recommendations': (_) => _tmdbRecommendationsJson,
      });
      final trakt = TraktService(httpMock, clientId: 'c', clientSecret: 's');
      final service = MoreLikeThisService(httpMock, trakt: trakt);

      final result = await service.fetchTmdbRecommendations(
        contentId: 'tt1',
        contentType: ContentType.movie,
        tmdbApiKey: 'key',
        tmdbId: 'tt1',
      );

      final items = result.valueOrNull!;
      expect(items.length, 2);
      expect(items[0].name, 'TMDB Movie');
      expect(items[0].poster, 'https://image.tmdb.org/t/p/w342/abc.jpg');
      expect(items[0].background, 'https://image.tmdb.org/t/p/w780/def.jpg');
      expect(items[0].releaseInfo, '2020');
      expect(items[1].name, 'TMDB Show');
      expect(items[1].poster, isNull);
    });
  });

  group('fetch() source preference', () {
    test('trakt preferred + token -> uses trakt', () async {
      var traktCalled = false;
      var tmdbCalled = false;
      final httpMock = _httpFor({
        '/movies/tt1/related': (_) {
          traktCalled = true;
          return '[]';
        },
        'recommendations': (_) {
          tmdbCalled = true;
          return '{"results":[]}';
        },
      });
      final trakt = TraktService(httpMock, clientId: 'c', clientSecret: 's');
      final service = MoreLikeThisService(httpMock, trakt: trakt);

      await service.fetch(
        contentId: 'tt1',
        contentType: ContentType.movie,
        traktAccessToken: 'token',
        tmdbApiKey: 'tmdbkey',
        tmdbId: '123',
      );
      expect(traktCalled, isTrue);
      // Trakt returned empty -> TMDB fallback kicks in (by design).
      expect(tmdbCalled, isTrue);
    });

    test('no trakt token -> falls to TMDB', () async {
      var tmdbCalled = false;
      final httpMock = _httpFor({
        'recommendations': (_) {
          tmdbCalled = true;
          return '{"results":[]}';
        },
      });
      final trakt = TraktService(httpMock, clientId: 'c', clientSecret: 's');
      final service = MoreLikeThisService(httpMock, trakt: trakt);

      await service.fetch(
        contentId: 'tt1',
        contentType: ContentType.movie,
        tmdbApiKey: 'tmdbkey',
        tmdbId: '123',
      );
      expect(tmdbCalled, isTrue);
    });

    test('neither available -> empty, no crash', () async {
      final httpMock = HttpClient(
        maxRetries: 0,
        client: MockClient((request) async => http.Response('[]', 200)),
      );
      final trakt = TraktService(httpMock, clientId: 'c', clientSecret: 's');
      final service = MoreLikeThisService(httpMock, trakt: trakt);

      final result = await service.fetch(
        contentId: 'tt1',
        contentType: ContentType.movie,
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isEmpty);
    });
  });
}
