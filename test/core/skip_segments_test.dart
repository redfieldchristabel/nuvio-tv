import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/skip/skip_segments.dart';

void main() {
  group('SkipSegment', () {
    test('contains() covers [start, end)', () {
      const segment = SkipSegment(
        type: SkipSegmentType.intro,
        startMs: 10000,
        endMs: 90000,
        source: 'x',
      );
      expect(segment.contains(const Duration(seconds: 10)), isTrue);
      expect(segment.contains(const Duration(seconds: 89)), isTrue);
      expect(segment.contains(const Duration(seconds: 90)), isFalse);
      expect(segment.contains(const Duration(seconds: 5)), isFalse);
    });

    test('json round-trip', () {
      const segment = SkipSegment(
        type: SkipSegmentType.recap,
        startMs: 5000,
        endMs: 30000,
        source: 'aniskip',
        confidence: 0.8,
      );
      final restored = SkipSegment.fromJson(segment.toJson());
      expect(restored.type, SkipSegmentType.recap);
      expect(restored.startMs, 5000);
      expect(restored.endMs, 30000);
      expect(restored.source, 'aniskip');
      expect(restored.confidence, 0.8);
    });
  });

  group('SkipSegmentsService helpers', () {
    late SkipSegmentsService svc;

    setUp(() => svc = SkipSegmentsService(providers: const []));

    test('activeAt picks the covering segment', () {
      final segments = [
        SkipSegment(type: SkipSegmentType.intro, startMs: 0, endMs: 50000, source: 'x'),
        SkipSegment(type: SkipSegmentType.outro, startMs: 900000, endMs: 960000, source: 'x'),
      ];
      expect(svc.activeAt(segments, const Duration(seconds: 20))?.type,
          SkipSegmentType.intro);
      expect(svc.activeAt(segments, const Duration(minutes: 15, seconds: 30))?.type,
          SkipSegmentType.outro);
      expect(svc.activeAt(segments, const Duration(minutes: 5)), isNull);
    });

    test('upcoming finds the nearest start within lookahead', () {
      final segments = [
        SkipSegment(type: SkipSegmentType.intro, startMs: 60000, endMs: 120000, source: 'x'),
      ];
      expect(svc.upcoming(segments, const Duration(seconds: 58))?.startMs, 60000);
      expect(svc.upcoming(segments, const Duration(seconds: 30)), isNull);
    });

    test('caches repeated lookups', () async {
      var calls = 0;
      final svc2 = SkipSegmentsService(providers: [
        _CountingProvider(() => calls++),
      ]);
      await svc2.getSegments(type: 'series', imdbId: 'tt1', season: 1, episode: 1, malId: null);
      await svc2.getSegments(type: 'series', imdbId: 'tt1', season: 1, episode: 1, malId: null);
      expect(calls, 1);
    });
  });

  group('SkipSegmentsService aggregation', () {
    test('merges segments from multiple providers', () async {
      final service = SkipSegmentsService(providers: [
        _FakeProvider('a', [
          const SkipSegment(
              type: SkipSegmentType.intro,
              startMs: 0,
              endMs: 90000,
              source: 'a'),
        ]),
        _FakeProvider('b', [
          const SkipSegment(
              type: SkipSegmentType.outro,
              startMs: 1200000,
              endMs: 1320000,
              source: 'b'),
        ]),
      ]);
      final segments = await service.getSegments(
        type: 'series',
        imdbId: 'tt1',
        season: 1,
        episode: 1,
        malId: null,
      );
      expect(segments.length, 2);
      expect(segments.any((s) => s.source == 'a'), isTrue);
      expect(segments.any((s) => s.source == 'b'), isTrue);
    });

    test('provider failure does not break aggregation', () async {
      final service = SkipSegmentsService(providers: [
        _FailingProvider(),
        _FakeProvider('b', [
          const SkipSegment(
              type: SkipSegmentType.intro,
              startMs: 0,
              endMs: 90000,
              source: 'b'),
        ]),
      ]);
      final segments = await service.getSegments(
        type: 'series',
        imdbId: 'tt1',
        season: 1,
        episode: 1,
        malId: null,
      );
      expect(segments.length, 1);
      expect(segments.first.source, 'b');
    });
  });

  group('AnimeSkipProvider (GraphQL)', () {
    test('searches show by MAL id then fetches episode segments', () async {
      var callCount = 0;
      final provider = AnimeSkipProvider(
        clientId: 'test-client',
        http: HttpClient(
          maxRetries: 0,
          client: MockClient((request) async {
            callCount++;
            expect(request.headers['X-Client-ID'], 'test-client');
            final body = request.body;
            if (callCount == 1) {
              expect(body, contains('searchShows'));
              expect(body, contains('MAL'));
              return http.Response(
                '{"data":{"searchShows":{"shows":[{"id":"show-1"}]}}}',
                200,
              );
            }
            expect(body, contains('episodes'));
            return http.Response(
              '{"data":{"episodes":{"episodes":[{"id":"ep-1","segments":'
              '[{"type":"intro","start":10.5,"end":95.0},'
              '{"type":"credits","start":1200.0,"end":1320.0}]}]}}}',
              200,
            );
          }),
        ),
      );

      final segments = await provider.resolve(
        type: 'series',
        imdbId: 'tt1',
        season: 1,
        episode: 3,
        malId: 1535,
        episodeLengthSec: 1440,
      );

      expect(callCount, 2);
      expect(segments.length, 2);
      expect(segments[0].type, SkipSegmentType.intro);
      expect(segments[0].startMs, 10500);
      expect(segments[0].endMs, 95000);
      expect(segments[0].source, 'anime-skip');
      expect(segments[1].type, SkipSegmentType.outro);
    });

    test('returns empty when no MAL id (no HTTP)', () async {
      var called = false;
      final provider = AnimeSkipProvider(
        clientId: 'c',
        http: HttpClient(
          maxRetries: 0,
          client: MockClient((request) async {
            called = true;
            return http.Response('{}', 200);
          }),
        ),
      );
      final segments = await provider.resolve(
        type: 'series',
        imdbId: null,
        season: null,
        episode: null,
        malId: null,
        episodeLengthSec: null,
      );
      expect(segments, isEmpty);
      expect(called, isFalse);
    });

    test('returns empty when show not found', () async {
      final provider = AnimeSkipProvider(
        clientId: 'c',
        http: HttpClient(
          maxRetries: 0,
          client: MockClient((request) async =>
              http.Response('{"data":{"searchShows":{"shows":[]}}}', 200)),
        ),
      );
      final segments = await provider.resolve(
        type: 'series',
        imdbId: 'tt1',
        season: 1,
        episode: 1,
        malId: 999999,
        episodeLengthSec: null,
      );
      expect(segments, isEmpty);
    });

    test('maps all AnimeSkip segment types', () async {
      final provider = AnimeSkipProvider(
        clientId: 'c',
        http: HttpClient(
          maxRetries: 0,
          client: MockClient((request) async {
            final body = request.body;
            if (body.contains('searchShows')) {
              return http.Response(
                '{"data":{"searchShows":{"shows":[{"id":"s"}]}}}',
                200,
              );
            }
            return http.Response(
              '{"data":{"episodes":{"episodes":[{"id":"e","segments":['
              '{"type":"op","start":0,"end":90},'
              '{"type":"ed","start":1300,"end":1390},'
              '{"type":"recap","start":90,"end":120},'
              '{"type":"preview","start":1390,"end":1440},'
              '{"type":"mixed-op","start":30,"end":100},'
              '{"type":"mixed-ed","start":200,"end":260},'
              '{"type":"unknown-type","start":500,"end":510}'
              ']}]}}}',
              200,
            );
          }),
        ),
      );
      final segments = await provider.resolve(
        type: 'series',
        imdbId: 'tt1',
        season: 1,
        episode: 1,
        malId: 1,
        episodeLengthSec: null,
      );
      final types = segments.map((s) => s.type).toSet();
      expect(types, containsAll([
        SkipSegmentType.intro, // op
        SkipSegmentType.outro, // ed
        SkipSegmentType.recap,
        SkipSegmentType.preview,
        SkipSegmentType.mixedOp,
        SkipSegmentType.mixedEd,
      ]));
      expect(segments.length, 7); // unknown maps to intro
    });

    test('skips malformed segments (null/invalid times)', () async {
      final provider = AnimeSkipProvider(
        clientId: 'c',
        http: HttpClient(
          maxRetries: 0,
          client: MockClient((request) async {
            final body = request.body;
            if (body.contains('searchShows')) {
              return http.Response(
                '{"data":{"searchShows":{"shows":[{"id":"s"}]}}}',
                200,
              );
            }
            return http.Response(
              '{"data":{"episodes":{"episodes":[{"id":"e","segments":['
              '{"type":"intro","start":null,"end":90},'
              '{"type":"intro","start":100,"end":50},'
              '{"type":"intro","start":10,"end":20}'
              ']}]}}}',
              200,
            );
          }),
        ),
      );
      final segments = await provider.resolve(
        type: 'series',
        imdbId: 'tt1',
        season: 1,
        episode: 1,
        malId: 1,
        episodeLengthSec: null,
      );
      expect(segments.length, 1); // only the valid one
    });
  });
}

