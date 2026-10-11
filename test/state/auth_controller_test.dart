import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:nuvio_tv_flutter/data/remote/nuvio_backend_client.dart';
import 'package:nuvio_tv_flutter/state/auth_controller.dart';
import 'package:nuvio_tv_flutter/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalStore store;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.create();
    container = ProviderContainer(overrides: [
      localStoreProvider.overrideWithValue(store),
      nuvioBackendClientProvider.overrideWithValue(
        NuvioBackendClient(
          HttpClient(
            maxRetries: 0,
            client: MockClient((request) async {
              if (request.url.path
                  .contains('start_device_login_session')) {
                return http.Response(
                  '{"deviceCode":"dc1","userCode":"CODE-1234",'
                  '"verificationUriComplete":"https://nuvio.tv/tv-login?c=1234",'
                  '"pollIntervalSeconds":1}',
                  200,
                );
              }
              if (request.url.path.contains('poll_tv_login_session')) {
                return http.Response('{"status":"approved","approved":true}', 200);
              }
              if (request.url.path.contains('tv-logins-exchange')) {
                return http.Response(
                  '{"access_token":"at","refresh_token":"rt",'
                  '"user":{"id":"u1","email":"e@t.com"}}',
                  200,
                );
              }
              return http.Response('nf', 404);
            }),
          ),
          backendUrl: 'https://backend.test',
          publishableKey: 'pk',
        ),
      ),
    ]);
    addTearDown(container.dispose);
  });

  group('AuthController full pairing flow', () {
    test('logged out initially', () async {
      final session = await container.read(authControllerProvider.future);
      expect(session, isNull);
      expect(container.read(authControllerProvider.notifier).phase,
          AuthPhase.loggedOut);
    });

    test('startPairing returns session to display', () async {
      final notifier = container.read(authControllerProvider.notifier);
      final result = await notifier.startPairing();
      final session = result.valueOrNull!;
      expect(session.deviceCode, 'dc1');
      expect(session.userCode, 'CODE-1234');
      expect(session.loginUrl, contains('nuvio.tv'));
    });

    test('full flow: pair -> poll approved -> exchange -> authenticated',
        () async {
      final notifier = container.read(authControllerProvider.notifier);

      final pairing = await notifier.startPairing();
      final session = pairing.valueOrNull!;

      final poll = await notifier.pollPairing(session);
      expect(poll.valueOrNull!.isApproved, isTrue);

      final exchanged = await notifier.exchangePairing(session);
      final authSession = exchanged.valueOrNull!;
      expect(authSession.accessToken, 'at');

      // State now authenticated + persisted.
      expect(container.read(authControllerProvider).valueOrNull!.accessToken,
          'at');
      expect(notifier.phase, AuthPhase.authenticated);

      // Fresh container (restart) still authenticated.
      final container2 = ProviderContainer(overrides: [
        localStoreProvider.overrideWithValue(store),
        nuvioBackendClientProvider.overrideWithValue(
          NuvioBackendClient(HttpClient(maxRetries: 0,
              client: MockClient((r) async => http.Response('nf', 404))),
              backendUrl: 'https://b.test', publishableKey: 'pk'),
        ),
      ]);
      addTearDown(container2.dispose);
      final restored = await container2.read(authControllerProvider.future);
      expect(restored!.accessToken, 'at');
    });

    test('submitSyncCode exchanges directly', () async {
      final notifier = container.read(authControllerProvider.notifier);
      final result = await notifier.submitSyncCode('MANUAL-CODE');
      expect(result.valueOrNull!.accessToken, 'at');
      expect(notifier.phase, AuthPhase.authenticated);
    });

    test('signOut clears session', () async {
      final notifier = container.read(authControllerProvider.notifier);
      await notifier.submitSyncCode('CODE');
      expect(notifier.phase, AuthPhase.authenticated);

      await notifier.signOut();
      expect(container.read(authControllerProvider).valueOrNull, isNull);
      expect(notifier.phase, AuthPhase.loggedOut);
    });

    test('installation id stable across calls', () async {
      final notifier = container.read(authControllerProvider.notifier);
      await notifier.startPairing();
      final id1 = store.getString('nuvioInstallationId');
      await notifier.startPairing();
      final id2 = store.getString('nuvioInstallationId');
      expect(id1, isNotNull);
      expect(id2, id1);
      expect(id1!.startsWith('nuvio-web-'), isTrue);
    });
  });
}
