import 'dart:convert';

import 'package:nuvio_tv_flutter/core/config/app_config.dart';
import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';

/// Client for the REAL Nuvio backend (Supabase-based).
///
/// This app is a client for the existing Nuvio service — existing users
/// log in and their profiles/library/sync come from Nuvio's own backend.
/// Endpoint shapes mirror the official Tizen client exactly:
///
/// - REST:   {backendUrl}/rest/v1/...        (headers: apikey + Bearer)
/// - RPC:    {backendUrl}/rest/v1/rpc/{fn}   (POST JSON)
/// - Edge:   {backendUrl}/functions/v1/{fn}  (POST JSON)
///
/// Device login (TV pairing), ported from the official qrLoginService:
/// 1. POST /rest/v1/rpc/start_device_login_session
///    {p_device_nonce, p_redirect_base_url, p_device_type, p_device_name}
///    -> {deviceCode, userCode, verificationUriComplete, pollIntervalSeconds}
/// 2. POST /rest/v1/rpc/poll_tv_login_session  (while pending)
/// 3. POST /functions/v1/tv-logins-exchange {code, device_nonce}
///    -> {access_token, refresh_token}
class NuvioBackendClient {
  NuvioBackendClient(
    this._http, {
    String? backendUrl,
    String? publishableKey,
  })  : _backendUrlOverride = backendUrl,
        _publishableKeyOverride = publishableKey;

  final HttpClient _http;
  final String? _backendUrlOverride;
  final String? _publishableKeyOverride;

  String get _backendUrl => (_backendUrlOverride ?? AppConfig.supabaseUrl)
      .replaceAll(RegExp(r'/+$'), '');
  String get _publishableKey =>
      _publishableKeyOverride ?? AppConfig.supabaseAnonKey;

  Map<String, String> _headers({String? accessToken}) => {
        'Content-Type': 'application/json',
        'apikey': _publishableKey,
        'Authorization': 'Bearer ${accessToken ?? _publishableKey}',
      };

  bool get isConfigured => _backendUrl.isNotEmpty && _publishableKey.isNotEmpty;

  // ---- generic Supabase operations ----

  /// POST {backend}/rest/v1/rpc/{function}
  Future<Result<dynamic>> rpc(
    String functionName,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    if (!isConfigured) return Result.err(AppError.unknown('Backend not configured'));
    return _http.postJson(
      Uri.parse('$_backendUrl/rest/v1/rpc/$functionName'),
      body: body,
      headers: _headers(accessToken: accessToken),
    );
  }

  /// GET {backend}/rest/v1/{table}?{query}
  Future<Result<dynamic>> select(
    String table,
    String query, {
    String? accessToken,
  }) async {
    if (!isConfigured) return Result.err(AppError.unknown('Backend not configured'));
    final suffix = query.isEmpty ? '' : '?$query';
    return _http.getJson(
      Uri.parse('$_backendUrl/rest/v1/$table$suffix'),
      headers: _headers(accessToken: accessToken),
    );
  }

