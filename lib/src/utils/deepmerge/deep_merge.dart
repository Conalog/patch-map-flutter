import 'dart:collection';

const List<String> _defaultMergeBy = <String>['id', 'label', 'type'];

/// Strategy used when both `target` and `source` values are lists.
enum DeepMergeStrategy {
  /// Merge list items.
  ///
  /// Primitive items are merged by index and object items (`Map`) are matched
  /// by [deepMerge]'s [mergeBy] keys in priority order.
  merge,

  /// Replace the entire target list with a cloned source list.
  replace,
}

final class _DeepMergeOptions {
  const _DeepMergeOptions({required this.mergeBy, required this.mergeStrategy});

  final List<String> mergeBy;
  final DeepMergeStrategy mergeStrategy;
}

/// Recursively merges [source] into [target] and returns a new merged value.
///
/// Rules:
/// - If [source] is not a `Map`/`List`, [source] replaces [target].
/// - If both are maps, keys are deep-merged by key.
/// - If both are lists, behavior depends on [mergeStrategy].
///   - [DeepMergeStrategy.merge]: primitive items merge by index; map items are
///     matched by [mergeBy] keys in order.
///   - [DeepMergeStrategy.replace]: source list replaces the target list.
/// - If collection types differ, a cloned [source] collection is returned.
///
/// The result does not alias mutable `Map`/`List` nodes from [target] or
/// [source], and self-referential source structures are preserved safely.
///
/// Default [mergeBy] priority is `id`, `label`, `type`.
Object? deepMerge(
  Object? target,
  Object? source, {
  List<String> mergeBy = _defaultMergeBy,
  DeepMergeStrategy mergeStrategy = DeepMergeStrategy.merge,
}) {
  final options = _DeepMergeOptions(
    mergeBy: mergeBy,
    mergeStrategy: mergeStrategy,
  );
  final mergeVisited = HashMap<Object, Object?>.identity();
  final cloneVisited = HashMap<Object, Object?>.identity();
  return _deepMerge(target, source, options, mergeVisited, cloneVisited);
}

Object? _deepMerge(
  Object? target,
  Object? source,
  _DeepMergeOptions options,
  HashMap<Object, Object?> mergeVisited,
  HashMap<Object, Object?> cloneVisited,
) {
  if (source is! Map && source is! List) {
    return source;
  }

  final sourceObject = source as Object;
  if (mergeVisited.containsKey(sourceObject)) {
    return mergeVisited[sourceObject];
  }

  if (target is List && source is List) {
    return _mergeList(
      target,
      source,
      options,
      mergeVisited,
      cloneVisited,
      sourceObject,
    );
  }

  if (target is Map && source is Map) {
    final out = _cloneMap(target, cloneVisited);
    mergeVisited[sourceObject] = out;
    cloneVisited[sourceObject] = out;

    for (final entry in source.entries) {
      out[entry.key] = _deepMerge(
        out[entry.key],
        entry.value,
        options,
        mergeVisited,
        cloneVisited,
      );
    }
    return out;
  }

  return _cloneNode(source, cloneVisited);
}

List<Object?> _mergeList(
  List target,
  List source,
  _DeepMergeOptions options,
  HashMap<Object, Object?> mergeVisited,
  HashMap<Object, Object?> cloneVisited,
  Object sourceObject,
) {
  if (options.mergeStrategy == DeepMergeStrategy.replace) {
    return _cloneList(source, cloneVisited);
  }

  final merged = _cloneList(target, cloneVisited);
  mergeVisited[sourceObject] = merged;
  cloneVisited[sourceObject] = merged;
  final used = List<bool>.filled(merged.length, false, growable: true);
  final index = _ListMergeIndex.fromList(merged, options.mergeBy);

  for (var i = 0; i < source.length; i++) {
    final item = source[i];

    if (item is Map) {
      final idx = index.find(item, used, options.mergeBy);
      if (idx != -1) {
        merged[idx] = _deepMerge(
          merged[idx],
          item,
          options,
          mergeVisited,
          cloneVisited,
        );
        used[idx] = true;
        continue;
      }

      final clonedItem = _cloneNode(item, cloneVisited);
      merged.add(clonedItem);
      used.add(true);
      continue;
    }

    final clonedItem = _cloneNode(item, cloneVisited);
    if (i < merged.length) {
      merged[i] = clonedItem;
      used[i] = true;
      continue;
    }

    merged.add(clonedItem);
    used.add(true);
  }

  return merged;
}

final class _IndexQueue {
  _IndexQueue(this.indexes);

  final List<int> indexes;
  int cursor = 0;

  int nextUnused(List<bool> used) {
    while (cursor < indexes.length) {
      final idx = indexes[cursor];
      cursor++;
      if (idx < used.length && !used[idx]) {
        return idx;
      }
    }
    return -1;
  }
}

final class _ListMergeIndex {
  _ListMergeIndex(this._byKey);

  factory _ListMergeIndex.fromList(List<Object?> items, List<String> keys) {
    final byKey = <String, Map<Object?, _IndexQueue>>{
      for (final key in keys) key: <Object?, _IndexQueue>{},
    };

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) {
        continue;
      }

      for (final key in keys) {
        if (!item.containsKey(key)) {
          continue;
        }

        final value = item[key];
        final values = byKey[key]!;
        final queue = values[value];
        if (queue == null) {
          values[value] = _IndexQueue(<int>[i]);
        } else {
          queue.indexes.add(i);
        }
      }
    }

    return _ListMergeIndex(byKey);
  }

  final Map<String, Map<Object?, _IndexQueue>> _byKey;

  int find(Map criteria, List<bool> used, List<String> priorityKeys) {
    for (final key in priorityKeys) {
      if (!criteria.containsKey(key)) {
        continue;
      }

      final criteriaValue = criteria[key];
      final queue = _byKey[key]?[criteriaValue];
      if (queue == null) {
        return -1;
      }
      return queue.nextUnused(used);
    }

    return -1;
  }
}

Object? _cloneNode(Object? value, HashMap<Object, Object?> visited) {
  if (value is Map) {
    return _cloneMap(value, visited);
  }
  if (value is List) {
    return _cloneList(value, visited);
  }
  return value;
}

Map<Object?, Object?> _cloneMap(Map source, HashMap<Object, Object?> visited) {
  final sourceObject = source as Object;
  if (visited.containsKey(sourceObject)) {
    return visited[sourceObject]! as Map<Object?, Object?>;
  }

  final out = <Object?, Object?>{};
  visited[sourceObject] = out;

  for (final entry in source.entries) {
    out[entry.key] = _cloneNode(entry.value, visited);
  }

  return out;
}

List<Object?> _cloneList(List source, HashMap<Object, Object?> visited) {
  final sourceObject = source as Object;
  if (visited.containsKey(sourceObject)) {
    return visited[sourceObject]! as List<Object?>;
  }

  final out = <Object?>[];
  visited[sourceObject] = out;

  for (final item in source) {
    out.add(_cloneNode(item, visited));
  }

  return out;
}
