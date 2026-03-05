/// Fast-path match metadata for `Patchmap.update(path: ...)`.
///
/// Supported forms:
/// - direct id: `$..[?(@.id=="...")]`
/// - simple equality: `$..[?(@.foo.bar==...)]`
///
/// When parsing fails, callers should fallback to selector/json-path.
final class UpdatePathFastMatch {
  const UpdatePathFastMatch({this.directId, this.simpleEquals});

  final String? directId;
  final UpdateSimpleEqualityPath? simpleEquals;
}

final class UpdateSimpleEqualityPath {
  const UpdateSimpleEqualityPath({
    required this.keyPath,
    required this.expectedValue,
  });

  final String keyPath;
  final Object? expectedValue;
}

final RegExp _directIdPathPattern = RegExp(
  r'''^\$\.\.\[\?\(@\.id==(?:\"([^\"]+)\"|'([^']+)')\)\]$''',
);
final RegExp _simpleEqualityPathPattern = RegExp(
  r'^\$\.\.\[\?\(@\.([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\s*==\s*(.+)\)\]$',
);

UpdatePathFastMatch? parseUpdatePathFastMatch(String path) {
  final normalized = path.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final directId = _parseDirectIdPath(normalized);
  if (directId != null) {
    return UpdatePathFastMatch(directId: directId);
  }

  final simple = _parseSimpleEqualityPath(normalized);
  if (simple != null) {
    return UpdatePathFastMatch(simpleEquals: simple);
  }

  return null;
}

bool updatePathLooseEquals(Object? left, Object? right) {
  if (left == null && right == null) {
    return true;
  }
  return left == right;
}

String? _parseDirectIdPath(String normalizedPath) {
  final match = _directIdPathPattern.firstMatch(normalizedPath);
  if (match == null) {
    return null;
  }
  return match.group(1) ?? match.group(2);
}

UpdateSimpleEqualityPath? _parseSimpleEqualityPath(String normalizedPath) {
  final match = _simpleEqualityPathPattern.firstMatch(normalizedPath);
  if (match == null) {
    return null;
  }

  final keyPath = match.group(1);
  final rawLiteral = match.group(2);
  if (keyPath == null || keyPath.isEmpty || rawLiteral == null) {
    return null;
  }

  return UpdateSimpleEqualityPath(
    keyPath: keyPath,
    expectedValue: _parseFilterLiteral(rawLiteral.trim()),
  );
}

Object? _parseFilterLiteral(String raw) {
  if (raw.isEmpty) {
    return '';
  }

  if ((raw.startsWith('"') && raw.endsWith('"')) ||
      (raw.startsWith("'") && raw.endsWith("'"))) {
    return _unescapeQuoted(raw.substring(1, raw.length - 1));
  }

  if (raw == 'null') {
    return null;
  }
  if (raw == 'true') {
    return true;
  }
  if (raw == 'false') {
    return false;
  }

  final numeric = num.tryParse(raw);
  if (numeric != null) {
    return numeric;
  }

  // Keep parity with JsonSearchFilterCompiler.compileTerm fallback behavior.
  return raw;
}

String _unescapeQuoted(String value) {
  if (!value.contains(r'\')) {
    return value;
  }

  final out = StringBuffer();
  var index = 0;
  while (index < value.length) {
    final current = value[index];
    if (current != r'\') {
      out.write(current);
      index += 1;
      continue;
    }

    final nextIndex = index + 1;
    if (nextIndex >= value.length) {
      out.write(r'\');
      break;
    }

    final next = value[nextIndex];
    out.write(switch (next) {
      'n' => '\n',
      'r' => '\r',
      't' => '\t',
      _ => next,
    });
    index += 2;
  }
  return out.toString();
}
