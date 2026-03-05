import 'dart:async';

import 'display/update.dart' as display_update;
import 'display/update.dart' show PatchmapUpdateOptions;
import 'domain/elements/builtin_element_decoders.dart';
import 'domain/elements/element_model.dart';
import 'render/layers/element_render_host.dart';
import 'render/layers/builtin_element_render_layers.dart';
import 'runtime/patchmap_init_options.dart';
import 'runtime/patchmap_runtime.dart';
import 'state/elements_state.dart';

export 'display/update.dart'
    show PatchmapUpdateMergeStrategy, PatchmapUpdateOptions, update;
export 'runtime/patchmap_init_options.dart'
    show PatchmapInitAppOptions, PatchmapInitAssets, PatchmapInitOptions;
export 'runtime/patchmap_runtime.dart' show PatchmapRuntime;

final class Patchmap {
  Patchmap({PatchmapRuntime? runtime}) : _app = runtime ?? PatchmapRuntime();

  final PatchmapRuntime _app;
  final ElementsState _elementsState = ElementsState();
  final ElementRenderHost _renderHost = ElementRenderHost();
  bool _renderHostBound = false;
  Future<void>? _initFuture;

  PatchmapRuntime get app => _app;

  Future<void> init({
    PatchmapInitOptions options = const PatchmapInitOptions(),
  }) {
    if (_app.assetsReady) {
      _ensureRenderHostMounted();
      return Future<void>.value();
    }

    final inProgress = _initFuture;
    if (inProgress != null) {
      return inProgress;
    }

    _app.configureApp(options.app);

    final initialization = _app
        .preloadAssets(assets: options.assets)
        .then<void>((_) {
          _ensureRenderHostMounted();
        })
        .whenComplete(() {
          _initFuture = null;
        });

    _initFuture = initialization;
    return initialization;
  }

  void _ensureRenderHostMounted() {
    ensureBuiltinElementRenderLayersRegistered();
    if (!_renderHostBound) {
      _renderHost.bindElementsState(_elementsState);
      _renderHostBound = true;
    }
    if (_renderHost.parent == null) {
      _app.world.add(_renderHost);
    }
  }

  List<ElementModel> update({
    PatchmapUpdateOptions options = const PatchmapUpdateOptions(),
  }) {
    return display_update.update(_elementsState, options: options);
  }

  List<ElementModel> draw(Iterable<Object?> elements) {
    ensureBuiltinElementDecodersRegistered();
    final models = elements.map(ElementModel.decode).toList(growable: false);
    return _drawModels(models);
  }

  List<ElementModel> _drawModels(Iterable<ElementModel> elements) {
    final drawnElements = List<ElementModel>.of(elements, growable: false);
    _elementsState.clear();
    for (final element in drawnElements) {
      _elementsState.upsert(element);
    }
    return List<ElementModel>.unmodifiable(drawnElements);
  }
}
