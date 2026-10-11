import 'content_type.dart';

/// Where a stream result came from. Mirrors the official clients'
/// streamOrigin kinds (addon vs plugin scraper vs debrid vs p2p).
enum StreamOriginKind { addon, plugin, debrid, p2p, external }

/// A playable source candidate for a movie or episode.
///
/// Shape mirrors the Stremio stream extra + the Nuvio extensions
/// (sourceProviderId, addonOrderIndex) used for grouping and ordering.
class Stream {
  const Stream({
    this.name,
    this.title,
    this.description,
    this.url,
    this.ytId,
    this.infoHash,
    this.fileIdx,
    this.externalUrl,
    this.behaviorHints = const {},
    this.addonName,
    this.addonLogo,
    this.addonId,
    this.addonBaseUrl,
    this.sourceProviderId,
    this.addonOrderIndex,
    this.isDebrid = false,
    this.originKind = StreamOriginKind.addon,
    this.subtitle,
  });

  final String? name;
  final String? title;
  final String? description;
  final String? url;
  final String? ytId;
  final String? infoHash;
  final int? fileIdx;
  final String? externalUrl;
  final Map<String, dynamic> behaviorHints;
  final String? addonName;
  final String? addonLogo;
  final String? addonId;
  final String? addonBaseUrl;
  final String? sourceProviderId;
  final int? addonOrderIndex;
  final bool isDebrid;
  final StreamOriginKind originKind;

  /// Optional subtitle bundled with this stream result.
  final Subtitle? subtitle;

  bool get isTorrent => infoHash != null && infoHash!.isNotEmpty;
  bool get isYoutube => ytId != null && ytId!.isNotEmpty;
  bool get isPlayable => url != null && url!.isNotEmpty;

  Stream copyWith({
    String? name,
    String? title,
    String? description,
    String? url,
    String? ytId,
    String? infoHash,
    int? fileIdx,
    String? externalUrl,
    Map<String, dynamic>? behaviorHints,
    String? addonName,
    String? addonLogo,
    String? addonId,
    String? addonBaseUrl,
    String? sourceProviderId,
    int? addonOrderIndex,
    bool? isDebrid,
    StreamOriginKind? originKind,
    Subtitle? subtitle,
  }) {
    return Stream(
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      ytId: ytId ?? this.ytId,
      infoHash: infoHash ?? this.infoHash,
      fileIdx: fileIdx ?? this.fileIdx,
      externalUrl: externalUrl ?? this.externalUrl,
      behaviorHints: behaviorHints ?? this.behaviorHints,
      addonName: addonName ?? this.addonName,
      addonLogo: addonLogo ?? this.addonLogo,
      addonId: addonId ?? this.addonId,
      addonBaseUrl: addonBaseUrl ?? this.addonBaseUrl,
      sourceProviderId: sourceProviderId ?? this.sourceProviderId,
      addonOrderIndex: addonOrderIndex ?? this.addonOrderIndex,
      isDebrid: isDebrid ?? this.isDebrid,
      originKind: originKind ?? this.originKind,
      subtitle: subtitle ?? this.subtitle,
    );
  }

  factory Stream.fromJson(Map<String, dynamic> json) {
    final origin = json['streamOrigin'] as Map<String, dynamic>?;
    return Stream(
      name: json['name'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      url: json['url'] as String?,
      ytId: json['ytId'] as String?,
      infoHash: (json['infoHash'] ?? json['info_hash']) as String?,
      fileIdx: json['fileIdx'] is int ? json['fileIdx'] as int : null,
      externalUrl: json['externalUrl'] as String?,
      behaviorHints:
          (json['behaviorHints'] as Map<String, dynamic>?) ?? const {},
      addonName: (json['addonName'] ?? origin?['addonName']) as String?,
      addonLogo: (json['addonLogo'] ?? origin?['addonLogo']) as String?,
      addonId: (json['addonId'] ?? origin?['addonId']) as String?,
      addonBaseUrl:
          (json['addonBaseUrl'] ?? origin?['addonBaseUrl']) as String?,
      sourceProviderId:
          (json['sourceProviderId'] ?? origin?['sourceProviderId']) as String?,
      addonOrderIndex: json['addonOrderIndex'] is int
          ? json['addonOrderIndex'] as int
          : (origin?['addonOrderIndex'] is int
              ? origin!['addonOrderIndex'] as int
              : null),
      isDebrid: json['isDebrid'] == true,
      originKind: _originKind(json, origin),
      subtitle: json['subtitle'] == null
          ? null
          : Subtitle.fromJson(json['subtitle'] as Map<String, dynamic>),
    );
  }

  static StreamOriginKind _originKind(
    Map<String, dynamic> json,
    Map<String, dynamic>? origin,
  ) {
    final raw =
        (origin?['kind'] ?? json['originKind'] ?? json['kind']) as String?;
    switch (raw?.toLowerCase()) {
      case 'plugin':
        return StreamOriginKind.plugin;
      case 'debrid':
        return StreamOriginKind.debrid;
      case 'p2p':
        return StreamOriginKind.p2p;
      case 'external':
        return StreamOriginKind.external;
      default:
        return StreamOriginKind.addon;
    }
  }
}

/// A subtitle track attached to a stream or discovered separately.
class Subtitle {
  const Subtitle({
    required this.id,
    this.lang,
    this.url,
    this.format,
    this.title,
  });

  final String id;
  final String? lang;
  final String? url;
  final String? format;
  final String? title;

  factory Subtitle.fromJson(Map<String, dynamic> json) {
    return Subtitle(
      id: (json['id'] as String?) ?? '',
      lang: (json['lang'] ?? json['language']) as String?,
      url: json['url'] as String?,
      format: json['format'] as String?,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (lang != null) 'lang': lang,
        if (url != null) 'url': url,
        if (format != null) 'format': format,
        if (title != null) 'title': title,
      };
}

/// Identifies what the user asked the stream resolver for.
class StreamRequest {
  const StreamRequest({
    required this.contentId,
    required this.type,
    this.videoId,
    this.season,
    this.episode,
  });

  final String contentId;
  final ContentType type;
  final String? videoId;
  final int? season;
  final int? episode;
}
