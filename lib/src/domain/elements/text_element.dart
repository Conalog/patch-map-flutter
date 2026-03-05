import 'dart:collection';

import '../common/json_types.dart';
import 'element_model.dart';

/// Text domain model for `type: "text"` elements.
///
/// Supported JSON fields (draw/fromJson):
/// - `type` (required): must be `"text"`.
/// - `id` (`String?`): when omitted, an auto id is assigned.
/// - `label` (`String?`)
/// - `show` (`bool`, default `true`)
/// - `attrs` (`Map<String, Object?>`, default `{}`)
/// - `text` (`String`, default `''`)
/// - `style` (`Map<String, Object?>`, default `{}`)
/// - `size` (`Map<String, Object?>?`, default `null`)
///
/// Patch behavior:
/// - `applyJsonPatch(..., mergeObjects: true)` merges object fields (`attrs`,
///   `style`, `size`) as patch maps.
/// - `applyJsonPatch(..., mergeObjects: false)` replaces object fields.
/// - `text: null` in JSON patch is normalized to `''`.
///
/// Rendering note (current text render layer behavior):
/// - `style.fill` -> text color
/// - `style.fontSize` -> font size
/// - `style.fontWeight` -> font weight (numeric or named string)
/// - `style.fontFamily` -> font family
final class TextElement extends ElementModel {
  static const String elementType = 'text';
  static bool _decoderRegistered = false;

  static void ensureDecoderRegistered() {
    if (_decoderRegistered) {
      return;
    }
    ElementModel.registerDecoder(elementType, fromJson);
    _decoderRegistered = true;
  }