class _CountingProvider implements SkipSegmentProvider {
  _CountingProvider(this.onResolve);

  final void Function() onResolve;

  @override
  String get name => 'counting';

  @override
  Future<List<SkipSegment>> resolve({
    required String type,
    required String? imdbId,
    required int? season,
    required int? episode,
    required int? malId,
    required int? episodeLengthSec,
  }) async {
    onResolve();
    return const [
      SkipSegment(
          type: SkipSegmentType.intro,
          startMs: 0,
          endMs: 90000,
          source: 'counting'),
    ];
  }
}

class _FakeProvider implements SkipSegmentProvider {
  _FakeProvider(this.name, this.segments, {this.onResolve});

  @override
  final String name;
  final List<SkipSegment> segments;
  final void Function()? onResolve;

  @override
  Future<List<SkipSegment>> resolve({
    required String type,
    required String? imdbId,
    required int? season,
    required int? episode,
    required int? malId,
    required int? episodeLengthSec,
  }) async {
    onResolve?.call();
    return segments;
  }
}

class _FailingProvider implements SkipSegmentProvider {
  @override
  String get name => 'failing';

  @override
  Future<List<SkipSegment>> resolve({
    required String type,
    required String? imdbId,
    required int? season,
    required int? episode,
    required int? malId,
    required int? episodeLengthSec,
  }) async {
    throw Exception('provider down');
  }
}
