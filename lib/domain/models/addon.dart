/// A Stremio-protocol addon manifest (id, name, catalogs, resources).
class Addon {
  const Addon({
    required this.id,
    required this.name,
    required this.url,
    this.version,
    this.description,
    this.types = const [],
    this.catalogs = const [],
    this.resources = const [],
    this.background,
    this.logo,
    this.contactEmail,
    this.enabled = true,
    this.orderIndex = 0,
  });

  final String id;
  final String name;
  final String url;
  final String? version;
  final String? description;
  final List<String> types;
  final List<AddonCatalog> catalogs;
  final List<AddonResource> resources;
  final String? background;
  final String? logo;
  final String? contactEmail;
  final bool enabled;
  final int orderIndex;

  bool supportsResource(String resource) =>
      resources.any((r) => r.name == resource);

  Addon copyWith({bool? enabled, int? orderIndex}) => Addon(
        id: id,
        name: name,
        url: url,
        version: version,
        description: description,
        types: types,
        catalogs: catalogs,
        resources: resources,
        background: background,
        logo: logo,
        contactEmail: contactEmail,
        enabled: enabled ?? this.enabled,
        orderIndex: orderIndex ?? this.orderIndex,
      );

  factory Addon.fromJson(Map<String, dynamic> json, {String? url}) {
    return Addon(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Addon',
      url: url ?? (json['url'] as String?) ?? '',
      version: json['version'] as String?,
      description: json['description'] as String?,
      types: (json['types'] as List<dynamic>?)
              ?.map((t) => t is String ? t : (t['type'] as String? ?? ''))
              .where((t) => t.isNotEmpty)
              .toList() ??
          const [],
      catalogs: (json['catalogs'] as List<dynamic>?)
              ?.map((e) => AddonCatalog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      resources: (json['resources'] as List<dynamic>?)
              ?.map((e) => AddonResource.fromJson(e))
              .toList() ??
          const [],
      background: json['background'] as String?,
      logo: json['logo'] as String?,
      contactEmail: json['contactEmail'] as String?,
    );
  }
}

/// A catalog declared by an addon (e.g. "popular movies", "top series").
class AddonCatalog {
  const AddonCatalog({
    required this.id,
    this.type,
    this.name,
    this.genres = const [],
    this.extra = const [],
  });

  final String id;
  final String? type;
  final String? name;
  final List<String> genres;
  final List<AddonExtra> extra;

  factory AddonCatalog.fromJson(Map<String, dynamic> json) {
    return AddonCatalog(
      id: (json['id'] as String?) ?? '',
      type: json['type'] as String? ?? json['type_name'] as String?,
      name: json['name'] as String?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => g.toString())
              .toList() ??
          const [],
      extra: (json['extra'] as List<dynamic>?)
              ?.map((e) => AddonExtra.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// An extra parameter supported by a catalog (genre, search, skip...).
class AddonExtra {
  const AddonExtra({
    required this.name,
    this.isRequired = false,
    this.options = const [],
  });

  final String name;
  final bool isRequired;
  final List<String> options;

  factory AddonExtra.fromJson(Map<String, dynamic> json) {
    return AddonExtra(
      name: (json['name'] as String?) ?? '',
      isRequired: json['isRequired'] == true,
      options: (json['options'] as List<dynamic>?)
              ?.map((o) => o.toString())
              .toList() ??
          const [],
    );
  }
}

/// A resource an addon serves (catalog, meta, stream, subtitles).
class AddonResource {
  const AddonResource({
    required this.name,
    this.types = const [],
    this.idPrefixes,
  });

  final String name;
  final List<String> types;
  final List<String>? idPrefixes;

  factory AddonResource.fromJson(dynamic raw) {
    if (raw is String) {
      return AddonResource(name: raw);
    }
    if (raw is Map<String, dynamic>) {
      return AddonResource(
        name: (raw['name'] as String?) ?? '',
        types: (raw['types'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            const [],
        idPrefixes: (raw['idPrefixes'] as List<dynamic>?)
            ?.map((t) => t.toString())
            .toList(),
      );
    }
    return const AddonResource(name: '');
  }
}
