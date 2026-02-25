const _maxTokenCacheEntries = 512;
const _maxFilterCacheEntries = 512;

final Map<String, List<_Token>> _tokenCache = <String, List<_Token>>{};
final Map<String, _CompiledFilter> _filterCache = <String, _CompiledFilter>{};
int _tokenParseCount = 0;
int _filterCompileCount = 0;
final Object _missing = Object();

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

List<_Token> _tokenizeExpression(String expression) {
  final cached = _tokenCache[expression];
  if (cached != null) {
    return cached;
  }

  final parsed = List<_Token>.unmodifiable(
    _JsonPathTokenizer(expression).parse(),
  );
  _tokenParseCount++;
  _putCacheEntry(_tokenCache, expression, parsed, _maxTokenCacheEntries);
  return parsed;
}

void _putCacheEntry<K, V>(Map<K, V> cache, K key, V value, int maxEntries) {
  if (cache.length >= maxEntries && !cache.containsKey(key)) {
    cache.remove(cache.keys.first);
  }
  cache[key] = value;
}

List<_NodeRef> _trace(
  List<_Token> tokens,
  _NodeRef node,
  List<String>? searchableKeys,
) {
  final result = <_NodeRef>[];
  _traceInto(tokens, 0, node, searchableKeys, result);
  return result;
}

