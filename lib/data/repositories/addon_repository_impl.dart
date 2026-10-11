import 'dart:async';
import 'dart:convert';

import 'package:nuvio_tv_flutter/core/network/http_client.dart';
import 'package:nuvio_tv_flutter/core/util/result.dart';
import 'package:nuvio_tv_flutter/core/storage/local_store.dart';
import 'package:nuvio_tv_flutter/data/remote/addon_api.dart';
import 'package:nuvio_tv_flutter/domain/models/addon.dart';

/// Contract: install/remove/enable addons, expose the effective list.
abstract class AddonRepository {
  Future<List<Addon>> getAddons();
  Future<Result<Addon>> install(String manifestUrl);
  Future<void> remove(String addonId);
  Future<void> setEnabled(String addonId, bool enabled);
  Future<void> setOrder(List<String> orderedIds);
  Stream<List<Addon>> watchAddons();
}

/// Local persistence-backed implementation.
class LocalAddonRepository implements AddonRepository {
  LocalAddonRepository(this._store, {AddonApi? api, HttpClient? http})
      : _api = api ?? AddonApi(http ?? HttpClient());

  final LocalStore _store;
  final AddonApi _api;

  final _controller = StreamController<List<Addon>>.broadcast();
  List<Addon>? _cache;

  static const _key = StorageKeys.addons;

  @override
  Future<List<Addon>> getAddons() async => _cache ??= _readAll();

  @override
  Stream<List<Addon>> watchAddons() {
    // Emit current then future updates.
    Future.microtask(() async {
      _controller.add(await getAddons());
    });
    return _controller.stream;
  }

  @override
  Future<Result<Addon>> install(String manifestUrl) async {
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || !uri.hasScheme) {
      return Result.err(AppError.parse('Invalid addon URL'));
    }
    final manifestResult = await _api.getManifest(uri);
    final error = manifestResult.errorOrNull;
    if (error != null) return Result.err(error);
    return _persistInstall(manifestResult.valueOrNull!);
  }

  Future<Result<Addon>> _persistInstall(Addon addon) async {
    final addons = await getAddons();
    // Dedupe by id: re-install updates url + metadata.
    final existingIndex = addons.indexWhere((a) => a.id == addon.id);
    if (existingIndex >= 0) {
      addons[existingIndex] =
          addon.copyWith(enabled: addons[existingIndex].enabled);
    } else {
      addons.add(addon.copyWith(orderIndex: addons.length));
    }
    await _writeAll(addons);
    _controller.add(addons);
    return Result.ok(addon);
  }

  @override
  Future<void> remove(String addonId) async {
    final addons = await getAddons();
    addons.removeWhere((a) => a.id == addonId);
    await _writeAll(addons);
    _controller.add(addons);
  }

  @override
  Future<void> setEnabled(String addonId, bool enabled) async {
    final addons = await getAddons();
    final index = addons.indexWhere((a) => a.id == addonId);
    if (index < 0) return;
    addons[index] = addons[index].copyWith(enabled: enabled);
    await _writeAll(addons);
    _controller.add(addons);
  }

  @override
  Future<void> setOrder(List<String> orderedIds) async {
    final addons = await getAddons();
    final byId = {for (final a in addons) a.id: a};
    final reordered = <Addon>[];
    for (var i = 0; i < orderedIds.length; i++) {
      final addon = byId[orderedIds[i]];
      if (addon != null) {
        reordered.add(addon.copyWith(orderIndex: i));
        byId.remove(orderedIds[i]);
      }
    }
    // Append any not mentioned, preserving relative order.
    var next = reordered.length;
    for (final addon in byId.values) {
      reordered.add(addon.copyWith(orderIndex: next));
      next++;
    }
    await _writeAll(reordered);
    _controller.add(reordered);
  }

  // ---- persistence ----

  List<Addon> _readAll() {
    final raw = _store.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => Addon.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<Addon> addons) async {
    _cache = addons;
    final raw = jsonEncode(addons
        .map((a) => {
              ..._addonToJson(a),
            })
        .toList());
    await _store.setString(_key, raw);
  }

  Map<String, dynamic> _addonToJson(Addon a) => {
        'id': a.id,
        'name': a.name,
        'url': a.url,
        if (a.version != null) 'version': a.version,
        if (a.description != null) 'description': a.description,
        'types': a.types,
        'catalogs': a.catalogs
            .map((c) => {
                  'id': c.id,
                  if (c.type != null) 'type': c.type,
                  if (c.name != null) 'name': c.name,
                  'genres': c.genres,
                })
            .toList(),
        'resources': a.resources
            .map((r) => {
                  'name': r.name,
                  'types': r.types,
                  if (r.idPrefixes != null) 'idPrefixes': r.idPrefixes,
                })
            .toList(),
        if (a.background != null) 'background': a.background,
        if (a.logo != null) 'logo': a.logo,
        'enabled': a.enabled,
        'orderIndex': a.orderIndex,
      };

  void dispose() => _controller.close();
}
