import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/debrid/debrid_service.dart';
import '../core/plugin/plugin_models.dart';
import '../core/storage/local_store.dart';
import '../domain/models/user_profile.dart';

/// App-wide settings, persisted per profile.
class AppSettings {
  const AppSettings({
    this.experienceMode = ExperienceMode.modern,
    this.skipIntervalSeconds = 10,
    this.autoPlayNext = true,
    this.autoPlayMode = StreamAutoPlayMode.manual,
    this.autoPlayRegex,
    this.p2pEnabled = false,
    this.enableUpload = true,
    this.hideTorrentStats = true,
    this.accentColor,
    this.traktConnected = false,
    this.simklConnected = false,
    this.mdbListApiKey,
  });

  final ExperienceMode experienceMode;
  final int skipIntervalSeconds;
  final bool autoPlayNext;
  final String autoPlayMode; // MANUAL | FIRST_STREAM | REGEX_MATCH
  final String? autoPlayRegex;
  final bool p2pEnabled;
  final bool enableUpload;
  final bool hideTorrentStats;
  final String? accentColor; // hex
  final bool traktConnected;
  final bool simklConnected;
  final String? mdbListApiKey;

  AppSettings copyWith({
    ExperienceMode? experienceMode,
    int? skipIntervalSeconds,
    bool? autoPlayNext,
    String? autoPlayMode,
    String? autoPlayRegex,
    bool? p2pEnabled,
    bool? enableUpload,
    bool? hideTorrentStats,
    String? accentColor,
    bool? traktConnected,
    bool? simklConnected,
    String? mdbListApiKey,
  }) {
    return AppSettings(
      experienceMode: experienceMode ?? this.experienceMode,
      skipIntervalSeconds: skipIntervalSeconds ?? this.skipIntervalSeconds,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      autoPlayMode: autoPlayMode ?? this.autoPlayMode,
      autoPlayRegex: autoPlayRegex ?? this.autoPlayRegex,
      p2pEnabled: p2pEnabled ?? this.p2pEnabled,
      enableUpload: enableUpload ?? this.enableUpload,
      hideTorrentStats: hideTorrentStats ?? this.hideTorrentStats,
      accentColor: accentColor ?? this.accentColor,
      traktConnected: traktConnected ?? this.traktConnected,
      simklConnected: simklConnected ?? this.simklConnected,
      mdbListApiKey: mdbListApiKey ?? this.mdbListApiKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'experienceMode': experienceMode.id,
        'skipIntervalSeconds': skipIntervalSeconds,
        'autoPlayNext': autoPlayNext,
        'autoPlayMode': autoPlayMode,
        if (autoPlayRegex != null) 'autoPlayRegex': autoPlayRegex,
        'p2pEnabled': p2pEnabled,
        'enableUpload': enableUpload,
        'hideTorrentStats': hideTorrentStats,
        if (accentColor != null) 'accentColor': accentColor,
        'traktConnected': traktConnected,
        'simklConnected': simklConnected,
        if (mdbListApiKey != null) 'mdbListApiKey': mdbListApiKey,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      experienceMode: ExperienceModeX.fromId(json['experienceMode'] as String?),
      skipIntervalSeconds: (json['skipIntervalSeconds'] as num?)?.toInt() ?? 10,
      autoPlayNext: json['autoPlayNext'] != false,
      autoPlayMode: (json['autoPlayMode'] as String?) ?? 'MANUAL',
      autoPlayRegex: json['autoPlayRegex'] as String?,
      p2pEnabled: json['p2pEnabled'] == true,
      enableUpload: json['enableUpload'] != false,
      hideTorrentStats: json['hideTorrentStats'] != false,
      accentColor: json['accentColor'] as String?,
      traktConnected: json['traktConnected'] == true,
      simklConnected: json['simklConnected'] == true,
      mdbListApiKey: json['mdbListApiKey'] as String?,
    );
  }
}

/// Stream auto-play mode constants (mirror of StreamAutoPlaySelector).
class StreamAutoPlayMode {
  const StreamAutoPlayMode._();
  static const manual = 'MANUAL';
  static const firstStream = 'FIRST_STREAM';
  static const regexMatch = 'REGEX_MATCH';
}

