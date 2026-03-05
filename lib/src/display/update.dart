import '../domain/common/json_types.dart';
import '../domain/elements/element_model.dart';
import '../state/elements_state.dart';
import '../utils/deepmerge/deep_merge.dart';
import '../utils/selector/selector.dart';
import 'update_path_match.dart';

enum PatchmapUpdateMergeStrategy { merge, replace }

final class PatchmapUpdateOptions {
  const PatchmapUpdateOptions({
    this.path,
    this.elements = const <ElementModel>[],
    this.changes,
    this.relativeTransform = false,
    this.mergeStrategy = PatchmapUpdateMergeStrategy.merge,
    this.refresh = false,
  });

  final String? path;
  final Iterable<ElementModel> elements;
  final JsonMap? changes;
  final bool relativeTransform;
  final PatchmapUpdateMergeStrategy mergeStrategy;
  final bool refresh;
}

List<ElementModel> update(
  ElementsState state, {
  PatchmapUpdateOptions options = const PatchmapUpdateOptions(),
}) {
  final targetById = <String, ElementModel>{};
  for (final element in options.elements) {
    targetById[element.id] = element;
  }

  final path = options.path;
  if (path != null && path.isNotEmpty) {
    for (final element in _elementsByPath(state, path)) {
      targetById[element.id] = element;
    }
  }
  final targets = targetById.values;

  final baseChanges = options.changes;
  final useMerge = options.mergeStrategy == PatchmapUpdateMergeStrategy.merge;
  for (final element in targets) {
    JsonMap? changes = baseChanges;
    if (baseChanges != null && options.relativeTransform) {
      changes = _cloneJsonMap(baseChanges);
      _applyRelativeTransform(element, changes);
    }

    if (changes != null) {
      element.applyJsonPatch(changes, mergeObjects: useMerge);
    }

    if (options.refresh) {
      // Force one state change event even when data is unchanged.
      state.upsert(element, changedKeys: const <String>{'*'}, refresh: true);
    }
  }

  return List<ElementModel>.unmodifiable(targets);
}

List<ElementModel> _elementsByPath(ElementsState state, String path) {
  final fastPathMatch = parseUpdatePathFastMatch(path);
  if (fastPathMatch?.directId case final directId?) {
    final model = state.byId(directId);
    if (model == null) {
      return const <ElementModel>[];
    }
    return <ElementModel>[model];
  }

  if (fastPathMatch?.simpleEquals case final simpleEq?) {
    final matched = <ElementModel>[];
    for (final model in state.elements) {
      final value = model.selectorValueAtPath(simpleEq.keyPath);
      if (identical(value, ElementModel.selectorValueNotFound)) {
        return _elementsBySelector(state, path);
      }
      if (updatePathLooseEquals(value, simpleEq.expectedValue)) {
        matched.add(model);
      }
    }
    return matched;
  }

  return _elementsBySelector(state, path);
}

List<ElementModel> _elementsBySelector(ElementsState state, String path) {
  final rootJson = state.selectorRootJsonMutable();
  final selected = selector(rootJson, path);
  final out = <ElementModel>[];
  for (final match in selected) {
    if (match is! Map) {
      continue;
    }
    final id = match['id'];
    if (id is! String) {
      continue;
    }
    final model = state.byId(id);
    if (model != null) {
      out.add(model);
    }
  }
  return out;
}

void _applyRelativeTransform(ElementModel element, JsonMap changes) {
  final attrs = ElementModel.asJsonMap(changes['attrs']);
  if (attrs == null) {
    return;
  }

  for (final key in const <String>['x', 'y', 'rotation', 'angle']) {
    final delta = attrs[key];
    if (delta is! num) {
      continue;
    }
    final current = element.attrs[key];
    final currentValue = current is num ? current : 0;
    attrs[key] = currentValue + delta;
  }
  changes['attrs'] = attrs;
}

JsonMap _cloneJsonMap(JsonMap source) {
  final cloned = deepMerge(const <String, Object?>{}, source);
  final map = ElementModel.asJsonMap(cloned);
  if (map != null) {
    return map;
  }
  return Map<String, Object?>.of(source);
}
