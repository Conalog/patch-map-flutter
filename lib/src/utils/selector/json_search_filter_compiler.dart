typedef _CompiledBoolPredicate = bool Function(Object? context);
typedef _CompiledValueResolver = Object? Function(Object? context);

final class JsonSearchCompiledFilter {
  const JsonSearchCompiledFilter(this._matches);

  final _CompiledBoolPredicate _matches;

  bool matches(Object? context) => _matches(context);
}

final class JsonSearchFilterCompiler {
  const JsonSearchFilterCompiler._();

  static final Object _missing = Object();

  static JsonSearchCompiledFilter compile(String expression) {
    final normalized = expression.trim();
    if (normalized.isEmpty) {
      return const JsonSearchCompiledFilter(_alwaysFalse);
    }

    final matcher = _compileLogical(_stripOuterParens(normalized));
    return JsonSearchCompiledFilter(matcher);
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
