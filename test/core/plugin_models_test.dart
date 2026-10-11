import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/plugin/plugin_models.dart';
import 'package:nuvio_tv_flutter/core/plugin/scraper_runner.dart';

void main() {
  group('PluginState.normalize', () {
    test('caps repositories at max', () {
      final repos = List.generate(
        30,
        (i) => PluginRepository(id: 'repo-$i', name: 'R$i', url: 'https://$i.test/'),
      );
      final state = PluginState.normalize(repositories: repos, scrapers: []);
      expect(state.repositories.length, PluginState.maxRepositories);
    });

    test('dedupes repos by url and id', () {
      final state = PluginState.normalize(
        repositories: [
          const PluginRepository(id: 'a', name: 'A', url: 'https://x.test/'),
          const PluginRepository(id: 'a', name: 'A dup', url: 'https://y.test/'),
          const PluginRepository(id: 'b', name: 'B', url: 'https://x.test/'),
          const PluginRepository(id: 'c', name: 'C', url: 'https://z.test/'),
        ],
        scrapers: [],
      );
      expect(state.repositories.length, 2); // a + c (b dup url, a dup id)
    });

    test('drops repos with empty url', () {
      final state = PluginState.normalize(
        repositories: [
          const PluginRepository(id: 'bad', name: 'Bad', url: ''),
          const PluginRepository(id: 'good', name: 'Good', url: 'https://g.test/'),
        ],
        scrapers: [],
      );
      expect(state.repositories.length, 1);
      expect(state.repositories.first.id, 'good');
    });

    test('drops orphan scrapers (repo missing)', () {
      final state = PluginState.normalize(
        repositories: [
          const PluginRepository(id: 'repo-1', name: 'R1', url: 'https://1.test/'),
        ],
        scrapers: [
          const Scraper(id: 's1', repositoryId: 'repo-1', name: 'S1', code: 'x'),
          const Scraper(id: 's2', repositoryId: 'repo-gone', name: 'S2', code: 'y'),
        ],
      );
      expect(state.scrapers.length, 1);
      expect(state.scrapers.first.id, 's1');
    });

    test('dedupes scrapers by repo+id+name', () {
      final state = PluginState.normalize(
        repositories: [
          const PluginRepository(id: 'repo-1', name: 'R1', url: 'https://1.test/'),
        ],
        scrapers: [
          const Scraper(id: 's1', repositoryId: 'repo-1', name: 'S1', code: 'x'),
          const Scraper(id: 's1', repositoryId: 'repo-1', name: 'S1', code: 'y'),
          const Scraper(id: 's2', repositoryId: 'repo-1', name: 'S2', code: 'z'),
        ],
      );
      expect(state.scrapers.length, 2);
    });

    test('caps scrapers at max', () {
      final scrapers = List.generate(
        250,
        (i) => Scraper(
            id: 's-$i', repositoryId: 'repo-1', name: 'S$i', code: 'x'),
      );
      final state = PluginState.normalize(
        repositories: [
          const PluginRepository(id: 'repo-1', name: 'R1', url: 'https://1.test/'),
        ],
        scrapers: scrapers,
      );
      expect(state.scrapers.length, PluginState.maxScrapers);
    });
  });

  group('PluginState JSON round-trip', () {
    test('preserves repos and scrapers', () {
      const original = PluginState(
        repositories: [
          PluginRepository(
              id: 'r1', name: 'Repo', url: 'https://r.test/', scraperCount: 3),
        ],
        scrapers: [
          Scraper(
              id: 's1',
              repositoryId: 'r1',
              name: 'Scraper',
              code: 'function loadLinks(){}',
              version: '1.0'),
        ],
      );
      final restored = PluginState.fromJson(original.toJson());
      expect(restored.repositories.first.id, 'r1');
      expect(restored.repositories.first.scraperCount, 3);
      expect(restored.scrapers.first.code, contains('loadLinks'));
      expect(restored.scrapers.first.version, '1.0');
    });

    test('handles corrupt json gracefully', () {
      final state = PluginState.fromJson(const {});
      expect(state.repositories, isEmpty);
      expect(state.scrapers, isEmpty);
    });
  });

  group('ScraperRunner.decodeScraperResult', () {
    test('parses array of stream maps', () {
      final result = ScraperRunner.decodeScraperResult(
          '[{"name":"4K","url":"https://x/1.mp4"},{"name":"1080p","infoHash":"abc"}]');
      expect(result.length, 2);
      expect(result[0]['url'], 'https://x/1.mp4');
      expect(result[1]['infoHash'], 'abc');
    });

    test('wraps single object into list', () {
      final result =
          ScraperRunner.decodeScraperResult('{"name":"only","url":"https://x"}');
      expect(result.length, 1);
    });

    test('returns empty for null/empty/garbage', () {
      expect(ScraperRunner.decodeScraperResult('null'), isEmpty);
      expect(ScraperRunner.decodeScraperResult(''), isEmpty);
      expect(ScraperRunner.decodeScraperResult('not json'), isEmpty);
      expect(ScraperRunner.decodeScraperResult('{"nested":true}'), isNotEmpty);
    });
  });
}
