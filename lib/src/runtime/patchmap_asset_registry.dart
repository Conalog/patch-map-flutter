import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'patchmap_init_options.dart';

final class PatchmapAssetRegistry {
  PatchmapAssetRegistry({String packageName = 'patch_map_flutter'})
    : _packageName = packageName;

  static const Map<String, String> _iconAssetPathByAlias = <String, String>{
    'object': 'assets/icons/object.svg',
    'inverter': 'assets/icons/inverter.svg',
    'combiner': 'assets/icons/combiner.svg',
    'device': 'assets/icons/device.svg',
    'edge': 'assets/icons/edge.svg',
    'loading': 'assets/icons/loading.svg',
    'warning': 'assets/icons/warning.svg',
    'wifi': 'assets/icons/wifi.svg',
  };

  final String _packageName;
  final Map<String, String> _iconSvgByAlias = <String, String>{};

  bool _isReady = false;
  Future<void>? _loadingFuture;

  bool get isReady => _isReady;

  Map<String, String> get iconSvgByAlias =>
      UnmodifiableMapView<String, String>(_iconSvgByAlias);

  Future<void> preload({
    PatchmapInitAssets assets = const PatchmapInitAssets(),
  }) {
    if (_isReady) {
      return Future<void>.value();
    }

    final inProgress = _loadingFuture;
    if (inProgress != null) {
      return inProgress;
    }

    final loadFuture = _loadAssets(assets).whenComplete(() {
      _loadingFuture = null;
    });
    _loadingFuture = loadFuture;
    return loadFuture;
  }

  Future<void> _loadAssets(PatchmapInitAssets assets) async {
    final mergedIconAssetPathByAlias = <String, String>{
      ..._iconAssetPathByAlias,
      ...assets.iconAssetPathByAlias,
    };

    final loadedIconEntries = await Future.wait(
      mergedIconAssetPathByAlias.entries.map((entry) async {
        final svg = await _loadAssetString(entry.value);
        return MapEntry<String, String>(entry.key, svg);
      }),
    );
    _iconSvgByAlias
      ..clear()
      ..addEntries(loadedIconEntries);
    _isReady = true;
  }

  Future<String> _loadAssetString(String relativePath) async {
    final candidates = _assetCandidates(relativePath);
    FlutterError? lastError;

    for (final path in candidates) {
      try {
        return await rootBundle.loadString(path);
      } on FlutterError catch (error) {
        lastError = error;
      }
    }

    throw lastError ??
        FlutterError('Unable to load asset: ${candidates.join(', ')}');
  }

  List<String> _assetCandidates(String relativePath) => <String>[
    'packages/$_packageName/$relativePath',
    relativePath,
  ];
}
