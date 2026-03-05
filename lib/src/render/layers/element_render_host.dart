import 'package:flame/components.dart';

import '../../domain/elements/element_model.dart';
import '../../state/elements_state.dart';
import 'element_render_layer.dart';

typedef ElementRenderLayerFactory = ElementRenderLayer<dynamic> Function();

final class ElementRenderHost extends Component {
  static final Map<String, ElementRenderLayerFactory> _layerFactoryByType =
      <String, ElementRenderLayerFactory>{};

  static void registerLayerFactory(
    String elementType,
    ElementRenderLayerFactory factory,
  ) {
    final normalizedType = elementType.trim();
    if (normalizedType.isEmpty) {
      throw ArgumentError.value(
        elementType,
        'elementType',
        'elementType must not be empty',
      );
    }

    final existing = _layerFactoryByType[normalizedType];
    if (existing != null) {
      if (identical(existing, factory)) {
        return;
      }
      throw StateError(
        'Layer factory already registered for element type: $normalizedType',
      );
    }

    _layerFactoryByType[normalizedType] = factory;
  }

  final Map<String, ElementRenderLayer<dynamic>> _layerByElementId =
      <String, ElementRenderLayer<dynamic>>{};
  ElementsState? _boundState;
  ElementsStateListener? _stateListener;

  int get layerCount => _layerByElementId.length;

  ElementRenderLayer<dynamic>? layerByElementId(String elementId) =>
      _layerByElementId[elementId];

  void bindElementsState(ElementsState state) {
    if (identical(_boundState, state)) {
      return;
    }

    _unbindElementsState();
    clearLayers();

    _boundState = state;
    void listener(ElementsStateChange change) {
      switch (change.kind) {
        case ElementsStateChangeKind.added:
        case ElementsStateChangeKind.updated:
          final model = change.model;
          if (model != null) {
            upsert(
              model,
              changedKeys: change.changedKeys,
              refresh:
                  change.refresh ||
                  change.kind == ElementsStateChangeKind.added,
            );
          }
        case ElementsStateChangeKind.removed:
          removeByElementId(change.elementId);
        case ElementsStateChangeKind.cleared:
          clearLayers();
      }
    }

    _stateListener = listener;
    state.addListener(listener);

    for (final model in state.elements) {
      upsert(model, refresh: true);
    }
  }

  void upsert(
    ElementModel model, {
    Set<String>? changedKeys,
    bool refresh = false,
  }) {
    final existing = _layerByElementId[model.id];
    if (existing != null) {
      existing.bind(model, changedKeys: changedKeys, refresh: refresh);
      return;
    }

    final layer = _newLayer(model);
    _layerByElementId[model.id] = layer;
    add(layer);
    layer.bind(model, refresh: true);
  }

  void removeByElementId(String elementId) {
    final layer = _layerByElementId.remove(elementId);
    layer?.removeFromParent();
  }

  void clearLayers() {
    if (_layerByElementId.isEmpty) {
      return;
    }
    final layers = _layerByElementId.values.toList(growable: false);
    _layerByElementId.clear();
    for (final layer in layers) {
      layer.removeFromParent();
    }
  }

  @override
  void onRemove() {
    _unbindElementsState();
    clearLayers();
    super.onRemove();
  }

  ElementRenderLayer<dynamic> _newLayer(ElementModel model) {
    final factory = _layerFactoryByType[model.type];
    if (factory != null) {
      return factory();
    }
    throw UnsupportedError(
      'No render layer registered for element type: ${model.type}',
    );
  }

  void _unbindElementsState() {
    final state = _boundState;
    final listener = _stateListener;
    if (state != null && listener != null) {
      state.removeListener(listener);
    }
    _boundState = null;
    _stateListener = null;
  }
}
