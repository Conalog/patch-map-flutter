import 'dart:async';

import 'runtime/patchmap_init_options.dart';
import 'runtime/patchmap_runtime.dart';

export 'runtime/patchmap_init_options.dart'
    show PatchmapInitAppOptions, PatchmapInitAssets, PatchmapInitOptions;
export 'runtime/patchmap_runtime.dart' show PatchmapRuntime;

final class Patchmap {
  Patchmap({PatchmapRuntime? runtime}) : _app = runtime ?? PatchmapRuntime();

  final PatchmapRuntime _app;
  Future<void>? _initFuture;

  PatchmapRuntime get app => _app;

  Future<void> init({
    PatchmapInitOptions options = const PatchmapInitOptions(),
  }) {
    if (_app.assetsReady) {
      return Future<void>.value();
    }

    final inProgress = _initFuture;
    if (inProgress != null) {
      return inProgress;
    }

    _app.configureApp(options.app);

    final initialization = _app
        .preloadAssets(assets: options.assets)
        .whenComplete(() {
          _initFuture = null;
        });

    _initFuture = initialization;
    return initialization;
  }
}