  /// POST {backend}/rest/v1/{table} (upsert with merge-duplicates)
  Future<Result<dynamic>> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    String? onConflict,
    String? accessToken,
  }) async {
    if (!isConfigured) return Result.err(AppError.unknown('Backend not configured'));
    final query = onConflict == null ? '' : '?on_conflict=${Uri.encodeComponent(onConflict)}';
    return _http.postJson(
      Uri.parse('$_backendUrl/rest/v1/$table$query'),
      body: rows,
      headers: {
        ..._headers(accessToken: accessToken),
        'Prefer': 'resolution=merge-duplicates,return=representation',
      },
    );
  }

  // ---- device login (TV pairing) ----

  /// Step 1: start a device login session.
  ///
  /// The live backend uses the legacy RPC `start_tv_login_session` with a
  /// 3-param signature (nonce, redirect, name) returning a LIST with
  /// {code, web_url, expires_at, poll_interval_seconds}. The modern
  /// `start_device_login_session` (4 params, object response) is tried
  /// first and we fall back on "function not found".
  Future<Result<DeviceLoginSession>> startDeviceLoginSession({
    required String deviceNonce,
    String deviceType = 'tv',
    String? deviceName,
  }) async {
    if (!isConfigured) {
      return Result.err(AppError.unknown('Backend not configured'));
    }
    final modern = await rpc(
      'start_device_login_session',
      {
        'p_device_nonce': deviceNonce,
        'p_redirect_base_url': AppConfig.tvLoginWebBaseUrl,
        'p_device_type': deviceType,
        if (deviceName != null && deviceName.isNotEmpty)
          'p_device_name': deviceName,
      },
    );
    // Modern path succeeded with an object?
    if (modern.isOk) {
      final value = modern.valueOrNull;
      if (value is Map<String, dynamic>) {
        return _parseLoginSession(value);
      }
    }
    // Legacy path: 3 params, list response.
    final legacy = await rpc(
      'start_tv_login_session',
      {
        'p_device_nonce': deviceNonce,
        'p_redirect_base_url': AppConfig.tvLoginWebBaseUrl,
        if (deviceName != null && deviceName.isNotEmpty)
          'p_device_name': deviceName,
      },
    );
    return switch (legacy) {
      Ok(:final value) => _parseLegacySession(value),
      Err(:final error) => Result.err(error),
    };
  }

  Result<DeviceLoginSession> _parseLoginSession(Map<String, dynamic> value) {
    final deviceCode = (value['deviceCode'] ?? value['device_code']) as String?;
    final userCode = (value['userCode'] ?? value['user_code']) as String?;
    final loginUrl = (value['verificationUriComplete'] ??
            value['verification_uri_complete']) as String?;
    if (deviceCode == null || userCode == null || loginUrl == null) {
      return Result.err(AppError.parse('Incomplete device login session'));
    }
    return Result.ok(DeviceLoginSession(
      deviceCode: deviceCode,
      userCode: userCode,
      loginUrl: loginUrl,
      verificationUri:
          (value['verificationUri'] ?? value['verification_uri']) as String?,
      pollIntervalSeconds: ((value['pollIntervalSeconds'] ??
                  value['poll_interval_seconds']) as num?)
              ?.toInt() ??
          3,
    ));
  }

  Result<DeviceLoginSession> _parseLegacySession(dynamic value) {
    // Legacy returns a LIST: [{code, web_url, expires_at, poll_interval_seconds}]
    Map<String, dynamic>? entry;
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map<String, dynamic>) entry = first;
    } else if (value is Map<String, dynamic>) {
      entry = value;
    }
    if (entry == null) {
      return Result.err(AppError.parse('Empty device login response'));
    }
    final code = (entry['code'] ?? entry['deviceCode']) as String?;
    final webUrl = (entry['web_url'] ??
            entry['verificationUriComplete'] ??
            entry['verification_uri_complete']) as String?;
    if (code == null || code.isEmpty || webUrl == null || webUrl.isEmpty) {
      return Result.err(AppError.parse('Incomplete device login session'));
    }
    return Result.ok(DeviceLoginSession(
      deviceCode: code,
      userCode: code, // legacy uses the code as the display code
      loginUrl: webUrl,
      verificationUri: AppConfig.tvLoginWebBaseUrl,
      pollIntervalSeconds:
          (entry['poll_interval_seconds'] as num?)?.toInt() ?? 3,
    ));
  }

  /// Step 2: poll status. Returns [DeviceLoginPoll.pending] until approved.
  Future<Result<DeviceLoginPoll>> pollDeviceLogin({
    required String deviceCode,
    required String deviceNonce,
    String? accessToken,
  }) async {
    final result = await rpc(
      'poll_tv_login_session',
      {
        'p_code': deviceCode,
        'p_device_nonce': deviceNonce,
      },
      accessToken: accessToken,
    );
    // Live backend returns a LIST: [{status, expires_at, poll_interval_seconds}]
    if (result.isOk) {
      final value = result.valueOrNull;
      Map<String, dynamic>? entry;
      if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
        entry = value.first as Map<String, dynamic>;
      } else if (value is Map<String, dynamic>) {
        entry = value;
      }
      if (entry != null) {
        final status = (entry['status'] as String?) ?? 'pending';
        return Result.ok(DeviceLoginPoll(
          status: status,
          approved: status == 'approved' || entry['approved'] == true,
        ));
      }
      return Result.ok(const DeviceLoginPoll(status: 'pending'));
    }
    return Result.err(result.errorOrNull!);
  }

  /// Step 3: exchange the approved code for session tokens.
  Future<Result<NuvioSession>> exchangeDeviceLogin({
    required String code,
    required String deviceNonce,
    String? accessToken,
  }) async {
    if (!isConfigured) return Result.err(AppError.unknown('Backend not configured'));
    final result = await _http.postJson(
      Uri.parse('$_backendUrl/functions/v1/tv-logins-exchange'),
      body: {'code': code, 'device_nonce': deviceNonce},
      headers: _headers(accessToken: accessToken),
    );
    return switch (result) {
      Ok(:final value) when value is Map<String, dynamic> =>
        _parseSession(value),
      Ok() => Result.err(AppError.parse('Exchange missing session tokens')),
      Err(:final error) => Result.err(error),
    };
  }

  Result<NuvioSession> _parseSession(Map<String, dynamic> value) {
    final access = (value['access_token'] ??
            (value['session'] as Map<String, dynamic>?)?['access_token'])
        as String?;
    final refresh = (value['refresh_token'] ??
            (value['session'] as Map<String, dynamic>?)?['refresh_token'])
        as String?;
    if (access == null || access.isEmpty) {
      return Result.err(AppError.parse('Exchange missing access token'));
    }
    return Result.ok(NuvioSession(
      accessToken: access,
      refreshToken: refresh ?? '',
      user: value['user'] is Map<String, dynamic>
          ? NuvioUser.fromJson(value['user'] as Map<String, dynamic>)
          : null,
    ));
  }

  // ---- member profile / cloud library ----

  /// Fetch the signed-in user's profiles (member catalog).
  Future<Result<List<Map<String, dynamic>>>> fetchProfiles(
      String accessToken) async {
    final result = await select(
      'profiles',
      'select=*&order=created_at.asc',
      accessToken: accessToken,
    );
    return switch (result) {
      Ok(:final value) when value is List => Result.ok(
          value.whereType<Map<String, dynamic>>().toList(),
        ),
      Ok() => Result.ok(const []),
      Err(:final error) => Result.err(error),
    };
  }

  /// Fetch cloud library rows for the user.
  Future<Result<List<Map<String, dynamic>>>> fetchCloudLibrary(
      String accessToken) async {
    final result = await select('library_items', 'select=*',
        accessToken: accessToken);
    return switch (result) {
      Ok(:final value) when value is List => Result.ok(
          value.whereType<Map<String, dynamic>>().toList(),
        ),
      Ok() => Result.ok(const []),
      Err(:final error) => Result.err(error),
    };
  }

  /// Push watch progress to the cloud (upsert).
  Future<Result<bool>> upsertWatchProgress(
    String accessToken,
    Map<String, dynamic> progressRow,
  ) async {
    final result = await upsert(
      'watch_progress',
      [progressRow],
      onConflict: 'content_id,video_id',
      accessToken: accessToken,
    );
    return Result.ok(result.isOk);
  }
}

