import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/network/http_client.dart';
import '../data/remote/nuvio_backend_client.dart';
import '../core/util/result.dart';
import 'settings_controller.dart' show localStoreProvider;

/// Auth state machine for Nuvio account pairing.
enum AuthPhase { loggedOut, pairing, authenticated }

/// Controller for the real-Nuvio device login + session lifecycle.
class AuthController extends AsyncNotifier<NuvioSession?> {
  static const _sessionKey = 'nuvioSession';
  static const _installationKey = 'nuvioInstallationId';

  @override
  Future<NuvioSession?> build() async {
    final store = ref.watch(localStoreProvider);
    final raw = store.getString(_sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return NuvioSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  NuvioBackendClient _client() => ref.read(nuvioBackendClientProvider);

  /// Phase derived from current session state.
  AuthPhase get phase {
    final session = state.valueOrNull;
    if (session == null) return AuthPhase.loggedOut;
    return AuthPhase.authenticated;
  }

  /// Step 1: start pairing. Returns the session to display.
  Future<Result<DeviceLoginSession>> startPairing() async {
    final nonce = _getOrCreateInstallationId();
    final result = await _client().startDeviceLoginSession(
      deviceNonce: nonce,
      deviceName: 'Nuvio TV',
    );
    if (result.isOk) {
      // Stash the nonce for the poll/exchange steps.
      final store = ref.read(localStoreProvider);
      await store.setString('nuvioPairingNonce', nonce);
    }
    return result;
  }

  /// Step 2: poll once.
  Future<Result<DeviceLoginPoll>> pollPairing(DeviceLoginSession session) async {
    final nonce = ref.read(localStoreProvider).getString('nuvioPairingNonce') ?? '';
    return _client().pollDeviceLogin(
      deviceCode: session.deviceCode,
      deviceNonce: nonce,
    );
  }

  /// Step 3: exchange approved code for tokens + persist session.
  Future<Result<NuvioSession>> exchangePairing(DeviceLoginSession session) async {
    final nonce = ref.read(localStoreProvider).getString('nuvioPairingNonce') ?? '';
    final result = await _client().exchangeDeviceLogin(
      code: session.deviceCode,
      deviceNonce: nonce,
    );
    if (result.isOk) {
      await _persistSession(result.valueOrNull!);
    }
    return result;
  }

  /// Manual sync-code path: exchange directly with the typed code.
  Future<Result<NuvioSession>> submitSyncCode(String code) async {
    final nonce = _getOrCreateInstallationId();
    final result = await _client().exchangeDeviceLogin(
      code: code,
      deviceNonce: nonce,
    );
    if (result.isOk) {
      await _persistSession(result.valueOrNull!);
    }
    return result;
  }

  /// Sign out: clear stored session.
  Future<void> signOut() async {
    final store = ref.read(localStoreProvider);
    await store.remove(_sessionKey);
    state = const AsyncData(null);
  }

  Future<void> _persistSession(NuvioSession session) async {
    final store = ref.read(localStoreProvider);
    await store.setString(_sessionKey, jsonEncode(session.toJson()));
    state = AsyncData(session);
  }

  String _getOrCreateInstallationId() {
    final store = ref.read(localStoreProvider);
    var id = store.getString(_installationKey);
    if (id == null || id.isEmpty) {
      id = _generateInstallationId();
      // Fire-and-forget persist; nonce works even if write is slow.
      store.setString(_installationKey, id);
    }
    return id;
  }

  String _generateInstallationId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final suffix = List.generate(
        32, (_) => alphabet[random.nextInt(alphabet.length)]).join();
    return ['nuvio-web-', suffix].join();
  }
}

final nuvioBackendClientProvider = Provider<NuvioBackendClient>((ref) {
  // Real Nuvio backend from AppConfig (official credentials as defaults).
  return NuvioBackendClient(
    HttpClient(),
    backendUrl: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, NuvioSession?>(AuthController.new);
