import 'json_search.dart';

/// Evaluates a JSONPath expression against [json] and returns matched values.
///
/// This is a convenience wrapper over [jsonSearch] with defaults tailored for
/// patch-map node trees.
///
/// Defaults:
/// - [searchableKeys]: `['children']` (recursive walk only follows `children`)
/// - [flatten]: `true` (matched list values are concatenated into the result)
///
/// Behavior:
/// - `path == null` returns an empty list.
/// - `json == null` is treated as an empty JSON object.
/// - `searchableKeys == null` disables key restriction and traverses all keys.
List<Object?> selector(
  Object? json,
  String? path, {
  List<String>? searchableKeys = const ['children'],
  bool flatten = true,
}) {
  return jsonSearch(
    options: JsonSearchOptions(
      searchableKeys: searchableKeys,
      flatten: flatten,
    ),
    expression: path ?? '',
    json: json ?? const <String, Object?>{},
  );
}
