sealed class JsonPathToken {
  const JsonPathToken();
}

final class JsonPathRecursiveToken extends JsonPathToken {
  const JsonPathRecursiveToken();
}

final class JsonPathWildcardToken extends JsonPathToken {
  const JsonPathWildcardToken();
}

final class JsonPathPropertyToken extends JsonPathToken {
  const JsonPathPropertyToken(this.name);

  final String name;
}

final class JsonPathIndexToken extends JsonPathToken {
  const JsonPathIndexToken(this.index);

  final int index;
}

final class JsonPathFilterToken extends JsonPathToken {
  const JsonPathFilterToken(this.expression);

  final String expression;
}

final class JsonPathSliceToken extends JsonPathToken {
  const JsonPathSliceToken({this.start, this.stop, required this.step});

  final int? start;
  final int? stop;
  final int step;
}

final class JsonPathUnionToken extends JsonPathToken {
  const JsonPathUnionToken(this.selectors);

  final List<JsonPathToken> selectors;
}

final class JsonPathTokenizer {
  JsonPathTokenizer(this._source);

  final String _source;
  int _cursor = 0;

  List<JsonPathToken> parse() {
    _skipWhitespace();
    _expect(r'$');
    final tokens = <JsonPathToken>[];

    while (!_isAtEnd) {
      _skipWhitespace();
      if (_isAtEnd) {
        break;
      }

      if (_matches('..')) {
        tokens.add(const JsonPathRecursiveToken());
        continue;
      }

      final char = _peek();
      if (char == '*') {
        _advance();
        tokens.add(const JsonPathWildcardToken());
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
        tokens.add(JsonPathPropertyToken(_readIdentifier()));
        continue;
      }

      throw FormatException('Unsupported token at $_cursor in "$_source".');
    }

    return tokens;
  }

  JsonPathToken _parseDotSelector() {
    _skipWhitespace();
    if (_isAtEnd) {
      throw FormatException('Unexpected end after "." in "$_source".');
    }

    if (_peek() == '*') {
      _advance();
      return const JsonPathWildcardToken();
    }

    final name = _readIdentifier();
    if (name.isEmpty) {
      throw FormatException('Expected member name at $_cursor in "$_source".');
    }
    return JsonPathPropertyToken(name);
  }

  JsonPathToken _parseBracketSelector() {
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
      return JsonPathFilterToken(expression.trim());
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

  JsonPathToken _parseBracketContent(String content) {
    if (content.isEmpty) {
      throw FormatException('Empty bracket selector in "$_source".');
    }

    final unionParts = _splitTopLevel(content, ',');
    if (unionParts.length > 1) {
      final selectors = List<JsonPathToken>.unmodifiable(
        unionParts.map(_parseSingleBracketSelector),
      );
      return JsonPathUnionToken(selectors);
    }

    return _parseSingleBracketSelector(content);
  }

  JsonPathToken _parseSingleBracketSelector(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      throw FormatException('Empty bracket selector in "$_source".');
    }

    if (value == '*') {
      return const JsonPathWildcardToken();
    }

    if (_isWrappedByQuotes(value)) {
      return JsonPathPropertyToken(_unquote(value));
    }

    final sliceParts = _splitTopLevel(value, ':');
    if (sliceParts.length >= 2 && sliceParts.length <= 3) {
      final start = _parseNullableInt(sliceParts[0]);
      final stop = _parseNullableInt(sliceParts[1]);
      final step = sliceParts.length == 3
          ? _parseNullableInt(sliceParts[2])
          : 1;
      return JsonPathSliceToken(start: start, stop: stop, step: step ?? 1);
    }

    final index = int.tryParse(value);
    if (index != null) {
      return JsonPathIndexToken(index);
    }

    return JsonPathPropertyToken(value);
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
