import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/domain/models/stream.dart';
import 'package:nuvio_tv_flutter/domain/models/video.dart';
import 'package:nuvio_tv_flutter/domain/models/watch_progress.dart';
import 'package:nuvio_tv_flutter/domain/repositories/stream_logic.dart';

Stream _s({
  String? name,
  String? title,
  String? url,
  String? infoHash,
  String? addonName,
  int? orderIndex,
  StreamOriginKind kind = StreamOriginKind.addon,
  String? providerId,
}) {
  return Stream(
    name: name,
    title: title,
    url: url,
    infoHash: infoHash,
    addonName: addonName,
    addonOrderIndex: orderIndex,
    originKind: kind,
    sourceProviderId: providerId,
  );
}

void main() {
  group('QualityDetector', () {
    test('detects resolutions in priority order', () {
      expect(QualityDetector.detect('2160p', null), '4K');
      expect(QualityDetector.detect(null, 'Movie 4K HDR'), '4K');
      expect(QualityDetector.detect('1080p', null), '1080p');
      expect(QualityDetector.detect('720p web', null), '720p');
      expect(QualityDetector.detect('480p', null), '480p');
      expect(QualityDetector.detect('360p', null), '360p');
    });

    test('returns null for unknown', () {
      expect(QualityDetector.detect('some stream', 'no info'), isNull);
      expect(QualityDetector.detect(null, null), isNull);
    });
  });

  group('StreamOrdering', () {
    test('orders by addon index', () {
      final a = _s(name: 'A', orderIndex: 1);
      final b = _s(name: 'B', orderIndex: 0);
      final ordered = StreamOrdering.order([a, b]);
      expect(ordered.first.name, 'B');
    });

    test('unknown index goes last, stable', () {
      final a = _s(name: 'A', orderIndex: 2);
      final b = _s(name: 'B'); // unknown
      final c = _s(name: 'C', orderIndex: 0);
      final ordered = StreamOrdering.order([b, a, c]);
      expect(ordered.map((s) => s.name).toList(), ['C', 'A', 'B']);
    });

    test('groupBySource separates addons and plugins', () {
      final streams = [
        _s(name: '1', addonName: 'Cinemeta', orderIndex: 0),
        _s(name: '2', addonName: 'Torrentio', orderIndex: 1),
        _s(name: '3', kind: StreamOriginKind.plugin, providerId: 'scraper-x'),
      ];
      final groups = StreamOrdering.groupBySource(streams);
      expect(groups.keys.length, 3);
      expect(groups.keys.any((k) => k.startsWith('addon:')), isTrue);
      expect(groups.keys.any((k) => k.startsWith('plugin:')), isTrue);
    });
  });

  group('StreamAutoPlaySelector', () {
    final streams = [
      _s(name: '1080p', title: 'Cinemeta stream', orderIndex: 0),
      _s(name: '4K', title: 'Torrentio 4K', orderIndex: 1),
      _s(
          name: 'plugin pick',
          title: 'Scraper result',
          kind: StreamOriginKind.plugin,
          providerId: 'x'),
    ];

    test('MANUAL never autoplays', () {
      expect(
        StreamAutoPlaySelector.select(
          streams: streams,
          mode: StreamAutoPlaySelector.modeManual,
          source: StreamAutoPlaySelector.sourceAll,
        ),
        isNull,
      );
    });

    test('FIRST_STREAM picks first after ordering', () {
      final pick = StreamAutoPlaySelector.select(
        streams: streams,
        mode: StreamAutoPlaySelector.modeFirstStream,
        source: StreamAutoPlaySelector.sourceAll,
      );
      expect(pick, isNotNull);
      expect(pick!.name, '1080p');
    });

    test('REGEX_MATCH picks matching stream', () {
      final pick = StreamAutoPlaySelector.select(
        streams: streams,
        mode: StreamAutoPlaySelector.modeRegexMatch,
        source: StreamAutoPlaySelector.sourceAll,
        regexPattern: '4K',
      );
      expect(pick, isNotNull);
      expect(pick!.name, '4K');
    });

    test('REGEX no match leaves picker open', () {
      final pick = StreamAutoPlaySelector.select(
        streams: streams,
        mode: StreamAutoPlaySelector.modeRegexMatch,
        source: StreamAutoPlaySelector.sourceAll,
        regexPattern: '8bit-does-not-exist',
      );
      expect(pick, isNull);
    });

    test('source filter: addons only excludes plugins', () {
      final pick = StreamAutoPlaySelector.select(
        streams: streams,
        mode: StreamAutoPlaySelector.modeFirstStream,
        source: StreamAutoPlaySelector.sourceAddonsOnly,
      );
      expect(pick!.originKind, isNot(StreamOriginKind.plugin));
    });

    test('source filter: plugins only excludes addons', () {
      final pick = StreamAutoPlaySelector.select(
        streams: streams,
        mode: StreamAutoPlaySelector.modeFirstStream,
        source: StreamAutoPlaySelector.sourcePluginsOnly,
      );
      expect(pick!.originKind, StreamOriginKind.plugin);
    });

    test('isRegexConfigured rejects junk', () {
      expect(StreamAutoPlaySelector.isRegexConfigured(null), isFalse);
      expect(StreamAutoPlaySelector.isRegexConfigured(''), isFalse);
      expect(StreamAutoPlaySelector.isRegexConfigured('!!!'), isFalse);
      expect(StreamAutoPlaySelector.isRegexConfigured('4K'), isTrue);
      expect(StreamAutoPlaySelector.isRegexConfigured('(?:bad'), isFalse);
    });
  });

  group('WatchProgressPolicy', () {
    test('thresholds match official', () {
      expect(WatchProgressPolicy.isStarted(0.02), isFalse);
      expect(WatchProgressPolicy.isStarted(0.021), isTrue);
      expect(WatchProgressPolicy.isCompleted(0.89), isFalse);
      expect(WatchProgressPolicy.isCompleted(0.90), isTrue);
      // Simkl completes at 80%.
      expect(WatchProgressPolicy.isCompleted(0.85, source: 'simkl_playback'),
          isTrue);
    });

    test('inProgress = started && !completed', () {
      expect(WatchProgressPolicy.isInProgress(0.5), isTrue);
      expect(WatchProgressPolicy.isInProgress(0.01), isFalse);
      expect(WatchProgressPolicy.isInProgress(0.95), isFalse);
    });
  });

  group('ContinueWatchingPolicy', () {
    WatchProgress _p(double fraction, int daysAgo, {String? source}) {
      return WatchProgress(
        contentId: 'tt$fraction$daysAgo',
        contentType: 'movie',
        positionMs: (fraction * 6000000).round(),
        durationMs: 6000000,
        updatedAt: DateTime.now().subtract(Duration(days: daysAgo)),
        source: source,
      );
    }

    test('only in-progress items in window', () {
      final items = [
        _p(0.5, 1), // in progress
        _p(0.01, 1), // not started
        _p(0.95, 1), // completed
      ];
      final window = ContinueWatchingPolicy.renderWindow(items);
      expect(window.length, 1);
    });

    test('excludes items older than maxAge', () {
      final items = [_p(0.5, 40)];
      expect(ContinueWatchingPolicy.renderWindow(items), isEmpty);
    });

    test('newest first', () {
      final items = [_p(0.5, 5), _p(0.4, 1), _p(0.3, 3)];
      final window = ContinueWatchingPolicy.renderWindow(items);
      expect(window.first.contentId, contains('0.4'));
    });

    test('respects limit', () {
      final items = List.generate(30, (i) => _p(0.5, i % 10));
      expect(ContinueWatchingPolicy.renderWindow(items, limit: 20).length, 20);
    });
  });

  group('NextUpResolver', () {
    test('returns first unwatched in season/episode order', () {
      final videos = [
        const Video(id: 's1e3', season: 1, episode: 3),
        const Video(id: 's1e1', season: 1, episode: 1),
        const Video(id: 's1e2', season: 1, episode: 2),
        const Video(id: 's2e1', season: 2, episode: 1),
      ];
      final next = NextUpResolver.nextUp(
        videos: videos,
        watchedVideoIds: {'s1e1', 's1e2'},
      );
      expect(next!.id, 's1e3');
    });

    test('returns first video when nothing watched', () {
      final videos = [
        const Video(id: 's1e2', season: 1, episode: 2),
        const Video(id: 's1e1', season: 1, episode: 1),
      ];
      expect(
          NextUpResolver.nextUp(videos: videos, watchedVideoIds: {})!.id,
          's1e1');
    });

    test('returns null when all watched', () {
      final videos = [const Video(id: 's1e1', season: 1, episode: 1)];
      expect(
        NextUpResolver.nextUp(
            videos: videos, watchedVideoIds: {'s1e1'}),
        isNull,
      );
    });
  });

  group('ImageRepository.sizedUrl', () {
    // sizedUrl lives on the repository; test the static behavior via instance.
    test('TMDB urls get width substitution', () {
      final repo = ImageRepository();
      expect(
        repo.sizedUrl('https://image.tmdb.org/t/p/original/abc.jpg', width: 342),
        'https://image.tmdb.org/t/p/w342/abc.jpg',
      );
      expect(
        repo.sizedUrl('https://example.com/poster.jpg'),
        'https://example.com/poster.jpg',
      );
      expect(repo.sizedUrl(null), isNull);
      expect(repo.sizedUrl(''), isNull);
    });
  });
}
