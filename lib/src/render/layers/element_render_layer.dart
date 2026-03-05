import 'package:flame/components.dart';

import '../../domain/elements/element_model.dart';

/// Base render layer that projects one [ElementModel] into Flame component
/// state.
abstract class ElementRenderLayer<T extends ElementModel>
    extends PositionComponent
    with HasVisibility {
  T? _model;

  T get model => _model as T;

  void bind(T model) {
    _model = model;
    priority = _priorityFromZIndex(model.zIndex);
    isVisible = model.show;
    _syncPosition(model.attrs);
    syncFromModel(model);
  }

  void syncFromModel(T model);

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