void _traceInto(
  List<_Token> tokens,
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
  if (token is _RecursiveToken) {
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
  _Token token,
  List<_Token> tokens,
  int nextIndex,
  _NodeRef node,
  List<String>? searchableKeys,
  List<_NodeRef> result,
) {
  if (token is _PropertyToken) {
    final child = node.childByKey(token.name);
    if (child != null) {
      _traceInto(tokens, nextIndex, child, searchableKeys, result);
    }
    return;
  }

  if (token is _IndexToken) {
    final child = node.childByIndex(token.index);
    if (child != null) {
      _traceInto(tokens, nextIndex, child, searchableKeys, result);
    }
    return;
  }

  if (token is _WildcardToken) {
    for (final child in node.walk(searchableKeys)) {
      _traceInto(tokens, nextIndex, child, searchableKeys, result);
    }
    return;
  }

  if (token is _FilterToken) {
    for (final child in node.walk(searchableKeys)) {
      if (token.compiled.matches(child.value)) {
        _traceInto(tokens, nextIndex, child, searchableKeys, result);
      }
    }
    return;
  }

  if (token is _SliceToken) {
    for (final child in node.slice(
      start: token.start,
      stop: token.stop,
      step: token.step,
    )) {
      _traceInto(tokens, nextIndex, child, searchableKeys, result);
    }
    return;
  }

  if (token is _UnionToken) {
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

sealed class _Token {
  const _Token();
}

final class _RecursiveToken extends _Token {
  const _RecursiveToken();
}

final class _WildcardToken extends _Token {
  const _WildcardToken();
}

final class _PropertyToken extends _Token {
  const _PropertyToken(this.name);

  final String name;
}

final class _IndexToken extends _Token {
  const _IndexToken(this.index);

  final int index;
}

final class _FilterToken extends _Token {
  _FilterToken(this.expression) : compiled = _compiledFilterFor(expression);

  final String expression;
  final _CompiledFilter compiled;
}

final class _SliceToken extends _Token {
  const _SliceToken({this.start, this.stop, required this.step});

  final int? start;
  final int? stop;
  final int step;
}

final class _UnionToken extends _Token {
  const _UnionToken(this.selectors);

  final List<_Token> selectors;
}

final class _JsonPathTokenizer {
  _JsonPathTokenizer(this._source);

  final String _source;
  int _cursor = 0;

  List<_Token> parse() {
    _skipWhitespace();
    _expect(r'$');
    final tokens = <_Token>[];

    while (!_isAtEnd) {
      _skipWhitespace();
      if (_isAtEnd) {
        break;
      }

      if (_matches('..')) {
        tokens.add(const _RecursiveToken());
        continue;
      }

      final char = _peek();
      if (char == '*') {
        _advance();
        tokens.add(const _WildcardToken());
        continue;
      }

      if (char == '.') {
        _advance();
        tokens.add(_parseDotSelector());
        continue;
      }

      if (char == '[') {
        _advance();
        tokens.add(_parseBracketSelector());
        continue;
      }

      if (_isIdentifierChar(char)) {
        tokens.add(_PropertyToken(_readIdentifier()));
        continue;
      }

      throw FormatException('Unsupported token at $_cursor in "$_source".');
    }

    return tokens;
  }

  _Token _parseDotSelector() {
    _skipWhitespace();
    if (_isAtEnd) {
      throw FormatException('Unexpected end after "." in "$_source".');
    }

    if (_peek() == '*') {
      _advance();
      return const _WildcardToken();
    }

    final name = _readIdentifier();
    if (name.isEmpty) {
      throw FormatException('Expected member name at $_cursor in "$_source".');
    }
    return _PropertyToken(name);
  }

  _Token _parseBracketSelector() {
    _skipWhitespace();
    if (_isAtEnd) {
      throw FormatException(
        'Unexpected end in bracket selector of "$_source".',
      );
    }

    if (_peek() == '?') {
      _advance();
      _skipWhitespace();
      final expression = _readFilterExpression();
      _expect(']');
      return _FilterToken(expression.trim());
    }

    final literal = _readUntilTopLevel(']');
    _expect(']');
    return _parseBracketContent(literal.trim());
  }

  String _readFilterExpression() {
    if (_isAtEnd) {
      return '';
    }

    if (_peek() != '(') {
      return _readFilterExpressionInline();
    }

    _advance(); // opening "("
    final buffer = StringBuffer();
    var depth = 1;
    String? quote;

    while (!_isAtEnd) {
      final char = _peek();
      _advance();

      if (quote != null) {
        buffer.write(char);
        if (char == r'\') {
          if (!_isAtEnd) {
            buffer.write(_peek());
            _advance();
          }
          continue;
        }
        if (char == quote) {
          quote = null;
        }
        continue;
      }

      if (char == "'" || char == '"') {
        quote = char;
        buffer.write(char);
        continue;
      }

      if (char == '(') {
        depth++;
        buffer.write(char);
        continue;
      }

      if (char == ')') {
        depth--;
        if (depth == 0) {
          break;
        }
        buffer.write(char);
        continue;
      }

      buffer.write(char);
    }

    if (depth != 0) {
      throw FormatException('Unclosed filter expression in "$_source".');
    }

    return buffer.toString();
  }

  _Token _parseBracketContent(String content) {
    if (content.isEmpty) {
      throw FormatException('Empty bracket selector in "$_source".');
    }

    final unionParts = _splitTopLevel(content, ',');
    if (unionParts.length > 1) {
      final selectors = List<_Token>.unmodifiable(
        unionParts.map(_parseSingleBracketSelector),
      );
      return _UnionToken(selectors);
    }

    return _parseSingleBracketSelector(content);
  }

  _Token _parseSingleBracketSelector(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      throw FormatException('Empty bracket selector in "$_source".');
    }

    if (value == '*') {
      return const _WildcardToken();
    }

    if (_isWrappedByQuotes(value)) {
      return _PropertyToken(_unquote(value));
    }

    final sliceParts = _splitTopLevel(value, ':');
    if (sliceParts.length >= 2 && sliceParts.length <= 3) {
      final start = _parseNullableInt(sliceParts[0]);
      final stop = _parseNullableInt(sliceParts[1]);
      final step = sliceParts.length == 3
          ? _parseNullableInt(sliceParts[2])
          : 1;
      return _SliceToken(start: start, stop: stop, step: step ?? 1);
    }

    final index = int.tryParse(value);
    if (index != null) {
      return _IndexToken(index);
    }

    return _PropertyToken(value);
  }

  int? _parseNullableInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null) {
      throw FormatException('Invalid integer "$value" in "$_source".');
    }
    return parsed;
  }

  bool _isWrappedByQuotes(String value) =>
      (value.startsWith("'") && value.endsWith("'")) ||
      (value.startsWith('"') && value.endsWith('"'));

  String _unquote(String value) {
    final quote = value[0];
    final inner = value.substring(1, value.length - 1);
    return inner.replaceAll('\\$quote', quote).replaceAll(r'\\', r'\');
  }

  String _readFilterExpressionInline() {
    final buffer = StringBuffer();
    var parenDepth = 0;
    var bracketDepth = 0;
    String? quote;

    while (!_isAtEnd) {
      final char = _peek();
      if (quote != null) {
        _advance();
        buffer.write(char);
        if (char == r'\') {
          if (!_isAtEnd) {
            buffer.write(_peek());
            _advance();
          }
          continue;
        }
        if (char == quote) {
          quote = null;
        }
        continue;
      }

      if (char == "'" || char == '"') {
        quote = char;
        _advance();
        buffer.write(char);
        continue;
      }

      if (char == '[') {
        bracketDepth++;
        _advance();
        buffer.write(char);
        continue;
      }

      if (char == ']') {
        if (parenDepth == 0 && bracketDepth == 0) {
          break;
        }
        bracketDepth--;
        _advance();
        buffer.write(char);
        continue;
      }

      if (char == '(') {
        parenDepth++;
        _advance();
        buffer.write(char);
        continue;
      }

      if (char == ')') {
        if (parenDepth > 0) {
          parenDepth--;
        }
        _advance();
        buffer.write(char);
        continue;
      }

      _advance();
      buffer.write(char);
    }

    return buffer.toString();
  }

  String _readIdentifier() {
    final buffer = StringBuffer();
    while (!_isAtEnd) {
      final char = _peek();
      if (_isIdentifierChar(char)) {
        buffer.write(char);
        _advance();
        continue;
      }
      break;
    }
    return buffer.toString();
  }

  String _readUntilTopLevel(String stopChar) {
    final buffer = StringBuffer();
    String? quote;
    var parenDepth = 0;
    var bracketDepth = 0;

    while (!_isAtEnd) {
      final char = _peek();
      if (quote == null &&
          parenDepth == 0 &&
          bracketDepth == 0 &&
          char == stopChar) {
        break;
      }

      _advance();
      buffer.write(char);

      if (quote != null) {
        if (char == r'\') {
          if (!_isAtEnd) {
            buffer.write(_peek());
            _advance();
          }
          continue;
        }
        if (char == quote) {
          quote = null;
        }
        continue;
      }

      if (char == "'" || char == '"') {
        quote = char;
        continue;
      }

      if (char == '(') {
        parenDepth++;
        continue;
      }

      if (char == ')') {
        if (parenDepth > 0) {
          parenDepth--;
        }
        continue;
      }

      if (char == '[') {
        bracketDepth++;
        continue;
      }

      if (char == ']') {
        if (bracketDepth > 0) {
          bracketDepth--;
        }
      }
    }
    return buffer.toString();
  }

  List<String> _splitTopLevel(String source, String delimiter) {
    final parts = <String>[];
    var start = 0;
    var parenDepth = 0;
    var bracketDepth = 0;
    String? quote;

    for (var i = 0; i < source.length; i++) {
      final char = source[i];

      if (quote != null) {
        if (char == r'\') {
          i++;
          continue;
        }
        if (char == quote) {
          quote = null;
        }
        continue;
      }

      if (char == "'" || char == '"') {
        quote = char;
        continue;
      }

      if (char == '(') {
        parenDepth++;
        continue;
      }
      if (char == ')') {
        if (parenDepth > 0) {
          parenDepth--;
        }
        continue;
      }
      if (char == '[') {
        bracketDepth++;
        continue;
      }
      if (char == ']') {
        if (bracketDepth > 0) {
          bracketDepth--;
        }
        continue;
      }

      if (parenDepth == 0 &&
          bracketDepth == 0 &&
          source.startsWith(delimiter, i)) {
        parts.add(source.substring(start, i).trim());
        i += delimiter.length - 1;
        start = i + 1;
      }
    }

    if (parts.isEmpty) {
      return <String>[source.trim()];
    }

    parts.add(source.substring(start).trim());
    return parts;
  }

  bool _isIdentifierChar(String char) {
    final code = char.codeUnitAt(0);
    final isLetter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    final isDigit = code >= 48 && code <= 57;
    return isLetter || isDigit || char == '_' || char == '-';
  }

  void _skipWhitespace() {
    while (!_isAtEnd) {
      final char = _peek();
      if (char.trim().isEmpty) {
        _advance();
        continue;
      }
      break;
    }
  }

  bool _matches(String value) {
    if (_source.startsWith(value, _cursor)) {
      _cursor += value.length;
      return true;
    }
    return false;
  }

  void _expect(String expected) {
    if (!_matches(expected)) {
      throw FormatException('Expected "$expected" at $_cursor in "$_source".');
    }
  }

  String _peek() => _source[_cursor];

  void _advance() {
    _cursor++;
  }

  bool get _isAtEnd => _cursor >= _source.length;
}

typedef _CompiledBoolPredicate = bool Function(Object? context);
typedef _CompiledValueResolver = Object? Function(Object? context);

final class _CompiledFilter {
  const _CompiledFilter(this._matches);

  final _CompiledBoolPredicate _matches;

  bool matches(Object? context) => _matches(context);
}

_CompiledFilter _compiledFilterFor(String expression) {
  final key = expression.trim();
  final cached = _filterCache[key];
  if (cached != null) {
    return cached;
  }

  final compiled = _FilterEvaluator.compile(key);
  _filterCompileCount++;
  _putCacheEntry(_filterCache, key, compiled, _maxFilterCacheEntries);
  return compiled;
}

final class _FilterEvaluator {
  const _FilterEvaluator._();

  static _CompiledFilter compile(String expression) {
    final normalized = expression.trim();
    if (normalized.isEmpty) {
      return const _CompiledFilter(_alwaysFalse);
    }

    final matcher = _compileLogical(_stripOuterParens(normalized));
    return _CompiledFilter(matcher);
  }

  static _CompiledBoolPredicate _compileLogical(String expression) {
    final normalizedExpression = _stripOuterParens(expression.trim());
    if (normalizedExpression.isEmpty) {
      return _alwaysFalse;
    }

    final orParts = _splitTopLevel(normalizedExpression, '||');
    if (orParts.length > 1) {
      final parts = orParts.map(_compileLogical).toList(growable: false);
      return (context) {
        for (final predicate in parts) {
          if (predicate(context)) {
            return true;
          }
        }
        return false;
      };
    }

    final andParts = _splitTopLevel(normalizedExpression, '&&');
    if (andParts.length > 1) {
      final parts = andParts.map(_compileLogical).toList(growable: false);
      return (context) {
        for (final predicate in parts) {
          if (!predicate(context)) {
            return false;
          }
        }
        return true;
      };
    }

    return _compileComparison(normalizedExpression);
  }

  static _CompiledBoolPredicate _compileComparison(String expression) {
    final normalizedExpression = _stripOuterParens(expression.trim());
    final operators = <String>['!==', '===', '!=', '==', '<=', '>=', '<', '>'];
    for (final operator in operators) {
      final index = _findTopLevelOperator(normalizedExpression, operator);
      if (index < 0) {
        continue;
      }

      final left = normalizedExpression.substring(0, index).trim();
      final right = normalizedExpression
          .substring(index + operator.length)
          .trim();
      final leftValue = _compileTerm(left);
      final rightValue = _compileTerm(right);
      return (context) =>
          _compare(leftValue(context), rightValue(context), operator);
    }

    if (normalizedExpression.startsWith('!')) {
      final term = normalizedExpression.substring(1).trim();
      return (context) => !_evaluateTermAsPredicate(term, context);
    }

    return (context) => _evaluateTermAsPredicate(normalizedExpression, context);
  }

  static _CompiledValueResolver _compileTerm(String term) {
    final value = term.trim();
    if (value.isEmpty) {
      return _alwaysNull;
    }

    if (value == 'null') {
      return _alwaysNull;
    }
    if (value == 'true') {
      return _alwaysTrueValue;
    }
    if (value == 'false') {
      return _alwaysFalseValue;
    }
    if (value == '@') {
      return _identity;
    }

    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      final literal = _unquote(value);
      return (_) => literal;
    }

    final number = num.tryParse(value);
    if (number != null) {
      return (_) => number;
    }

    if (value.startsWith('@')) {
      final segments = _parsePathSegments(value.substring(1));
      return (context) => _resolvePath(context, segments);
    }

    return (_) => value;
  }

  static Object? _resolvePath(Object? context, List<Object> segments) {
    Object? current = context;

    for (final segment in segments) {
      if (segment is String) {
        if (current is Map && current.containsKey(segment)) {
          current = current[segment];
          continue;
        }

        if (current is List) {
          final index = int.tryParse(segment);
          if (index != null) {
            final normalizedIndex = index < 0 ? current.length + index : index;
            if (normalizedIndex >= 0 && normalizedIndex < current.length) {
              current = current[normalizedIndex];
              continue;
            }
          }
        }
      } else if (segment is int) {
        if (current is List) {
          final normalizedIndex = segment < 0
              ? current.length + segment
              : segment;
          if (normalizedIndex >= 0 && normalizedIndex < current.length) {
            current = current[normalizedIndex];
            continue;
          }
        } else if (current is Map && current.containsKey(segment.toString())) {
          current = current[segment.toString()];
          continue;
        }
      }

      return _missing;
    }
    return current;
  }

  static List<Object> _parsePathSegments(String path) {
    if (path.isEmpty) {
      return const <Object>[];
    }

    final segments = <Object>[];
    var cursor = 0;

    while (cursor < path.length) {
      final char = path[cursor];
      if (char == '.') {
        cursor++;
        continue;
      }

      if (char == '[') {
        final parsed = _parseBracketPathSegment(path, cursor);
        segments.add(parsed.segment);
        cursor = parsed.nextIndex;
        continue;
      }

      final token = StringBuffer();
      while (cursor < path.length) {
        final next = path[cursor];
        if (next == '.' || next == '[') {
          break;
        }
        token.write(next);
        cursor++;
      }

      final normalized = token.toString().trim();
      if (normalized.isNotEmpty) {
        segments.add(normalized);
      }
    }

    return segments;
  }

  static ({Object segment, int nextIndex}) _parseBracketPathSegment(
    String path,
    int start,
  ) {
    var cursor = start + 1;
    while (cursor < path.length && path[cursor].trim().isEmpty) {
      cursor++;
    }

    if (cursor >= path.length) {
      return (segment: '', nextIndex: cursor);
    }

    final char = path[cursor];
    if (char == "'" || char == '"') {
      final quote = char;
      cursor++;
      final buffer = StringBuffer();
      while (cursor < path.length) {
        final value = path[cursor];
        cursor++;
        if (value == r'\') {
          if (cursor < path.length) {
            buffer.write(path[cursor]);
            cursor++;
          }
          continue;
        }
        if (value == quote) {
          break;
        }
        buffer.write(value);
      }

      while (cursor < path.length && path[cursor].trim().isEmpty) {
        cursor++;
      }
      if (cursor < path.length && path[cursor] == ']') {
        cursor++;
      }
      return (segment: buffer.toString(), nextIndex: cursor);
    }

    final buffer = StringBuffer();
    while (cursor < path.length && path[cursor] != ']') {
      buffer.write(path[cursor]);
      cursor++;
    }
    if (cursor < path.length && path[cursor] == ']') {
      cursor++;
    }

    final raw = buffer.toString().trim();
    final index = int.tryParse(raw);
    if (index != null) {
      return (segment: index, nextIndex: cursor);
    }
    return (segment: raw, nextIndex: cursor);
  }

  static bool _compare(Object? left, Object? right, String operator) {
    if (_isMissing(left) || _isMissing(right)) {
      return false;
    }

    switch (operator) {
      case '==':
        return _looseEquals(left, right);
      case '!=':
        return !_looseEquals(left, right);
      case '===':
        return _strictEquals(left, right);
      case '!==':
        return !_strictEquals(left, right);
      case '<':
        return _compareOrdered(left, right, (result) => result < 0);
      case '>':
        return _compareOrdered(left, right, (result) => result > 0);
      case '<=':
        return _compareOrdered(left, right, (result) => result <= 0);
      case '>=':
        return _compareOrdered(left, right, (result) => result >= 0);
      default:
        return false;
    }
  }

  static bool _evaluateTermAsPredicate(String expression, Object? context) {
    final normalized = _stripOuterParens(expression.trim());
    if (normalized.isEmpty) {
      return false;
    }

    final value = _compileTerm(normalized)(context);
    if (normalized.startsWith('@')) {
      return !_isMissing(value);
    }

    return _isTruthy(value);
  }

  static bool _isMissing(Object? value) => identical(value, _missing);

  static bool _compareOrdered(
    Object? left,
    Object? right,
    bool Function(int result) predicate,
  ) {
    if (left is num && right is num) {
      return predicate(left.compareTo(right));
    }
    if (left is String && right is String) {
      return predicate(left.compareTo(right));
    }
    return false;
  }

  static bool _looseEquals(Object? left, Object? right) {
    if (left == null && right == null) {
      return true;
    }
    return left == right;
  }

  static bool _strictEquals(Object? left, Object? right) {
    if (left == null || right == null) {
      return left == right;
    }
    return left.runtimeType == right.runtimeType && left == right;
  }

  static bool _isTruthy(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value.isNotEmpty;
    }
    if (value is List || value is Map || value is Set) {
      return true;
    }
    return true;
  }

  static String _unquote(String value) {
    final quote = value[0];
    final inner = value.substring(1, value.length - 1);
    return inner.replaceAll('\\$quote', quote).replaceAll(r'\\', r'\');
  }

  static String _stripOuterParens(String expression) {
    var result = expression.trim();
    while (result.startsWith('(') && result.endsWith(')')) {
      if (!_isFullyWrappedByParens(result)) {
        break;
      }
      result = result.substring(1, result.length - 1).trim();
    }
    return result;
  }

  static bool _isFullyWrappedByParens(String expression) {
    var depth = 0;
    String? quote;

    for (var i = 0; i < expression.length; i++) {
      final char = expression[i];
      if (quote != null) {
        if (char == r'\') {
          i++;
          continue;
        }
        if (char == quote) {
          quote = null;
        }
        continue;
      }

      if (char == "'" || char == '"') {
        quote = char;
        continue;
      }

      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
        if (depth == 0 && i != expression.length - 1) {
          return false;
        }
      }
    }
    return depth == 0;
  }

  static List<String> _splitTopLevel(String expression, String delimiter) {
    final parts = <String>[];
    var depth = 0;
    String? quote;
    var start = 0;

    for (var i = 0; i < expression.length; i++) {
      final char = expression[i];

      if (quote != null) {
        if (char == r'\') {
          i++;
          continue;
        }
        if (char == quote) {
          quote = null;
        }
        continue;
      }

      if (char == "'" || char == '"') {
        quote = char;
        continue;
      }

      if (char == '(') {
        depth++;
        continue;
      }
      if (char == ')') {
        depth--;
        continue;
      }

      if (depth == 0 &&
          expression.startsWith(delimiter, i) &&
          delimiter.isNotEmpty) {
        parts.add(expression.substring(start, i).trim());
        i += delimiter.length - 1;
        start = i + 1;
      }
    }

    if (parts.isEmpty) {
      return <String>[expression.trim()];
    }

    parts.add(expression.substring(start).trim());
    return parts.where((part) => part.isNotEmpty).toList(growable: false);
  }

  static int _findTopLevelOperator(String expression, String operator) {
    var depth = 0;
    String? quote;

    for (var i = 0; i <= expression.length - operator.length; i++) {
      final char = expression[i];

      if (quote != null) {
        if (char == r'\') {
          i++;
          continue;
        }
        if (char == quote) {
          quote = null;
        }
        continue;
      }

      if (char == "'" || char == '"') {
        quote = char;
        continue;
      }

      if (char == '(') {
        depth++;
        continue;
      }
      if (char == ')') {
        depth--;
        continue;
      }

      if (depth == 0 && expression.startsWith(operator, i)) {
        return i;
      }
    }

    return -1;
  }
}

bool _alwaysFalse(Object? _) => false;
Object? _alwaysNull(Object? _) => null;
Object? _alwaysTrueValue(Object? _) => true;
Object? _alwaysFalseValue(Object? _) => false;
Object? _identity(Object? context) => context;
