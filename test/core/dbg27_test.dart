import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/skip/skip_segments.dart';

void main() {
  test('capture', () async {
    final logs = <String>[];
    AnimeSkipProvider.debugCapture = (s) { logs.add(s); return null; };
    var n = 0;
    final provider = AnimeSkipProvider(
      clientId: 'c',
      http: HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          n++;
          if (n == 1) {
            return http.Response('{"data":{"searchShows":{"shows":[{"id":"show-1"}]}}}', 200);
          }
          return http.Response('{"data":{"episodes":{"episodes":[{"id":"e","segments":[{"type":"intro","start":1.0,"end":2.0}]}}]}}', 200);
        }),
      ),
    );
    final segments = await provider.resolve(
      type: 'series', imdbId: 'tt1', season: 1, episode: 3, malId: 1535, episodeLengthSec: 1440,
    );
    logs.add('segments=${segments.length}');
    File('/tmp/dbg27.txt').writeAsStringSync(logs.join('\n'));
  });
}
