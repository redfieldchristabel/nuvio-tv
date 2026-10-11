import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart' show AppErrorKind;

void main() {
  group('HttpClient.getJson', () {
    test('returns decoded JSON on 200', () async {
      final client = HttpClient(
        client: MockClient((request) async {
          return http.Response('{"hello": "world"}', 200);
        }),
      );
      final result = await client.getJson(Uri.parse('https://x.test/a'));
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, {'hello': 'world'});
    });

    test('returns null for empty 200 body', () async {
      final client = HttpClient(
        client: MockClient((request) async => http.Response('', 200)),
      );
      final result = await client.getJson(Uri.parse('https://x.test/a'));
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('maps 404 to http error without retry', () async {
      var calls = 0;
      final client = HttpClient(
        client: MockClient((request) async {
          calls++;
          return http.Response('nope', 404);
        }),
      );
      final result = await client.getJson(Uri.parse('https://x.test/a'));
      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.kind, AppErrorKind.http);
      expect(result.errorOrNull!.statusCode, 404);
      expect(calls, 1); // no retry on 4xx
    });

    test('retries 5xx then succeeds', () async {
      var calls = 0;
      final client = HttpClient(
        client: MockClient((request) async {
          calls++;
          if (calls == 1) return http.Response('boom', 500);
          return http.Response('{"ok": true}', 200);
        }),
      );
      final result = await client.getJson(Uri.parse('https://x.test/a'));
      expect(result.isOk, isTrue);
      expect(calls, 2);
    });

    test('exhausts retries on persistent 5xx', () async {
      var calls = 0;
      final client = HttpClient(
        maxRetries: 2,
        client: MockClient((request) async {
          calls++;
          return http.Response('boom', 503);
        }),
      );
      final result = await client.getJson(Uri.parse('https://x.test/a'));
      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.statusCode, 503);
      expect(calls, 3); // initial + 2 retries
    });

    test('maps network failure to network error', () async {
      final client = HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          throw http.ClientException('refused');
        }),
      );
      final result = await client.getJson(Uri.parse('https://x.test/a'));
      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.kind, AppErrorKind.network);
    });

    test('maps invalid JSON to parse error', () async {
      final client = HttpClient(
        maxRetries: 0,
        client: MockClient((request) async => http.Response('{broken', 200)),
      );
      final result = await client.getJson(Uri.parse('https://x.test/a'));
      expect(result.isErr, isTrue);
      expect(result.errorOrNull!.kind, AppErrorKind.parse);
    });
  });

  group('HttpClient.postJson', () {
    test('sends JSON body with content-type', () async {
      Uri? capturedUri;
      Map<String, String>? capturedHeaders;
      String? capturedBody;
      final client = HttpClient(
        client: MockClient((request) async {
          capturedUri = request.url;
          capturedHeaders = request.headers;
          capturedBody = request.body;
          return http.Response('{"done": true}', 200);
        }),
      );
      final result = await client.postJson(
        Uri.parse('https://x.test/submit'),
        body: {'a': 1},
      );
      expect(result.isOk, isTrue);
      expect(capturedUri!.path, '/submit');
      expect(capturedHeaders!['content-type'], 'application/json');
      expect(jsonDecode(capturedBody!), {'a': 1});
    });
  });
}
