import 'package:flame/components.dart';

import '../../domain/elements/element_model.dart';

/// Base render layer that projects one [ElementModel] into Flame component
/// state.
abstract class ElementRenderLayer<T extends ElementModel>
    extends PositionComponent
    with HasVisibility {
  T? _model;

  T get model => _model as T;

  void bind(T model, {Set<String>? changedKeys, bool refresh = false}) {
    _model = model;
    final fullBind = refresh || _shouldRunFullBind(changedKeys);
    final effectiveKeys = fullBind ? null : changedKeys;

    if (fullBind ||
        _touchesAny(effectiveKeys, const <String>{'attrs.zIndex'})) {
      priority = _priorityFromZIndex(model.zIndex);
    }
    if (fullBind || _touchesAny(effectiveKeys, const <String>{'show'})) {
      isVisible = model.show;
    }
    if (fullBind ||
        _touchesAny(effectiveKeys, const <String>{'attrs.x', 'attrs.y'})) {
      _syncPosition(model.attrs);
    }
    if (fullBind || _shouldSyncFromModel(effectiveKeys!)) {
      syncFromModel(model, changedKeys: effectiveKeys, refresh: fullBind);
    }
  }

  void syncFromModel(
    T model, {
    required Set<String>? changedKeys,
    required bool refresh,
  });

  bool _shouldRunFullBind(Set<String>? changedKeys) {
    if (changedKeys == null || changedKeys.isEmpty) {
      return true;
    }
    if (changedKeys.contains('*')) {
      return true;
    }
    if (changedKeys.contains('attrs') &&
        !changedKeys.any((key) => key.startsWith('attrs.'))) {
      return true;
    }
    return false;
  }

  bool _shouldSyncFromModel(Set<String> changedKeys) {
    for (final key in changedKeys) {
      if (_isSharedOnlyKey(key)) {
        continue;
      }
      return true;
    }
    return false;
  }

  bool _isSharedOnlyKey(String key) {
    return key == 'show' ||
        key == 'attrs' ||
        key == 'attrs.x' ||
        key == 'attrs.y' ||
        key == 'attrs.zIndex';
  }

  bool _touchesAny(Set<String>? changedKeys, Set<String> targets) {
    if (changedKeys == null) {
      return true;
    }
    for (final target in targets) {
      if (changedKeys.contains(target)) {
        return true;
      }
      if (target.contains('.')) {
        final parent = target.substring(0, target.indexOf('.'));
        if (changedKeys.contains(parent)) {
          return true;
        }
      }
    }
    return false;
  }

  void _syncPosition(Map<String, Object?> attrs) {
    position.setValues(
      _doubleFromAttr(attrs['x']),
      _doubleFromAttr(attrs['y']),
    );
  }

  int _priorityFromZIndex(num zIndex) {
    if (zIndex is double && !zIndex.isFinite) {
      return 0;
    }
    return zIndex.round();
  }

  double _doubleFromAttr(Object? value) => value is num ? value.toDouble() : 0;
}
