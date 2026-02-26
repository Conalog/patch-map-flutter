import 'dart:collection';

import 'is_same.dart';

final Object _missing = Object();

/// Builds a shallow replacement patch from [previous] to [next].
///
/// Behavior mirrors patch-map's JavaScript `diff-replace`:
/// - If two non-map values are deeply equal via [isSame], returns an empty map.
/// - If top-level values are not both `Map` with a compatible map
///   implementation type,
///   returns [next] as a full replacement.
/// - Otherwise, compares only keys present in [next] and returns a map
///   containing keys whose values changed (or newly appeared).
///
/// Removed keys are intentionally ignored and do not appear in the patch.
Object? buildReplacementPatch(Object? previous, Object? next) {
  if (previous is! Map || next is! Map) {
    return isSame(previous, next) ? <Object?, Object?>{} : next;
  }

  if (!_hasCompatibleMapImplementation(previous, next)) {
    return next;
  }

  final result = <Object?, Object?>{};
  for (final key in next.keys) {
    var previousValue = previous[key];
    if (previousValue == null && !previous.containsKey(key)) {
      previousValue = _missing;
    }
    final nextValue = next[key];
    if (!isSame(previousValue, nextValue)) {
      result[key] = nextValue;
    }
  }
  return result;
}

bool _hasCompatibleMapImplementation(Map left, Map right) {
  return _mapImplementationToken(left) == _mapImplementationToken(right);
}

Object _mapImplementationToken(Map value) {
  if (value is LinkedHashMap) {
    return LinkedHashMap;
  }
  if (value is HashMap) {
    return HashMap;
  }
  if (value is SplayTreeMap) {
    return SplayTreeMap;
  }
  return value.runtimeType;
}
