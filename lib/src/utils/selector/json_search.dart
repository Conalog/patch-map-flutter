import 'json_path_tokenizer.dart';
import 'json_search_filter_compiler.dart';

const _maxTokenCacheEntries = 512;
const _maxFilterCacheEntries = 512;

final Map<String, List<JsonPathToken>> _tokenCache = <String, List<JsonPathToken>>{};
final Map<String, JsonSearchCompiledFilter> _filterCache =
    <String, JsonSearchCompiledFilter>{};
int _tokenParseCount = 0;
int _filterCompileCount = 0;

class JsonSearchCacheStats {
  const JsonSearchCacheStats({
    required this.tokenParseCount,
    required this.filterCompileCount,
    required this.tokenCacheSize,
    required this.filterCacheSize,
  });

  final int tokenParseCount;
  final int filterCompileCount;
  final int tokenCacheSize;
  final int filterCacheSize;
}

void resetJsonSearchCachesForTest() {
  _tokenCache.clear();
  _filterCache.clear();
  _tokenParseCount = 0;
  _filterCompileCount = 0;
}

JsonSearchCacheStats jsonSearchCacheStatsForTest() {
  return JsonSearchCacheStats(
    tokenParseCount: _tokenParseCount,
    filterCompileCount: _filterCompileCount,
    tokenCacheSize: _tokenCache.length,
    filterCacheSize: _filterCache.length,
  );
}

/// Options used by [jsonSearch].
class JsonSearchOptions {
  const JsonSearchOptions({this.searchableKeys, this.flatten = false});

  /// Restricts object traversal to these keys.
  ///
  /// `null` means "walk every key".
  final List<String>? searchableKeys;

  /// Concatenates matched list values into the final result.
  final bool flatten;
}

/// A lightweight JSONPath evaluator with custom walk behavior for object keys.
List<Object?> jsonSearch({
  required JsonSearchOptions options,
  required String expression,
  required Object? json,
}) {
  if (expression.isEmpty) {
    return const <Object?>[];
  }

  final tokens = _tokenizeExpression(expression);
  final matches = _trace(tokens, _NodeRef.root(json), options.searchableKeys);

  if (!options.flatten) {
    return matches.map((match) => match.value).toList(growable: false);
  }

  final flattened = <Object?>[];
  for (final match in matches) {
    final value = match.value;
    if (value is List) {
      flattened.addAll(value);
      continue;
    }
    flattened.add(value);
  }
  return flattened;
}

List<JsonPathToken> _tokenizeExpression(String expression) {
  final cached = _tokenCache[expression];
  if (cached != null) {
    return cached;
  }

  final parsed = List<JsonPathToken>.unmodifiable(
    JsonPathTokenizer(expression).parse(),
  );
  _tokenParseCount++;
  _putCacheEntry(_tokenCache, expression, parsed, _maxTokenCacheEntries);
  return parsed;
}

JsonSearchCompiledFilter _compiledFilterFor(String expression) {
  final key = expression.trim();
  final cached = _filterCache[key];
  if (cached != null) {
    return cached;
  }

  final compiled = JsonSearchFilterCompiler.compile(key);
  _filterCompileCount++;
  _putCacheEntry(_filterCache, key, compiled, _maxFilterCacheEntries);
  return compiled;
}

void _putCacheEntry<K, V>(Map<K, V> cache, K key, V value, int maxEntries) {
  if (cache.length >= maxEntries && !cache.containsKey(key)) {
    cache.remove(cache.keys.first);
  }
  cache[key] = value;
}

List<_NodeRef> _trace(
  List<JsonPathToken> tokens,
  _NodeRef node,
  List<String>? searchableKeys,
) {
  final result = <_NodeRef>[];
  _traceInto(tokens, 0, node, searchableKeys, result);
  return result;
}

void _traceInto(
  List<JsonPathToken> tokens,
  int tokenIndex,
  _NodeRef node,
  List<String>? searchableKeys,
  List<_NodeRef> result,
) {
  if (tokenIndex >= tokens.length) {
    result.add(node);
    return;
  }

  final token = tokens[tokenIndex];
  final nextIndex = tokenIndex + 1;
  if (token is JsonPathRecursiveToken) {
    _traceInto(tokens, nextIndex, node, searchableKeys, result);
    for (final child in node.walk(searchableKeys)) {
      final value = child.value;
      if (value is Map || value is List) {
        _traceInto(tokens, tokenIndex, child, searchableKeys, result);
      }
    }
    return;
  }

  _traceToken(token, tokens, nextIndex, node, searchableKeys, result);
}

