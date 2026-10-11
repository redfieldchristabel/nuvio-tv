import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';

/// Debrid provider descriptors, ported from the official clients'
/// debridProviders.js capability matrix.
enum DebridProviderId { torbox, premiumize, realdebrid }

enum DebridAuthMethod { apiKey, deviceCode }

enum DebridCapability {
  clientResolve,
  localTorrentCacheCheck,
  localTorrentResolve,
  cloudLibrary,
}

class DebridProvider {
  const DebridProvider({
    required this.id,
    required this.displayName,
    required this.shortName,
    required this.authMethod,
    required this.capabilities,
    this.visibleInUi = true,
  });

  final DebridProviderId id;
  final String displayName;
  final String shortName;
  final DebridAuthMethod authMethod;
  final List<DebridCapability> capabilities;
  final bool visibleInUi;

  bool supports(DebridCapability capability) =>
      capabilities.contains(capability);

  static const all = <DebridProvider>[
    DebridProvider(
      id: DebridProviderId.torbox,
      displayName: 'Torbox',
      shortName: 'TB',
      authMethod: DebridAuthMethod.deviceCode,
      capabilities: [
        DebridCapability.clientResolve,
        DebridCapability.localTorrentCacheCheck,
        DebridCapability.localTorrentResolve,
        DebridCapability.cloudLibrary,
      ],
    ),
    DebridProvider(
      id: DebridProviderId.premiumize,
      displayName: 'Premiumize',
      shortName: 'PM',
      authMethod: DebridAuthMethod.deviceCode,
      capabilities: [
        DebridCapability.clientResolve,
        DebridCapability.localTorrentCacheCheck,
        DebridCapability.localTorrentResolve,
        DebridCapability.cloudLibrary,
      ],
    ),
    DebridProvider(
      id: DebridProviderId.realdebrid,
      displayName: 'Real-Debrid',
      shortName: 'RD',
      authMethod: DebridAuthMethod.apiKey,
      capabilities: [
        DebridCapability.clientResolve,
        DebridCapability.localTorrentCacheCheck,
      ],
    ),
  ];