/// A pending device login session (step 1 result).
class DeviceLoginSession {
  const DeviceLoginSession({
    required this.deviceCode,
    required this.userCode,
    required this.loginUrl,
    this.verificationUri,
    this.pollIntervalSeconds = 3,
  });

  final String deviceCode;
  final String userCode;
  final String loginUrl;
  final String? verificationUri;
  final int pollIntervalSeconds;
}

/// Poll result for step 2.
class DeviceLoginPoll {
  const DeviceLoginPoll({required this.status, this.approved = false});

  final String status;
  final bool approved;

  bool get isPending => !approved && status == 'pending';
  bool get isApproved => approved || status == 'approved';
}

/// Session tokens + user after successful exchange.
class NuvioSession {
  const NuvioSession({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });

  final String accessToken;
  final String refreshToken;
  final NuvioUser? user;

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        if (user != null) 'user': user!.toJson(),
      };

  factory NuvioSession.fromJson(Map<String, dynamic> json) => NuvioSession(
        accessToken: (json['accessToken'] as String?) ?? '',
        refreshToken: (json['refreshToken'] as String?) ?? '',
        user: json['user'] == null
            ? null
            : NuvioUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// Minimal user identity from the backend.
class NuvioUser {
  const NuvioUser({
    required this.id,
    this.email,
    this.displayName,
  });

  final String id;
  final String? email;
  final String? displayName;

  factory NuvioUser.fromJson(Map<String, dynamic> json) => NuvioUser(
        id: (json['id'] as String?) ?? '',
        email: json['email'] as String?,
        displayName:
            (json['display_name'] ?? json['name']) as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
      };
}

/// Generates a device nonce (32 lowercase alphanumerics), matching the
/// official installation-id alphabet.
String generateDeviceNonce() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = DateTime.now().microsecondsSinceEpoch;
  return List.generate(
    32,
    (i) => alphabet[(rand >> (i % 30)) & 0x1f % alphabet.length],
  ).join();
}

/// JSON helpers re-exported for tests.
Map<String, dynamic> decodeJsonObject(String raw) {
  final value = jsonDecode(raw);
  return value is Map<String, dynamic> ? value : const {};
}
