import 'dart:convert';

import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';

/// Plugin (JS scraper) domain models, ported from the official clients'
/// plugin state shape.
///
/// A repository hosts scrapers; each scraper has a manifest and JS code
/// with a `loadLinks(type, imdbId, season, episode)` entry point.
class PluginRepository {
  const PluginRepository({
    required this.id,
    required this.name,
    required this.url,
    this.description,
    this.enabled = true,
    this.scraperCount = 0,
    this.lastUpdated,
  });

  final String id;
  final String name;
  final String url;
  final String? description;
  final bool enabled;
  final int scraperCount;
  final DateTime? lastUpdated;

  PluginRepository copyWith({
    bool? enabled,
    int? scraperCount,
    DateTime? lastUpdated,
  }) {
    return PluginRepository(
      id: id,
      name: name,
      url: url,
      description: description,
      enabled: enabled ?? this.enabled,
      scraperCount: scraperCount ?? this.scraperCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        if (description != null) 'description': description,
        'enabled': enabled,
        'scraperCount': scraperCount,
        if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
      };

  factory PluginRepository.fromJson(Map<String, dynamic> json) {
    return PluginRepository(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Repository',
      url: (json['url'] as String?) ?? '',
      description: json['description'] as String?,
      enabled: json['enabled'] != false,
      scraperCount: (json['scraperCount'] as num?)?.toInt() ?? 0,
      lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? ''),
    );
  }
}

/// A single JS scraper inside a repository.
class Scraper {
  const Scraper({
    required this.id,
    required this.repositoryId,
    required this.name,
    required this.code,
    this.version,
    this.enabled = true,
    this.supportsMovies = true,
    this.supportsSeries = true,
  });

  final String id;
  final String repositoryId;
  final String name;
  final String code;
  final String? version;
  final bool enabled;
  final bool supportsMovies;
  final bool supportsSeries;

  Map<String, dynamic> toJson() => {
        'id': id,
        'repositoryId': repositoryId,
        'name': name,
        'code': code,
        if (version != null) 'version': version,
        'enabled': enabled,
        'supportsMovies': supportsMovies,
        'supportsSeries': supportsSeries,
      };

  factory Scraper.fromJson(Map<String, dynamic> json) {
    return Scraper(
      id: (json['id'] as String?) ?? '',
      repositoryId: (json['repositoryId'] as String?) ?? 'repo',
      name: (json['name'] as String?) ?? 'Scraper',
      code: (json['code'] as String?) ?? '',
      version: json['version'] as String?,
      enabled: json['enabled'] != false,
      supportsMovies: json['supportsMovies'] != false,
      supportsSeries: json['supportsSeries'] != false,
    );
  }
}

/// The full plugin state (repos + scrapers), persisted per profile.
class PluginState {
  const PluginState({
    this.repositories = const [],
    this.scrapers = const [],
  });

  static const maxRepositories = 20;
  static const maxScrapers = 200;

  final List<PluginRepository> repositories;
  final List<Scraper> scrapers;

  PluginState copyWith({
    List<PluginRepository>? repositories,
    List<Scraper>? scrapers,
  }) {
    return PluginState(
      repositories: repositories ?? this.repositories,
      scrapers: scrapers ?? this.scrapers,
    );
  }

  /// Normalize: cap counts, dedupe by url/id, drop orphans.
  factory PluginState.normalize({
    required List<PluginRepository> repositories,
    required List<Scraper> scrapers,
  }) {
    final seenUrls = <String>{};
    final seenIds = <String>{};
    final cleanRepos = <PluginRepository>[];
    for (final repo in repositories.take(maxRepositories)) {
      final urlKey = repo.url.toLowerCase();
      final idKey = repo.id.toLowerCase();
      if (seenUrls.contains(urlKey) || seenIds.contains(idKey)) continue;
      if (repo.url.isEmpty) continue;
      seenUrls.add(urlKey);
      seenIds.add(idKey);
      cleanRepos.add(repo);
    }

    final repoIds = cleanRepos.map((r) => r.id).toSet();
    final seenScrapers = <String>{};
    final cleanScrapers = <Scraper>[];
    for (final scraper in scrapers.take(maxScrapers)) {
      final identity =
          '${scraper.repositoryId}|${scraper.id}|${scraper.name}'.toLowerCase();
      if (seenScrapers.contains(identity)) continue;
      if (!repoIds.contains(scraper.repositoryId)) continue; // orphan
      seenScrapers.add(identity);
      cleanScrapers.add(scraper);
    }

    return PluginState(repositories: cleanRepos, scrapers: cleanScrapers);
  }

  Map<String, dynamic> toJson() => {
        'repositories': repositories.map((r) => r.toJson()).toList(),
        'scrapers': scrapers.map((s) => s.toJson()).toList(),
      };

  factory PluginState.fromJson(Map<String, dynamic> json) {
    return PluginState(
      repositories: ((json['repositories'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PluginRepository.fromJson)
          .toList(),
      scrapers: ((json['scrapers'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Scraper.fromJson)
          .toList(),
    );
  }
}

/// Persists plugin state (profile-scoped via [LocalStore] keys).
class PluginStore {
  PluginStore(this._store);

  final LocalStore _store;
  static const _key = StorageKeys.pluginState;

  PluginState load() {
    final decoded = _decode(_store.getString(_key));
    return decoded ?? const PluginState();
  }

  Future<void> save(PluginState state) async {
    await _store.setString(_key, jsonEncode(state.toJson()));
  }

  PluginState? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) return null;
      return PluginState.fromJson(value);
    } catch (_) {
      return null;
    }
  }
}

/// Fetches and parses a plugin repository index.
///
/// A repo URL points to a JSON index: {name, description, scrapers:
/// [{id, name, version, file}]} where file is a relative JS path.
class PluginRepoFetcher {
  PluginRepoFetcher(this._http);

  final HttpClient _http;

  Future<Result<List<Scraper>>> fetchScrapers(PluginRepository repo) async {
    final indexUri = Uri.tryParse(repo.url);
    if (indexUri == null || !indexUri.hasScheme) {
      return Result.err(AppError.parse('Invalid repository URL'));
    }
    final indexResult = await _http.getJson(indexUri);
    if (indexResult.isErr) return Result.err(indexResult.errorOrNull!);
    final index = indexResult.valueOrNull;
    if (index is! Map<String, dynamic>) {
      return Result.err(AppError.parse('Repository index not an object'));
    }

    final entries = (index['scrapers'] as List<dynamic>?) ?? const [];
    final base = repo.url.contains('/')
        ? repo.url.substring(0, repo.url.lastIndexOf('/') + 1)
        : repo.url;

    final scrapers = <Scraper>[];
    for (final entry in entries.whereType<Map<String, dynamic>>()) {
      final file = entry['file'] as String?;
      if (file == null || file.isEmpty) continue;
      final codeUri = Uri.tryParse('$base$file');
      if (codeUri == null) continue;
      final codeResult = await _http.getJson(codeUri);
      final code = codeResult.valueOrNull;
      scrapers.add(Scraper(
        id: (entry['id'] as String?) ?? file,
        repositoryId: repo.id,
        name: (entry['name'] as String?) ?? file,
        version: entry['version'] as String?,
        code: code is String ? code : '',
      ));
    }
    return Result.ok(scrapers);
  }
}