  static DebridProvider? byId(DebridProviderId id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// A connected debrid account.
class DebridAccount {
  const DebridAccount({
    required this.providerId,
    required this.apiKey,
    this.userEmail,
    this.premiumUntil,
    this.connectedAt,
  });

  final DebridProviderId providerId;
  final String apiKey;
  final String? userEmail;
  final DateTime? premiumUntil;
  final DateTime? connectedAt;

  bool get isPremium {
    final until = premiumUntil;
    if (until == null) return true; // unknown = assume yes
    return until.isAfter(DateTime.now());
  }

  Map<String, dynamic> toJson() => {
        'providerId': providerId.name,
        'apiKey': apiKey,
        if (userEmail != null) 'userEmail': userEmail,
        if (premiumUntil != null)
          'premiumUntil': premiumUntil!.toIso8601String(),
        if (connectedAt != null) 'connectedAt': connectedAt!.toIso8601String(),
      };

  factory DebridAccount.fromJson(Map<String, dynamic> json) {
    return DebridAccount(
      providerId: DebridProviderId.values.firstWhere(
        (p) => p.name == json['providerId'],
        orElse: () => DebridProviderId.realdebrid,
      ),
      apiKey: (json['apiKey'] as String?) ?? '',
      userEmail: json['userEmail'] as String?,
      premiumUntil:
          DateTime.tryParse(json['premiumUntil'] as String? ?? ''),
      connectedAt: DateTime.tryParse(json['connectedAt'] as String? ?? ''),
    );
  }
}

/// Abstract debrid operations. Each provider implements this.
abstract class DebridService {
  DebridProviderId get providerId;

  /// Validate an API key / device-code token; returns account info.
  Future<Result<DebridAccount>> validateKey(String apiKey);

  /// Check if a torrent (infoHash) is instantly cached.
  Future<Result<bool>> isCached(String infoHash);

  /// Resolve a cached torrent to a direct download URL.
  Future<Result<String>> resolveTorrent(
    String infoHash, {
    int? fileIndex,
  });

  /// Resolve a direct/hoster link to a premium download URL.
  Future<Result<String>> resolveLink(String url);
}

/// Real-Debrid implementation (API-key auth, /torrents + /unrestrict).
class RealDebridService implements DebridService {
  RealDebridService(this._http);

  final HttpClient _http;
  static const _base = 'https://api.real-debrid.com/rest/1.0';

  @override
  DebridProviderId get providerId => DebridProviderId.realdebrid;

  Map<String, String> _headers(String apiKey) =>
      {'Authorization': 'Bearer $apiKey'};

  @override
  Future<Result<DebridAccount>> validateKey(String apiKey) async {
    final result = await _http.getJson(
      Uri.parse('$_base/user'),
      headers: _headers(apiKey),
    );
    return switch (result) {
      Ok(:final value) when value is Map<String, dynamic> => Result.ok(
          DebridAccount(
            providerId: providerId,
            apiKey: apiKey,
            userEmail: value['email'] as String?,
            premiumUntil:
                DateTime.tryParse(value['premium'] as String? ?? ''),
            connectedAt: DateTime.now(),
          ),
        ),
      Ok() => Result.err(AppError.parse('Unexpected user response')),
      Err(:final error) => Result.err(error),
    };
  }

  @override
  Future<Result<bool>> isCached(String infoHash) async {
    // RD checks via /torrents/info/{id} after adding; simplified: we treat
    // the instantAvailable check at add time. For cache-check-first flows
    // the client adds the magnet and inspects available files.
    return Result.ok(false); // resolved at resolveTorrent time
  }

  @override
  Future<Result<String>> resolveTorrent(
    String infoHash, {
    int? fileIndex,
  }) async {
    // 1. Add magnet.
    final addResult = await _http.postJson(
      Uri.parse('$_base/torrents/addMagnet'),
      body: {'magnet': 'magnet:?xt=urn:btih:$infoHash'},
      headers: _headers(''), // filled by caller-side wrapper
    );
    if (addResult.isErr) return Result.err(addResult.errorOrNull!);
    final addData = addResult.valueOrNull;
    if (addData is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Add magnet failed'));
    }
    final torrentId = addData['id']?.toString();
    if (torrentId == null) {
      return Result.err(AppError.parse('No torrent id'));
    }

    // 2. Select files (all) then get info.
    await _http.postJson(
      Uri.parse('$_base/torrents/selectFiles/$torrentId'),
      body: {'files': 'all'},
      headers: _headers(''),
    );
    final infoResult = await _http.getJson(
      Uri.parse('$_base/torrents/info/$torrentId'),
      headers: _headers(''),
    );
    if (infoResult.isErr) return Result.err(infoResult.errorOrNull!);
    final info = infoResult.valueOrNull;
    if (info is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Info failed'));
    }

    // 3. Pick the requested (or first) link.
    final links = (info['links'] as List<dynamic>?) ?? const [];
    if (links.isEmpty) {
      return Result.err(AppError.notFound('No links in torrent'));
    }
    final link = fileIndex != null && fileIndex < links.length
        ? links[fileIndex]
        : links.first;

    // 4. Unrestrict to direct URL.
    final unrestrict = await _http.postJson(
      Uri.parse('$_base/unrestrict/link'),
      body: {'link': link.toString()},
      headers: _headers(''),
    );
    if (unrestrict.isErr) return Result.err(unrestrict.errorOrNull!);
    final unrestrictData = unrestrict.valueOrNull;
    if (unrestrictData is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Unrestrict failed'));
    }
    final download = unrestrictData['download'] as String?;
    if (download == null || download.isEmpty) {
      return Result.err(AppError.parse('No download URL'));
    }
    return Result.ok(download);
  }

  @override
  Future<Result<String>> resolveLink(String url) async {
    final result = await _http.postJson(
      Uri.parse('$_base/unrestrict/link'),
      body: {'link': url},
      headers: _headers(''),
    );
    if (result.isErr) return Result.err(result.errorOrNull!);
    final data = result.valueOrNull;
    if (data is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Unrestrict failed'));
    }
    final download = data['download'] as String?;
    if (download == null || download.isEmpty) {
      return Result.err(AppError.parse('No download URL'));
    }
    return Result.ok(download);
  }
}

/// Masks an API key for display: keeps first 4 + last 4.
String maskApiKey(String key) {
  if (key.length <= 8) return '••••';
  return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
}