/// Settings controller: load/save round-trip through LocalStore.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final store = ref.watch(localStoreProvider);
    final raw = store.getString(StorageKeys.tmdbSettings); // reuse key slot
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const AppSettings();
      return AppSettings.fromJson(decoded);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> modify(AppSettings Function(AppSettings) updater) async {
    final current = state.valueOrNull ?? const AppSettings();
    final next = updater(current);
    final store = ref.read(localStoreProvider);
    await store.setString(
        StorageKeys.tmdbSettings, jsonEncode(next.toJson()));
    state = AsyncData(next);
  }
}

final localStoreProvider = Provider<LocalStore>((ref) {
  throw UnimplementedError('Override in bootstrap');
});

final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

/// Connected debrid accounts (providerId -> account).
class DebridAccountsController
    extends AsyncNotifier<Map<DebridProviderId, DebridAccount>> {
  @override
  Future<Map<DebridProviderId, DebridAccount>> build() async {
    final store = ref.watch(localStoreProvider);
    final raw = store.getString(StorageKeys.debridSettings);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      final out = <DebridProviderId, DebridAccount>{};
      for (final entry in decoded.entries) {
        final id = DebridProviderId.values.firstWhere(
          (p) => p.name == entry.key,
          orElse: () => DebridProviderId.realdebrid,
        );
        out[id] = DebridAccount.fromJson(entry.value as Map<String, dynamic>);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> connect(DebridAccount account) async {
    final current = state.valueOrNull ?? {};
    final next = {...current, account.providerId: account};
    final store = ref.read(localStoreProvider);
    await store.setString(
      StorageKeys.debridSettings,
      jsonEncode(next.map((k, v) => MapEntry(k.name, v.toJson()))),
    );
    state = AsyncData(next);
  }

  Future<void> disconnect(DebridProviderId providerId) async {
    final current = state.valueOrNull ?? {};
    final next = {...current}..remove(providerId);
    final store = ref.read(localStoreProvider);
    await store.setString(
      StorageKeys.debridSettings,
      jsonEncode(next.map((k, v) => MapEntry(k.name, v.toJson()))),
    );
    state = AsyncData(next);
  }
}

final debridAccountsProvider = AsyncNotifierProvider<DebridAccountsController,
    Map<DebridProviderId, DebridAccount>>(DebridAccountsController.new);

/// Plugin state controller.
class PluginStateController extends AsyncNotifier<PluginState> {
  @override
  Future<PluginState> build() async {
    final store = ref.watch(localStoreProvider);
    return PluginStore(store).load();
  }

  Future<void> addRepository(PluginRepository repo, List<Scraper> scrapers) async {
    final current = state.valueOrNull ?? const PluginState();
    final next = PluginState.normalize(
      repositories: [...current.repositories, repo],
      scrapers: [...current.scrapers, ...scrapers],
    );
    await ref.read(localStoreProvider).let((store) => PluginStore(store).save(next));
    state = AsyncData(next);
  }

  Future<void> removeRepository(String repoId) async {
    final current = state.valueOrNull ?? const PluginState();
    final next = PluginState(
      repositories: current.repositories.where((r) => r.id != repoId).toList(),
      scrapers: current.scrapers.where((s) => s.repositoryId != repoId).toList(),
    );
    await ref.read(localStoreProvider).let((store) => PluginStore(store).save(next));
    state = AsyncData(next);
  }

  Future<void> setScraperEnabled(String scraperId, bool enabled) async {
    final current = state.valueOrNull ?? const PluginState();
    final next = current.copyWith(
      scrapers: current.scrapers
          .map((s) => s.id == scraperId ? Scraper(
                id: s.id,
                repositoryId: s.repositoryId,
                name: s.name,
                code: s.code,
                version: s.version,
                enabled: enabled,
                supportsMovies: s.supportsMovies,
                supportsSeries: s.supportsSeries,
              ) : s)
          .toList(),
    );
    await ref.read(localStoreProvider).let((store) => PluginStore(store).save(next));
    state = AsyncData(next);
  }
}

final pluginStateProvider =
    AsyncNotifierProvider<PluginStateController, PluginState>(
        PluginStateController.new);

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
