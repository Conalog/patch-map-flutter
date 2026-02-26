import 'dart:collection';
import 'dart:typed_data';

/// Deep structural equality used by diff utilities.
///
/// Rules intentionally mirror `patch-map`'s JavaScript `isSame` behavior where
/// possible, with a symmetric cycle mapping and iterative traversal to avoid
/// recursive stack overflow on very deep inputs.
bool isSame(Object? value1, Object? value2) {
  final stack = <_PendingPair>[_PendingPair(value1, value2)];
  final leftToRight = HashMap<Object, Object?>.identity();
  final rightToLeft = HashMap<Object, Object?>.identity();

  while (stack.isNotEmpty) {
    final current = stack.removeLast();
    final a = current.left;
    final b = current.right;

    if (identical(a, b)) {
      continue;
    }

    if (a is num && b is num && a.isNaN && b.isNaN) {
      continue;
    }

    if (_isScalar(a) || _isScalar(b) || a is Enum || b is Enum) {
      if (a != b) {
        return false;
      }
      continue;
    }

    if (a == null || b == null) {
      return false;
    }

    if (!_isSupportedComposite(a) || !_isSupportedComposite(b)) {
      return false;
    }

    if (a.runtimeType != b.runtimeType) {
      return false;
    }

    final objectA = a;
    final objectB = b;
    final mappedRight = leftToRight[objectA];
    final mappedLeft = rightToLeft[objectB];
    final hasMappedRight =
        mappedRight != null || leftToRight.containsKey(objectA);
    final hasMappedLeft =
        mappedLeft != null || rightToLeft.containsKey(objectB);

    if (hasMappedRight || hasMappedLeft) {
      if (!hasMappedRight || !hasMappedLeft) {
        return false;
      }
      if (!identical(mappedRight, objectB) || !identical(mappedLeft, objectA)) {
        return false;
      }
      continue;
    }

    leftToRight[objectA] = objectB;
    rightToLeft[objectB] = objectA;

    if (a is DateTime && b is DateTime) {
      if (!a.isAtSameMomentAs(b)) {
        return false;
      }
      continue;
    }

    if (a is RegExp && b is RegExp) {
      if (a.pattern != b.pattern ||
          a.isCaseSensitive != b.isCaseSensitive ||
          a.isMultiLine != b.isMultiLine ||
          a.isDotAll != b.isDotAll ||
          a.isUnicode != b.isUnicode) {
        return false;
      }
      continue;
    }

    if (a is TypedData && b is TypedData) {
      if (!_sameTypedData(a, b)) {
        return false;
      }
      continue;
    }

    if (a is List && b is List) {
      if (a.length != b.length) {
        return false;
      }

      for (var i = a.length - 1; i >= 0; i--) {
        stack.add(_PendingPair(a[i], b[i]));
      }
      continue;
    }

    if (a is Set && b is Set) {
      if (a.length != b.length) {
        return false;
      }

      final pairs = <_PendingPair>[];
      final iterA = a.iterator;
      final iterB = b.iterator;
      while (iterA.moveNext()) {
        if (!iterB.moveNext()) {
          return false;
        }
        pairs.add(_PendingPair(iterA.current, iterB.current));
      }
      if (iterB.moveNext()) {
        return false;
      }

      for (var i = pairs.length - 1; i >= 0; i--) {
        stack.add(pairs[i]);
      }
      continue;
    }

    if (a is Map && b is Map) {
      if (a.length != b.length) {
        return false;
      }

      final keys = a.keys.toList(growable: false);
      for (final key in keys) {
        if (!b.containsKey(key)) {
          return false;
        }
      }

      for (var i = keys.length - 1; i >= 0; i--) {
        final key = keys[i];
        stack.add(_PendingPair(a[key], b[key]));
      }
      continue;
    }

    return false;
  }

  return true;
}

bool _isScalar(Object? value) {
  return value is bool || value is num || value is String || value is Symbol;
}

bool _isSupportedComposite(Object value) {
  return value is DateTime ||
      value is RegExp ||
      value is TypedData ||
      value is List ||
      value is Set ||
      value is Map;
}

bool _sameTypedData(TypedData a, TypedData b) {
  if (a.lengthInBytes != b.lengthInBytes) {
    return false;
  }

  if (a is List && b is List) {
    final listA = a as List;
    final listB = b as List;
    if (listA.length != listB.length) {
      return false;
    }

    for (var i = 0; i < listA.length; i++) {
      if (listA[i] != listB[i]) {
        return false;
      }
    }
    return true;
  }

  final bytesA = a.buffer.asUint8List(a.offsetInBytes, a.lengthInBytes);
  final bytesB = b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
  for (var i = 0; i < bytesA.length; i++) {
    if (bytesA[i] != bytesB[i]) {
      return false;
    }
  }
  return true;
}

final class _PendingPair {
  const _PendingPair(this.left, this.right);

  final Object? left;
  final Object? right;
}
