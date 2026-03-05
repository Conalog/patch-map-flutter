import 'dart:collection';

import '../common/json_types.dart';
import 'element_model.dart';

/// Image domain model for `type: "image"` elements.
///
/// Supported JSON fields (draw/fromJson):
/// - `type` (required): must be `"image"`.
/// - `id` (`String?`): when omitted, an auto id is assigned.
/// - `label` (`String?`)
/// - `show` (`bool`, default `true`)
/// - `attrs` (`Map<String, Object?>`, default `{}`)
/// - `source` (`String`, required on draw)
/// - `size` (`Map<String, Object?>?`, default `null`)
/// - `tint` (`String|num|null`, default `null`)
final class ImageElement extends ElementModel {
  static const String elementType = 'image';
  static bool _decoderRegistered = false;

  static void ensureDecoderRegistered() {
    if (_decoderRegistered) {
      return;
    }
    ElementModel.registerDecoder(elementType, fromJson);
    _decoderRegistered = true;
  }

  static ImageElement fromJson(JsonMap map) {
    final type = map['type'];
    if (type != elementType) {
      throw FormatException(
        'ImageElement.fromJson expects type "$elementType", got "$type".',
      );
    }

    return ImageElement(
      id: _nullableString(map, 'id'),
      label: _nullableString(map, 'label'),
      show: _boolOrDefault(map, 'show', defaultValue: true),
      attrs: _jsonMapOrDefault(
        map,
        'attrs',
        defaultValue: const <String, Object?>{},
      ),
      source: _requiredString(map, 'source'),
      size: _nullableSizeMap(map, 'size'),
      tint: _nullableTintValue(map, 'tint'),
    );
  }

  static String? _nullableString(JsonMap map, String key) {
    if (!map.containsKey(key)) {
      return null;
    }
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw FormatException('draw() "$key" must be a string when provided.');
  }

  static bool _boolOrDefault(
    JsonMap map,
    String key, {
    required bool defaultValue,
  }) {
    if (!map.containsKey(key)) {
      return defaultValue;
    }
    final value = map[key];
    if (value is bool) {
      return value;
    }
    throw FormatException('draw() "$key" must be a bool when provided.');
  }

  static JsonMap _jsonMapOrDefault(
    JsonMap map,
    String key, {
    required JsonMap defaultValue,
  }) {
    if (!map.containsKey(key)) {
      return defaultValue;
    }
    final value = map[key];
    if (value == null) {
      return defaultValue;
    }
    final parsed = ElementModel.asJsonMap(value);
    if (parsed == null) {
      throw FormatException(
        'draw() "$key" must be a JSON object when provided.',
      );
    }
    return parsed;
  }

  static String _requiredString(JsonMap map, String key) {
    if (!map.containsKey(key)) {
      throw FormatException('draw() "$key" is required for image elements.');
    }
    final value = map[key];
    if (value is String) {
      return value;
    }
    throw FormatException('draw() "$key" must be a string when provided.');
  }

  static JsonMap? _nullableSizeMap(JsonMap map, String key) {
    if (!map.containsKey(key)) {
      return null;
    }
    final value = map[key];
    return _normalizeSize(value, key: key);
  }

  static JsonMap? _normalizeSize(Object? value, {required String key}) {
    if (value == null) {
      return null;
    }
    if (value is num && value.isFinite && value >= 0) {
      final normalized = value.toDouble();
      return <String, Object?>{'width': normalized, 'height': normalized};
    }
    final parsed = ElementModel.asJsonMap(value);
    if (parsed == null) {
      throw FormatException(
        'draw() "$key" must be a number or JSON object when provided.',
      );
    }
    return parsed;
  }

  static Object? _nullableTintValue(JsonMap map, String key) {
    if (!map.containsKey(key)) {
      return null;
    }
    final value = map[key];
    if (value == null || value is String || value is num) {
      return value;
    }
    throw FormatException(
      'draw() "$key" must be a string/number when provided.',
    );
  }

  ImageElement({
    super.id,
    super.label,
    super.show = true,
    super.attrs = const <String, Object?>{},
    String source = '',
    JsonMap? size,
    Object? tint,
  }) : _source = source,
       _size = size == null ? null : Map<String, Object?>.of(size),
       _tint = tint,
       super(type: elementType);

  String _source;
  Map<String, Object?>? _size;
  Object? _tint;

  String get source => _source;
  set source(String value) {
    apply(source: value);
  }

  Map<String, Object?>? get size {
    final value = _size;
    if (value == null) {
      return null;
    }
    return UnmodifiableMapView<String, Object?>(value);
  }

  set size(JsonMap? value) {
    apply(size: value);
  }

  void setSizeValue(String key, Object? value) {
    apply(sizePatch: <String, Object?>{key: value});
  }

