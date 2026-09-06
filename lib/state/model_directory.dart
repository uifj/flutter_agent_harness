// The model directory: what the composer's model seat offers, and what the
// current selection is.
//
// A port of dsh's `ModelDirectoryResolver` (`ctx.modelDirectories`), shrunk to
// the one process this app is: no host session RPC, so the "directory" is the
// settings document's provider plus the models its endpoint serves (the same
// `/v1/models` fetch the settings panel's Test connection runs), with the
// provider's static default standing in for the catalog dsh's host computes.
//
// The selection is advisory here, not authoritative: changing the model this
// way writes the settings document and rebuilds the runtime, because in a
// single process there is no per-session model override — the runtime IS the
// session's model. dsh can switch mid-session (`session.selectModel`); this
// app's equivalent is the rebuild, which drops the open conversation the same
// way any model-field save does.

import 'dart:io' show HttpException;

import 'package:flutter/foundation.dart';

import '../genkit/models_endpoint.dart';
import '../model/model_settings.dart';

/// One offered model: an id, the provider it belongs to, and whether the
/// endpoint itself reported it (fetched) or it is the provider's static
/// default (built-in).
@immutable
class DirectoryModel {
  const DirectoryModel({
    required this.provider,
    required this.id,
    required this.fetched,
  });

  final LlmProvider provider;
  final String id;

  /// True when [id] came off the endpoint's list rather than the provider
  /// default. The seat can show this as "listed" without saying anything
  /// stronger — a listed model is known to the endpoint; a default one is
  /// presumed.
  final bool fetched;
}

/// What the composer's model seat reads: the offered models, the current
/// selection, and the verbs to change either.
///
/// The directory describes one provider at a time — the settings document's
/// provider — because that is the set a selection can actually commit to;
/// switching providers is a settings change, not a menu choice, so the seat's
/// provider group is singular by design.
class ModelDirectory extends ChangeNotifier {
  ModelDirectory({
    required ModelSettings current,
    ModelsEndpointFetcher? fetcher,
  })  : _selected = current.model,
       _provider = current.provider,
       _models = List.unmodifiable(_defaultsFor(current.provider)),
       _fetcher = fetcher;

  /// The endpoint fetch behind the catalog refresh. Null keeps the directory
  /// static (tests) — `refresh` is then a no-op rather than an error.
  final ModelsEndpointFetcher? _fetcher;

  List<DirectoryModel> _models;
  String _selected;
  LlmProvider _provider;
  String? _loadError;
  bool _loading = false;

  /// Stale-response guard, the settings panel's generation counter again: a
  /// refresh from an abandoned provider must not land as the current list.
  int _generation = 0;

  /// The models on offer, defaults first, then the endpoint's list, deduped.
  List<DirectoryModel> get models => _models;

  /// The id the runtime's model field carries.
  String get selectedModel => _selected;

  /// The provider the whole directory describes.
  LlmProvider get provider => _provider;

  /// The last refresh's failure, or null. Null while loading, too: an
  /// in-flight refresh is not an error.
  String? get loadError => _loadError;

  bool get isLoading => _loading;

  /// Re-points the directory at a new document: the saved provider and model.
  /// Called by the host after a settings save (any save, not just a model
  /// one) so the seat can never disagree with the document it reads.
  void adopt(ModelSettings current) {
    final providerChanged = current.provider != _provider;
    _provider = current.provider;
    _selected = current.model;
    _generation++;
    _loading = false;
    _loadError = null;
    if (providerChanged) {
      // A different provider's catalog is a different floor; the fetched
      // list belonged to the old endpoint and goes with it.
      _models = List.unmodifiable(_defaultsFor(current.provider));
    }
    notifyListeners();
  }

  /// Refreshes the catalog from the endpoint. The static default survives
  /// any failure — a directory that offers nothing is a menu that cannot be
  /// used, and the default is the model the runtime can definitely reach.
  Future<void> refresh() async {
    if (_loading) return;
    final resolved = _fetcher;
    if (resolved == null) return;
    final generation = _generation;
    // The endpoint and key the CURRENT document names are what the fetch
    // consults; the host wires them in when it calls adopt, so the directory
    // itself holds only the selection, not the connection fields.
    final connection = _connection;
    if (connection == null) {
      // No key on file: no fetch. The defaults stay, and the seat does not
      // pretend the endpoint was asked.
      return;
    }
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final ids = await resolved.listModels(
        provider: _provider,
        baseUrl: connection.$1,
        apiKey: connection.$2,
      );
      if (generation != _generation) return;
      _models = _merge(defaults: _defaultsFor(_provider), fetched: ids);
      _loading = false;
      notifyListeners();
    } catch (error) {
      if (generation != _generation) return;
      _loading = false;
      // The settings probe's own wording rule: a status code is the most
      // useful sentence a failure has.
      _loadError = switch (error) {
        HttpException e => e.message,
        _ => error.toString(),
      };
      notifyListeners();
    }
  }

  /// The connection the refresh consults, set by the host per document.
  /// Null while no fetch should run.
  (String, String)? _connection;

  /// Wires the connection the next [refresh] uses. Called by the host beside
  /// [adopt] — the directory stays independent of `SettingsStore` so tests
  /// can drive it with bare values.
  void adoptConnection({required String baseUrl, required String apiKey}) {
    _connection = apiKey.trim().isEmpty ? null : (baseUrl, apiKey);
  }

  /// Notes [id] as the selection. Committing it is the HOST's job — the seat
  /// offers, the host saves — so this is only the directory's own bookkeeping
  /// for the menu's check mark; a save that fails restores the old value via
  /// [adopt].
  void select(String id) {
    if (id == _selected) return;
    _selected = id;
    notifyListeners();
  }

  /// The provider's own default, as the catalog's floor.
  static List<DirectoryModel> _defaultsFor(LlmProvider provider) => [
    DirectoryModel(
      provider: provider,
      id: defaultModelFor(provider),
      fetched: false,
    ),
  ];

  /// Defaults first, then the fetched list, deduped by id — the offered
  /// catalog keeps its floor even when the endpoint answers differently.
  static List<DirectoryModel> _merge({
    required List<DirectoryModel> defaults,
    required List<String> fetched,
  }) {
    final seen = <String>{};
    return List.unmodifiable([
      for (final model in defaults)
        if (seen.add(model.id)) model,
      for (final id in fetched)
        if (seen.add(id))
          DirectoryModel(
            provider: defaults.first.provider,
            id: id,
            fetched: true,
          ),
    ]);
  }
}
