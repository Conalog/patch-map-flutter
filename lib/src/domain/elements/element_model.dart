import 'dart:collection';

import '../common/json_types.dart';
import '../../utils/uid.dart';

typedef ElementModelListener =
    void Function(ElementModel model, ElementModelChange change);
typedef ElementModelDecoder = ElementModel Function(JsonMap map);

final class ElementModelChange {
  const ElementModelChange({required this.changedKeys, this.refresh = false});

  final Set<String> changedKeys;
  final bool refresh;
}

/// Mirrors patch-map's Element static hit policy.
enum ElementHitScope { self, children }

/// Base model shared by all top-level element models.
///
/// Original patch-map references:
/// - Base schema defaults: `show`, `id`, `label`, `attrs`
/// - Element class defaults reused in this Flutter port:
///   `isSelectable=false`, `hitScope='self'`
/// - Resize capability is intentionally not modeled yet in patch_map_flutter.
abstract class ElementModel {
  static const Object unchanged = Object();
  static const Object selectorValueNotFound = Object();
  static final Map<String, ElementModelDecoder> _decoderByType =
      <String, ElementModelDecoder>{};

  static void registerDecoder(String type, ElementModelDecoder decoder) {
    final normalizedType = type.trim();
    if (normalizedType.isEmpty) {
      throw ArgumentError.value(type, 'type', 'type must not be empty');
    }

    final existing = _decoderByType[normalizedType];
    if (existing != null) {
      if (identical(existing, decoder)) {
        return;
      }
      throw StateError(
        'Decoder already registered for element type: $normalizedType',
      );
    }
    _decoderByType[normalizedType] = decoder;
  }

  static ElementModel decode(Object? raw) {
    final map = asJsonMap(raw);
    if (map == null) {
      throw const FormatException(
        'draw() expects each element to be a JSON object.',
      );
    }

    final type = map['type'];
    if (type is! String || type.isEmpty) {
      throw const FormatException(
        'draw() element object must include non-empty string "type".',
      );
    }

    final decoder = _decoderByType[type];
    if (decoder == null) {
      throw UnsupportedError('Unsupported element type: $type');
    }
    return decoder(map);
  }

