import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/core/debrid/debrid_service.dart';

void main() {
  group('DebridProvider registry', () {
    test('all three providers present', () {
      expect(DebridProvider.all.length, 3);
      expect(DebridProvider.byId(DebridProviderId.torbox), isNotNull);
      expect(DebridProvider.byId(DebridProviderId.premiumize), isNotNull);
      expect(DebridProvider.byId(DebridProviderId.realdebrid), isNotNull);
    });

    test('capability matrix matches official', () {
      final torbox = DebridProvider.byId(DebridProviderId.torbox)!;
      expect(torbox.supports(DebridCapability.cloudLibrary), isTrue);
      expect(torbox.supports(DebridCapability.localTorrentResolve), isTrue);
      expect(torbox.authMethod, DebridAuthMethod.deviceCode);

      final rd = DebridProvider.byId(DebridProviderId.realdebrid)!;
      expect(rd.supports(DebridCapability.cloudLibrary), isFalse);
      expect(rd.authMethod, DebridAuthMethod.apiKey);

      final pm = DebridProvider.byId(DebridProviderId.premiumize)!;
      expect(pm.supports(DebridCapability.localTorrentCacheCheck), isTrue);
    });

    test('short names match official', () {
      expect(DebridProvider.byId(DebridProviderId.torbox)!.shortName, 'TB');
      expect(
          DebridProvider.byId(DebridProviderId.premiumize)!.shortName, 'PM');
      expect(
          DebridProvider.byId(DebridProviderId.realdebrid)!.shortName, 'RD');
    });
  });

  group('DebridAccount', () {
    test('premium status from expiry date', () {
      final future = DebridAccount(
        providerId: DebridProviderId.realdebrid,
        apiKey: 'key',
        premiumUntil: DateTime.now().add(const Duration(days: 30)),
      );
      final past = DebridAccount(
        providerId: DebridProviderId.realdebrid,
        apiKey: 'key',
        premiumUntil: DateTime.now().subtract(const Duration(days: 1)),
      );
      final unknown = DebridAccount(
        providerId: DebridProviderId.realdebrid,
        apiKey: 'key',
      );
      expect(future.isPremium, isTrue);
      expect(past.isPremium, isFalse);
      expect(unknown.isPremium, isTrue); // unknown = assume yes
    });

    test('json round-trip', () {
      final account = DebridAccount(
        providerId: DebridProviderId.torbox,
        apiKey: 'secret',
        userEmail: 'me@test.com',
        premiumUntil: DateTime(2027, 1, 1),
        connectedAt: DateTime(2026, 10, 11),
      );
      final restored = DebridAccount.fromJson(account.toJson());
      expect(restored.providerId, DebridProviderId.torbox);
      expect(restored.apiKey, 'secret');
      expect(restored.userEmail, 'me@test.com');
      expect(restored.premiumUntil, DateTime(2027, 1, 1));
    });
  });

  group('maskApiKey', () {
    test('keeps first and last 4', () {
      expect(maskApiKey('ABCDEFGHIJKLMNOP'), 'ABCD••••MNOP');
    });

    test('short keys fully masked', () {
      expect(maskApiKey('short'), '••••');
      expect(maskApiKey('12345678'), '••••');
    });
  });
}
