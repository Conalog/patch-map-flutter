import '../domain/common/json_types.dart';
import '../domain/elements/element_model.dart';
import '../state/elements_state.dart';
import '../utils/deepmerge/deep_merge.dart';
import '../utils/selector/selector.dart';

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
      state.upsert(element);
    }
  }

  return List<ElementModel>.unmodifiable(targets);
}

List<ElementModel> _elementsByPath(ElementsState state, String path) {
  final directId = _directIdFromPath(path);
  if (directId != null) {
    final model = state.byId(directId);
    if (model == null) {
      return const <ElementModel>[];
    }
    return <ElementModel>[model];
  }

  final rootJson = state.selectorRootJson();
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

final RegExp _directIdPathPattern = RegExp(
  r'''^\$\.\.\[\?\(@\.id==(?:\"([^\"]+)\"|'([^']+)')\)\]$''',
);

String? _directIdFromPath(String path) {
  final match = _directIdPathPattern.firstMatch(path.trim());
  if (match == null) {
    return null;
  }
  return match.group(1) ?? match.group(2);
}