  Object? get tint => _tint;
  set tint(Object? value) {
    apply(tint: value);
  }

  @override
  void applyJsonPatch(JsonMap changes, {required bool mergeObjects}) {
    final labelArg = labelArgFromChanges(changes);
    final showArg = showArgFromChanges(changes);
    final attrsArg = ElementModel.asJsonMap(changes['attrs']);
    final sourceArg = _sourceArg(changes);
    final sizeArg = _sizeArg(changes);
    final tintArg = _tintArg(changes);

    apply(
      label: labelArg,
      show: showArg,
      attrs: mergeObjects ? null : attrsArg,
      attrsPatch: mergeObjects ? attrsArg : null,
      source: sourceArg,
      size: mergeObjects ? null : sizeArg,
      sizePatch: mergeObjects ? sizeArg : null,
      tint: tintArg,
    );
  }

  @override
  void apply({
    Object? label = ElementModel.unchanged,
    bool? show,
    JsonMap? attrs,
    JsonMap? attrsPatch,
    bool mergeAttrs = false,
    Object? source = ElementModel.unchanged,
    JsonMap? size,
    JsonMap? sizePatch,
    bool mergeSize = false,
    Object? tint = ElementModel.unchanged,
  }) {
    final changedKeys = applyBaseChanges(
      label: label,
      show: show,
      attrs: attrs,
      attrsPatch: attrsPatch,
      mergeAttrs: mergeAttrs,
    );

    if (!identical(source, ElementModel.unchanged)) {
      final nextSource = source as String;
      if (_source != nextSource) {
        _source = nextSource;
        changedKeys.add('source');
      }
    }

    if (size != null) {
      final nextSize = Map<String, Object?>.of(size);
      final currentSize = _size;
      if (currentSize == null) {
        _size = nextSize;
        changedKeys.add('size');
        changedKeys.addAll(nextSize.keys.map((key) => 'size.$key'));
      } else if (mergeSize) {
        final sizeKeys = mergeMapEntries(currentSize, nextSize);
        if (sizeKeys.isNotEmpty) {
          changedKeys.add('size');
          changedKeys.addAll(sizeKeys.map((key) => 'size.$key'));
        }
      } else if (!mapEqualsShallow(currentSize, nextSize)) {
        final sizeKeys = changedMapKeys(currentSize, nextSize);
        _size = nextSize;
        changedKeys.add('size');
        changedKeys.addAll(sizeKeys.map((key) => 'size.$key'));
      }
    }

    if (sizePatch != null) {
      final currentSize = _size;
      if (currentSize == null) {
        final initial = <String, Object?>{};
        final sizeKeys = patchMapEntries(initial, sizePatch);
        if (initial.isNotEmpty) {
          _size = initial;
          changedKeys.add('size');
          changedKeys.addAll(sizeKeys.map((key) => 'size.$key'));
        }
      } else {
        final sizeKeys = patchMapEntries(currentSize, sizePatch);
        if (sizeKeys.isNotEmpty) {
          changedKeys.add('size');
          changedKeys.addAll(sizeKeys.map((key) => 'size.$key'));
        }
      }
    }

    if (!identical(tint, ElementModel.unchanged)) {
      if (_tint != tint) {
        _tint = tint;
        changedKeys.add('tint');
      }
    }

    if (changedKeys.isNotEmpty) {
      notifyChanged(changedKeys: changedKeys);
    }
  }

  @override
  bool get isSelectable => true;

  @override
  ElementHitScope get hitScope => ElementHitScope.children;

  @override
  JsonMap toJson() {
    final map = toJsonBase()..['source'] = _source;
    final sizeValue = _size;
    if (sizeValue != null) {
      map['size'] = Map<String, Object?>.of(sizeValue);
    }
    final tintValue = _tint;
    if (tintValue != null) {
      map['tint'] = tintValue;
    }
    return map;
  }

  @override
  Object? selectorRootValue(String key) {
    return switch (key) {
      'source' => _source,
      'size' => _size,
      'tint' => _tint,
      _ => super.selectorRootValue(key),
    };
  }

  Object _sourceArg(JsonMap changes) {
    if (!changes.containsKey('source')) {
      return ElementModel.unchanged;
    }
    final value = changes['source'];
    if (value is String) {
      return value;
    }
    if (value == null) {
      return '';
    }
    return ElementModel.unchanged;
  }

  JsonMap? _sizeArg(JsonMap changes) {
    if (!changes.containsKey('size')) {
      return null;
    }
    return _normalizeSize(changes['size'], key: 'size');
  }

  Object? _tintArg(JsonMap changes) {
    if (!changes.containsKey('tint')) {
      return ElementModel.unchanged;
    }
    final value = changes['tint'];
    if (value == null || value is String || value is num) {
      return value;
    }
    return ElementModel.unchanged;
  }
}
