import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/skip/skip_segments.dart';

void main() {
  group('SkipSegment', () {
    test('contains() covers [start, end)', () {
      final s = SkipSegment(
          type: SkipSegmentType.intro,
          startMs: 10000,
          endMs: 60000,
          source: 'test');
      expect(s.contains(const Duration(seconds: 10)), isTrue);
      expect(s.contains(const Duration(seconds: 30)), isTrue);
      expect(s.contains(const Duration(seconds: 60)), isFalse); // exclusive end
      expect(s.contains(const Duration(seconds: 5)), isFalse);
    });

    test('json round-trip', () {
      final s = SkipSegment(
          type: SkipSegmentType.ed,
          startMs: 100,
          endMs: 200,
          source: 'aniskip',
          confidence: 0.9);
      final back = SkipSegment.fromJson(s.toJson());
      expect(back.type, SkipSegmentType.ed);
      expect(back.startMs, 100);
      expect(back.endMs, 200);
      expect(back.source, 'aniskip');
      expect(back.confidence, 0.9);
    });
  });

  group('SkipSegmentsService', () {
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
        SkipSegment(type: SkipSegmentType.op, startMs: 100000, endMs: 160000, source: 'x'),
      ];
      expect(svc.upcoming(segments, const Duration(seconds: 97))?.type,
          SkipSegmentType.op);
      expect(svc.upcoming(segments, const Duration(seconds: 90)), isNull); // 10s away
      expect(svc.upcoming(segments, const Duration(seconds: 120)), isNull); // already in
    });

    test('caches repeated lookups', () async {
      var calls = 0;
      final counting = SkipSegmentsService(providers: [
        _CountingProvider(() => calls++),
      ]);
      await counting.getSegments(type: 'series', imdbId: 'tt1', season: 1, episode: 1);
      await counting.getSegments(type: 'series', imdbId: 'tt1', season: 1, episode: 1);
      expect(calls, 1); // second call served from cache
    });
  });
}

class _CountingProvider implements SkipSegmentProvider {
  _CountingProvider(this.onCall);
  final void Function() onCall;
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
    onCall();
    return const [];
  }
}
