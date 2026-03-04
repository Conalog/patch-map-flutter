import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/utils/uid.dart';

void main() {
  group('uid', () {
    test('creates a 15-character base62 id', () {
      final value = uid();

      expect(value, hasLength(15));
      expect(value, matches(RegExp(r'^[0-9A-Za-z]{15}$')));
    });

    test('returns different values across consecutive calls', () {
      final first = uid();
      final second = uid();

      expect(second, isNot(first));
    });
  });
}
