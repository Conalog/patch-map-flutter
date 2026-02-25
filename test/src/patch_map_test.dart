import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';

void main() {
  group('Patchmap', () {
    test('can be instantiated', () {
      final instance = Patchmap();
      expect(instance, isA<Patchmap>());
    });
  });
}
