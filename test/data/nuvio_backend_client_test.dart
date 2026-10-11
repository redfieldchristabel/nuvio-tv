import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/data/remote/nuvio_backend_client.dart';

void main() {
  group('Device login flow (real Nuvio backend)', () {
    test('start returns session with code + url', () async {
      final client = NuvioBackendClient(
        HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          expect(request.url.path, contains('/rpc/start_device_login_session'));
          final body = request.body;
          expect(body, contains('p_device_nonce'));
          expect(body, contains('p_device_type'));
          return http.Response(
            '{"deviceCode":"dc123","userCode":"ABCD-EFGH",'
            '"verificationUriComplete":"https://nuvio.tv/tv-login?code=ABCD",'
            '"pollIntervalSeconds":3}',
            200,
          );
        }),
      ), backendUrl: 'https://nuvio-backend.test', publishableKey: 'pk_test');

      final result = await client.startDeviceLoginSession(
        deviceNonce: 'nonce123',
        deviceName: 'Nuvio TV Flutter',
      );
      final session = result.valueOrNull!;
      expect(session.deviceCode, 'dc123');
      expect(session.userCode, 'ABCD-EFGH');
      expect(session.loginUrl, contains('nuvio.tv/tv-login'));
      expect(session.pollIntervalSeconds, 3);
    });

    test('poll returns pending until approved', () async {
      var callCount = 0;
      final client = NuvioBackendClient(
        HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            return http.Response('{"status":"pending"}', 200);
          }
          return http.Response('{"status":"approved","approved":true}', 200);
        }),
      ), backendUrl: 'https://nuvio-backend.test', publishableKey: 'pk_test');

      final first = await client.pollDeviceLogin(
          deviceCode: 'dc', deviceNonce: 'n');
      expect(first.valueOrNull!.isPending, isTrue);
      expect(first.valueOrNull!.isApproved, isFalse);

      final second = await client.pollDeviceLogin(
          deviceCode: 'dc', deviceNonce: 'n');
      expect(second.valueOrNull!.isApproved, isTrue);
    });

    test('exchange returns session tokens', () async {
      final client = NuvioBackendClient(
        HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          expect(
              request.url.path, contains('/functions/v1/tv-logins-exchange'));
          expect(request.body, contains('"code"'));
          expect(request.body, contains('"device_nonce"'));
          return http.Response(
            '{"access_token":"at123","refresh_token":"rt456",'
            '"user":{"id":"u1","email":"me@test.com"}}',
            200,
          );
        }),
      ), backendUrl: 'https://nuvio-backend.test', publishableKey: 'pk_test');

      final result = await client.exchangeDeviceLogin(
        code: 'dc123',
        deviceNonce: 'n',
      );
      final session = result.valueOrNull!;
      expect(session.accessToken, 'at123');
      expect(session.refreshToken, 'rt456');
      expect(session.user!.email, 'me@test.com');
    });

    test('exchange with missing tokens errors', () async {
      final client = NuvioBackendClient(
        HttpClient(
        maxRetries: 0,
        client: MockClient((request) async =>
            http.Response('{"error":"no session"}', 200)),
      ));
      final result = await client.exchangeDeviceLogin(
          code: 'x', deviceNonce: 'n');
      expect(result.isErr, isTrue);
    });
  });

  group('Profile + library sync', () {
    test('fetchProfiles parses list', () async {
      final client = NuvioBackendClient(
        HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          expect(request.url.path, contains('/rest/v1/profiles'));
          expect(request.headers['apikey'], isNotEmpty);
          return http.Response(
            '[{"id":"p1","name":"Main"},{"id":"p2","name":"Kids"}]',
            200,
          );
        }),
      ), backendUrl: 'https://nuvio-backend.test', publishableKey: 'pk_test');
      final result = await client.fetchProfiles('token');
      expect(result.valueOrNull!.length, 2);
      expect(result.valueOrNull!.first['name'], 'Main');
    });

    test('upsertWatchProgress sends merge-duplicates prefer', () async {
      Map<String, String>? capturedHeaders;
      final client = NuvioBackendClient(
        HttpClient(
        maxRetries: 0,
        client: MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response('[]', 200);
        }),
      ), backendUrl: 'https://nuvio-backend.test', publishableKey: 'pk_test');
      final result = await client.upsertWatchProgress('token', {
        'content_id': 'tt1',
        'position_ms': 500,
      });
      expect(result.valueOrNull, isTrue);
      expect(capturedHeaders!['Prefer'], contains('merge-duplicates'));
    });
  });

  group('generateDeviceNonce', () {
    test('32 lowercase alphanumeric chars', () {
      final nonce = generateDeviceNonce();
      expect(nonce.length, 32);
      expect(RegExp(r'^[a-z0-9]+$').hasMatch(nonce), isTrue);
    });
  });
}