  static TextElement fromJson(JsonMap map) {
    final type = map['type'];
    if (type != elementType) {
      throw FormatException(
        'TextElement.fromJson expects type "$elementType", got "$type".',
      );
    }

    return TextElement(
      id: _nullableString(map, 'id'),
      label: _nullableString(map, 'label'),
      show: _boolOrDefault(map, 'show', defaultValue: true),
      attrs: _jsonMapOrDefault(
        map,
        'attrs',
        defaultValue: const <String, Object?>{},
      ),
      text: _stringOrDefault(map, 'text', defaultValue: ''),
      style: _jsonMapOrDefault(
        map,
        'style',
        defaultValue: const <String, Object?>{},
      ),
      size: _nullableJsonMap(map, 'size'),
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

  static String _stringOrDefault(
    JsonMap map,
    String key, {
    required String defaultValue,
  }) {
    if (!map.containsKey(key)) {
      return defaultValue;
    }
    final value = map[key];
    if (value == null) {
      return defaultValue;
    }
    if (value is String) {
      return value;
    }
    throw FormatException('draw() "$key" must be a string when provided.');
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

  static JsonMap? _nullableJsonMap(JsonMap map, String key) {
    if (!map.containsKey(key)) {
      return null;
    }
    final value = map[key];
    if (value == null) {
      return null;
    }
    final parsed = ElementModel.asJsonMap(value);
    if (parsed == null) {
      throw FormatException(
        'draw() "$key" must be a JSON object when provided.',
      );
    }
    return parsed;
  }

  TextElement({
    super.id,
    super.label,
    super.show = true,
    super.attrs = const <String, Object?>{},
    String text = '',
    JsonMap style = const <String, Object?>{},
    JsonMap? size,
  }) : _text = text,
       _style = Map<String, Object?>.of(style),
       _size = size == null ? null : Map<String, Object?>.of(size),
       super(type: elementType);

  String _text;
  Map<String, Object?> _style;
  Map<String, Object?>? _size;

  String get text => _text;
  set text(String value) {
    apply(text: value);
  }

  Map<String, Object?> get style =>
      UnmodifiableMapView<String, Object?>(_style);
  set style(JsonMap value) {
    apply(style: value);
  }

  void setStyleValue(String key, Object? value) {
    apply(stylePatch: <String, Object?>{key: value});
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

  @override
  /// Applies a JSON patch to this text element.
  ///
  /// Recognized patch keys:
  /// - base keys: `label`, `show`, `attrs`
  /// - text keys: `text`, `style`, `size`
  ///
  /// Object key behavior depends on [mergeObjects]:
  /// - `true`: object values are merged as patches
  /// - `false`: object values replace existing maps
  void applyJsonPatch(JsonMap changes, {required bool mergeObjects}) {
    final labelArg = labelArgFromChanges(changes);
    final showArg = showArgFromChanges(changes);
    final attrsArg = ElementModel.asJsonMap(changes['attrs']);
    final textArg = _textArg(changes);
    final styleArg = ElementModel.asJsonMap(changes['style']);
    final sizeArg = ElementModel.asJsonMap(changes['size']);

    apply(
      label: labelArg,
      show: showArg,
      attrs: mergeObjects ? null : attrsArg,
      attrsPatch: mergeObjects ? attrsArg : null,
      text: textArg,
      style: mergeObjects ? null : styleArg,
      stylePatch: mergeObjects ? styleArg : null,
      size: mergeObjects ? null : sizeArg,
      sizePatch: mergeObjects ? sizeArg : null,
    );
  }

  @override
  /// Applies typed updates to this text element.
  ///
  /// - [text] updates displayed text.
  /// - [style]/[stylePatch] replace or patch style entries.
  /// - [size]/[sizePatch] replace or patch size entries.
  /// - [attrs]/[attrsPatch] and common fields are handled via base logic.
  ///
  /// Change notifications are emitted only when effective state changes.
  void apply({
    Object? label = ElementModel.unchanged,
    bool? show,
    JsonMap? attrs,
    JsonMap? attrsPatch,
    bool mergeAttrs = false,
    Object? text = ElementModel.unchanged,
    JsonMap? style,
    JsonMap? stylePatch,
    bool mergeStyle = false,
    JsonMap? size,
    JsonMap? sizePatch,
    bool mergeSize = false,
  }) {
    var changed = applyBaseChanges(
      label: label,
      show: show,
      attrs: attrs,
      attrsPatch: attrsPatch,
      mergeAttrs: mergeAttrs,
    );

    if (!identical(text, ElementModel.unchanged)) {
      final nextText = text as String;
      if (_text != nextText) {
        _text = nextText;
        changed = true;
      }
    }

    if (style != null) {
      final nextStyle = Map<String, Object?>.of(style);
      if (mergeStyle) {
        changed = mergeMapEntries(_style, nextStyle) || changed;
      } else if (!mapEqualsShallow(_style, nextStyle)) {
        _style = nextStyle;
        changed = true;
      }
    }

    if (stylePatch != null) {
      changed = patchMapEntries(_style, stylePatch) || changed;
    }

    if (size != null) {
      final nextSize = Map<String, Object?>.of(size);
      final currentSize = _size;
      if (currentSize == null) {
        _size = nextSize;
        changed = true;
      } else if (mergeSize) {
        changed = mergeMapEntries(currentSize, nextSize) || changed;
      } else if (!mapEqualsShallow(currentSize, nextSize)) {
        _size = nextSize;
        changed = true;
      }
    }

    if (sizePatch != null) {
      final currentSize = _size;
      if (currentSize == null) {
        final initial = <String, Object?>{};
        patchMapEntries(initial, sizePatch);
        if (initial.isNotEmpty) {
          _size = initial;
          changed = true;
        }
      } else {
        changed = patchMapEntries(currentSize, sizePatch) || changed;
      }
    }

    if (changed) {
      notifyChanged();
    }
  }

  @override
  bool get isSelectable => true;

  @override
  ElementHitScope get hitScope => ElementHitScope.children;

  @override
  JsonMap toJson() {
    final map = toJsonBase()
      ..['text'] = _text
      ..['style'] = Map<String, Object?>.of(_style);
    final sizeValue = _size;
    if (sizeValue != null) {
      map['size'] = Map<String, Object?>.of(sizeValue);
    }
    return map;
  }

  Object _textArg(JsonMap changes) {
    if (!changes.containsKey('text')) {
      return ElementModel.unchanged;
    }

    final value = changes['text'];
    if (value is String) {
      return value;
    }
    if (value == null) {
      return '';
    }
    return ElementModel.unchanged;
  }
}