void _traceToken(
  JsonPathToken token,
  List<JsonPathToken> tokens,
  int nextIndex,
  _NodeRef node,
  List<String>? searchableKeys,
  List<_NodeRef> result,
) {
  if (token is JsonPathPropertyToken) {
    final child = node.childByKey(token.name);
    if (child != null) {
      _traceInto(tokens, nextIndex, child, searchableKeys, result);
    }
    return;
  }

  if (token is JsonPathIndexToken) {
    final child = node.childByIndex(token.index);
    if (child != null) {
      _traceInto(tokens, nextIndex, child, searchableKeys, result);
    }
    return;
  }

  if (token is JsonPathWildcardToken) {
    for (final child in node.walk(searchableKeys)) {
      _traceInto(tokens, nextIndex, child, searchableKeys, result);
    }
    return;
  }

  if (token is JsonPathFilterToken) {
    final compiled = _compiledFilterFor(token.expression);
    for (final child in node.walk(searchableKeys)) {
      if (compiled.matches(child.value)) {
        _traceInto(tokens, nextIndex, child, searchableKeys, result);
      }
    }
    return;
  }

  if (token is JsonPathSliceToken) {
    for (final child in node.slice(
      start: token.start,
      stop: token.stop,
      step: token.step,
    )) {
      _traceInto(tokens, nextIndex, child, searchableKeys, result);
    }
    return;
  }

  if (token is JsonPathUnionToken) {
    for (final selector in token.selectors) {
      _traceToken(selector, tokens, nextIndex, node, searchableKeys, result);
    }
  }
}

final class _NodeRef {
  const _NodeRef(this.value);

  final Object? value;

  static _NodeRef root(Object? value) => _NodeRef(value);

  _NodeRef? childByKey(String key) {
    final current = value;
    if (current is Map && current.containsKey(key)) {
      return _NodeRef(current[key]);
    }
    return null;
  }

  _NodeRef? childByIndex(int index) {
    final current = value;
    if (current is List) {
      final normalizedIndex = index < 0 ? current.length + index : index;
      if (normalizedIndex >= 0 && normalizedIndex < current.length) {
        return _NodeRef(current[normalizedIndex]);
      }
    }
    return null;
  }

  Iterable<_NodeRef> slice({int? start, int? stop, int step = 1}) sync* {
    final current = value;
    if (current is! List || step == 0) {
      return;
    }

    final length = current.length;
    if (step > 0) {
      var from = _normalizeSliceIndex(start ?? 0, length);
      var to = _normalizeSliceIndex(stop ?? length, length);
      from = _clamp(from, 0, length);
      to = _clamp(to, 0, length);
      for (var i = from; i < to; i += step) {
        yield _NodeRef(current[i]);
      }
      return;
    }

    var from = _normalizeSliceIndex(start ?? (length - 1), length);
    var to = stop == null ? -1 : _normalizeSliceIndex(stop, length);
    from = _clamp(from, -1, length - 1);
    to = _clamp(to, -1, length - 1);
    for (var i = from; i > to; i += step) {
      if (i >= 0 && i < length) {
        yield _NodeRef(current[i]);
      }
    }
  }

  Iterable<_NodeRef> walk(List<String>? searchableKeys) sync* {
    final current = value;

    if (current is List) {
      for (var i = 0; i < current.length; i++) {
        yield _NodeRef(current[i]);
      }
      return;
    }

    if (current is! Map) {
      return;
    }

    if (searchableKeys == null) {
      for (final entry in current.entries) {
        yield _NodeRef(entry.value);
      }
      return;
    }

    for (final key in searchableKeys) {
      if (!current.containsKey(key)) {
        continue;
      }

      final nested = current[key];
      if (_hasPositiveLength(nested)) {
        yield _NodeRef(nested);
      }
    }
  }

  bool _hasPositiveLength(Object? value) {
    if (value is String) {
      return value.isNotEmpty;
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    if (value is Map) {
      return value.isNotEmpty;
    }
    if (value is Set) {
      return value.isNotEmpty;
    }
    return false;
  }

  int _normalizeSliceIndex(int index, int length) {
    if (index < 0) {
      return length + index;
    }
    return index;
  }

  int _clamp(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}
