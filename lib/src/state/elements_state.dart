import 'dart:collection';

import '../domain/elements/element_model.dart';

enum ElementsStateChangeKind { added, updated, removed, cleared }

final class ElementsStateChange {
  const ElementsStateChange({
    required this.kind,
    required this.elementId,
    this.model,
  });

  final ElementsStateChangeKind kind;
  final String elementId;
  final ElementModel? model;
}

typedef ElementsStateListener = void Function(ElementsStateChange change);

final class ElementsState {
  final Map<String, ElementModel> _byId = <String, ElementModel>{};
  final Map<String, ElementModelListener> _modelListenerById =
      <String, ElementModelListener>{};
  final Set<ElementsStateListener> _listeners = <ElementsStateListener>{};
  Map<String, Object?>? _selectorRootJsonCache;
  bool _selectorRootJsonDirty = true;
  Map<String, Object?>? _selectorRootJsonReadonlyCache;

  List<ElementModel> get elements =>
      List<ElementModel>.unmodifiable(_byId.values);

  ElementModel? byId(String elementId) => _byId[elementId];

  Object selectorRootJson() {
    final cached = _selectorRootJsonCache;
    final readonlyCached = _selectorRootJsonReadonlyCache;
    if (!_selectorRootJsonDirty && cached != null && readonlyCached != null) {
      return readonlyCached;
    }

    final next = <String, Object?>{
      'children': _byId.values.map((element) => element.toJson()).toList(),
    };
    _selectorRootJsonCache = next;
    _selectorRootJsonReadonlyCache = _readonlyRoot(next);
    _selectorRootJsonDirty = false;
    return _selectorRootJsonReadonlyCache!;
  }

  void addListener(ElementsStateListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ElementsStateListener listener) {
    _listeners.remove(listener);
  }

  void upsert(ElementModel model) {
    final existing = _byId[model.id];
    if (existing != null && !identical(existing, model)) {
      _detachModel(model.id, existing);
    } else if (identical(existing, model)) {
      _invalidateSelectorRootJson();
      _emit(
        ElementsStateChange(
          kind: ElementsStateChangeKind.updated,
          elementId: model.id,
          model: model,
        ),
      );
      return;
    }

    _byId[model.id] = model;
    _attachModel(model);
    _invalidateSelectorRootJson();

    _emit(
      ElementsStateChange(
        kind: existing == null
            ? ElementsStateChangeKind.added
            : ElementsStateChangeKind.updated,
        elementId: model.id,
        model: model,
      ),
    );
  }

  ElementModel? removeById(String elementId) {
    final removed = _byId.remove(elementId);
    if (removed == null) {
      return null;
    }

    _detachModel(elementId, removed);
    _invalidateSelectorRootJson();

    _emit(
      ElementsStateChange(
        kind: ElementsStateChangeKind.removed,
        elementId: elementId,
        model: removed,
      ),
    );
    return removed;
  }

  void clear() {
    if (_byId.isEmpty) {
      return;
    }

    final ids = _byId.keys.toList(growable: false);
    for (final id in ids) {
      final model = _byId[id];
      if (model != null) {
        _detachModel(id, model);
      }
    }
    _byId.clear();
    _invalidateSelectorRootJson();

    _emit(
      const ElementsStateChange(
        kind: ElementsStateChangeKind.cleared,
        elementId: '',
      ),
    );
  }

  void _attachModel(ElementModel model) {
    void listener(ElementModel changed) {
      final current = _byId[changed.id];
      if (!identical(current, changed)) {
        return;
      }
      _invalidateSelectorRootJson();
      _emit(
        ElementsStateChange(
          kind: ElementsStateChangeKind.updated,
          elementId: changed.id,
          model: changed,
        ),
      );
    }

    _modelListenerById[model.id] = listener;
    model.addListener(listener);
  }

  void _detachModel(String elementId, ElementModel model) {
    final listener = _modelListenerById.remove(elementId);
    if (listener != null) {
      model.removeListener(listener);
    }
  }

  void _emit(ElementsStateChange change) {
    if (_listeners.isEmpty) {
      return;
    }

    final listeners = List<ElementsStateListener>.of(_listeners);
    for (final listener in listeners) {
      listener(change);
    }
  }

  void _invalidateSelectorRootJson() {
    _selectorRootJsonDirty = true;
  }

  Map<String, Object?> _readonlyRoot(Map<String, Object?> root) {
    final out = <String, Object?>{};
    for (final entry in root.entries) {
      out[entry.key] = _toReadonlyJson(entry.value);
    }
    return UnmodifiableMapView<String, Object?>(out);
  }

  Object? _toReadonlyJson(Object? value) {
    if (value is Map) {
      final out = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is String) {
          out[key] = _toReadonlyJson(entry.value);
        }
      }
      return UnmodifiableMapView<String, Object?>(out);
    }
    if (value is List) {
      final out = <Object?>[];
      for (final item in value) {
        out.add(_toReadonlyJson(item));
      }
      return UnmodifiableListView<Object?>(out);
    }
    return value;
  }
}