  static JsonMap? asJsonMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    final out = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) {
        out[key] = entry.value;
      }
    }
    return out;
  }

  ElementModel({
    required this.type,
    String? id,
    String? label,
    bool show = true,
    JsonMap attrs = const <String, Object?>{},
  }) : id = id ?? uid(),
       _label = label,
       _show = show,
       _attrs = Map<String, Object?>.of(attrs);

  final String type;
  final String id;
  final Set<ElementModelListener> _listeners = <ElementModelListener>{};
  String? _label;
  bool _show;
  Map<String, Object?> _attrs;

  String? get label => _label;
  set label(String? value) {
    apply(label: value);
  }

  bool get show => _show;
  set show(bool value) {
    apply(show: value);
  }

  Map<String, Object?> get attrs =>
      UnmodifiableMapView<String, Object?>(_attrs);
  set attrs(JsonMap value) {
    apply(attrs: value);
  }

  void setAttr(String key, Object? value) {
    apply(attrsPatch: <String, Object?>{key: value});
  }

  void apply({
    Object? label = unchanged,
    bool? show,
    JsonMap? attrs,
    JsonMap? attrsPatch,
    bool mergeAttrs = false,
  }) {
    final changedKeys = applyBaseChanges(
      label: label,
      show: show,
      attrs: attrs,
      attrsPatch: attrsPatch,
      mergeAttrs: mergeAttrs,
    );
    if (changedKeys.isNotEmpty) {
      notifyChanged(changedKeys: changedKeys);
    }
  }

  /// Applies generic JSON patch fields handled by all element models.
  ///
  /// Subclasses can override and call their own typed [apply] to support
  /// additional fields while preserving one-shot notification semantics.
  void applyJsonPatch(JsonMap changes, {required bool mergeObjects}) {
    final labelArg = labelArgFromChanges(changes);
    final showArg = showArgFromChanges(changes);
    final attrsArg = asJsonMap(changes['attrs']);
    apply(
      label: labelArg,
      show: showArg,
      attrs: mergeObjects ? null : attrsArg,
      attrsPatch: mergeObjects ? attrsArg : null,
    );
  }

  void addListener(ElementModelListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ElementModelListener listener) {
    _listeners.remove(listener);
  }

  void notifyChanged({required Set<String> changedKeys, bool refresh = false}) {
    if (_listeners.isEmpty) {
      return;
    }
    final snapshot = Set<String>.unmodifiable(changedKeys);
    final listeners = List<ElementModelListener>.of(_listeners);
    for (final listener in listeners) {
      listener(
        this,
        ElementModelChange(changedKeys: snapshot, refresh: refresh),
      );
    }
  }

  Set<String> applyBaseChanges({
    Object? label = unchanged,
    bool? show,
    JsonMap? attrs,
    JsonMap? attrsPatch,
    bool mergeAttrs = false,
  }) {
    final changedKeys = <String>{};

    if (!identical(label, unchanged)) {
      final next = label as String?;
      if (_label != next) {
        _label = next;
        changedKeys.add('label');
      }
    }

    if (show != null && _show != show) {
      _show = show;
      changedKeys.add('show');
    }

    if (attrs != null) {
      final nextAttrs = Map<String, Object?>.of(attrs);
      if (mergeAttrs) {
        final attrKeys = mergeMapEntries(_attrs, nextAttrs);
        if (attrKeys.isNotEmpty) {
          changedKeys.add('attrs');
          changedKeys.addAll(attrKeys.map((key) => 'attrs.$key'));
        }
      } else if (!mapEqualsShallow(_attrs, nextAttrs)) {
        final attrKeys = changedMapKeys(_attrs, nextAttrs);
        _attrs = nextAttrs;
        changedKeys.add('attrs');
        changedKeys.addAll(attrKeys.map((key) => 'attrs.$key'));
      }
    }

    if (attrsPatch != null) {
      final attrKeys = patchMapEntries(_attrs, attrsPatch);
      if (attrKeys.isNotEmpty) {
        changedKeys.add('attrs');
        changedKeys.addAll(attrKeys.map((key) => 'attrs.$key'));
      }
    }

    return changedKeys;
  }

  Set<String> mergeMapEntries(
    Map<String, Object?> target,
    Map<String, Object?> source,
  ) {
    final changedKeys = <String>{};
    source.forEach((key, value) {
      if (!target.containsKey(key) || target[key] != value) {
        target[key] = value;
        changedKeys.add(key);
      }
    });
    return changedKeys;
  }

  Set<String> patchMapEntries(
    Map<String, Object?> target,
    Map<String, Object?> patch,
  ) {
    final changedKeys = <String>{};
    patch.forEach((key, value) {
      if (value == null) {
        if (target.containsKey(key)) {
          target.remove(key);
          changedKeys.add(key);
        }
        return;
      }

      if (!target.containsKey(key) || target[key] != value) {
        target[key] = value;
        changedKeys.add(key);
      }
    });
    return changedKeys;
  }

  Set<String> changedMapKeys(
    Map<String, Object?> previous,
    Map<String, Object?> next,
  ) {
    final changed = <String>{};
    for (final key in previous.keys) {
      if (!next.containsKey(key)) {
        changed.add(key);
      }
    }
    for (final entry in next.entries) {
      if (!previous.containsKey(entry.key) ||
          previous[entry.key] != entry.value) {
        changed.add(entry.key);
      }
    }
    return changed;
  }

  bool mapEqualsShallow(Map<String, Object?> left, Map<String, Object?> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key)) {
        return false;
      }
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  /// patch-map stores z-index under attrs.zIndex.
  num get zIndex {
    final raw = _attrs['zIndex'];
    return raw is num ? raw : 0;
  }

  /// Matches patch-map Element default (`false`).
  bool get isSelectable => false;

  /// Matches patch-map Element default (`self`).
  ElementHitScope get hitScope => ElementHitScope.self;

  /// Serializes base/common fields shared across all element models.
  JsonMap toJsonBase() {
    final map = <String, Object?>{'type': type, 'id': id, 'show': show};
    final currentLabel = _label;
    if (currentLabel != null) {
      map['label'] = currentLabel;
    }
    if (_attrs.isNotEmpty) {
      map['attrs'] = Map<String, Object?>.of(_attrs);
    }
    return map;
  }

  JsonMap toJson();

  /// Returns the value at [keyPath] for selector/path matching.
  ///
  /// The default implementation supports base root keys (`id`, `type`,
  /// `label`, `show`, `attrs`) plus nested lookups through maps/lists.
  /// Subclasses can override [selectorRootValue] to expose typed root keys
  /// without serializing a full JSON map.
  Object? selectorValueAtPath(String keyPath) {
    final normalized = keyPath.trim();
    if (normalized.isEmpty) {
      return selectorValueNotFound;
    }

    final segments = normalized.split('.');
    var current = selectorRootValue(segments.first);
    if (identical(current, selectorValueNotFound)) {
      return selectorValueNotFound;
    }

    for (var i = 1; i < segments.length; i++) {
      final segment = segments[i];
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
        continue;
      }
      if (current is List) {
        final index = int.tryParse(segment);
        if (index == null) {
          return selectorValueNotFound;
        }
        final normalizedIndex = index < 0 ? current.length + index : index;
        if (normalizedIndex < 0 || normalizedIndex >= current.length) {
          return selectorValueNotFound;
        }
        current = current[normalizedIndex];
        continue;
      }
      return selectorValueNotFound;
    }

    return current;
  }

  /// Root-level selector lookup hook for subclasses.
  Object? selectorRootValue(String key) {
    return switch (key) {
      'id' => id,
      'type' => type,
      'label' => _label,
      'show' => _show,
      'attrs' => _attrs,
      _ => selectorValueNotFound,
    };
  }

  Object? labelArgFromChanges(JsonMap changes) {
    if (!changes.containsKey('label')) {
      return unchanged;
    }
    final value = changes['label'];
    if (value == null || value is String) {
      return value;
    }
    return unchanged;
  }

  bool? showArgFromChanges(JsonMap changes) {
    final value = changes['show'];
    return value is bool ? value : null;
  }
}
