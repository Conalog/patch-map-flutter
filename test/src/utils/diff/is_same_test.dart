import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/utils/diff/is_same.dart';

void main() {
  group('isSame basics', () {
    test('compares primitives and nullables', () {
      expect(isSame(1, 1), isTrue);
      expect(isSame(1, 2), isFalse);
      expect(isSame('hello', 'hello'), isTrue);
      expect(isSame(true, false), isFalse);
      expect(isSame(null, null), isTrue);
      expect(isSame(null, 0), isFalse);
    });

    test('treats NaN as equal including nested values', () {
      expect(isSame(double.nan, double.nan), isTrue);
      expect(
        isSame(
          <String, Object?>{'a': double.nan},
          <String, Object?>{'a': double.nan},
        ),
        isTrue,
      );
      expect(
        isSame(<String, Object?>{'a': double.nan}, <String, Object?>{'a': 1}),
        isFalse,
      );
    });

    test('deep compares map and list values', () {
      final left = <String, Object?>{
        'a': 1,
        'b': <String, Object?>{
          'c': 3,
          'd': <Object?>[4, 5],
        },
      };
      final right = <String, Object?>{
        'a': 1,
        'b': <String, Object?>{
          'c': 3,
          'd': <Object?>[4, 5],
        },
      };
      final changed = <String, Object?>{
        'a': 1,
        'b': <String, Object?>{
          'c': 99,
          'd': <Object?>[4, 5],
        },
      };

      expect(isSame(left, right), isTrue);
      expect(isSame(left, changed), isFalse);
    });

    test('differentiates missing and explicit null keys', () {
      expect(
        isSame(<String, Object?>{'a': 1, 'b': null}, <String, Object?>{'a': 1}),
        isFalse,
      );
    });

    test('differentiates map and list', () {
      expect(
        isSame(
          <Object?>[1, 2, 3],
          <String, Object?>{'0': 1, '1': 2, '2': 3, 'length': 3},
        ),
        isFalse,
      );
    });
  });

  group('isSame special types', () {
    test('compares DateTime by instant', () {
      final v1 = DateTime.parse('2025-01-01T00:00:00Z');
      final v2 = DateTime.parse('2025-01-01T00:00:00Z');
      final v3 = DateTime.parse('2025-01-02T00:00:00Z');

      expect(isSame(v1, v2), isTrue);
      expect(isSame(v1, v3), isFalse);
    });

    test('compares RegExp by pattern and flags', () {
      expect(isSame(RegExp('abc'), RegExp('abc')), isTrue);
      expect(
        isSame(RegExp('abc'), RegExp('abc', caseSensitive: false)),
        isFalse,
      );
      expect(isSame(RegExp('abc', multiLine: true), RegExp('abc')), isFalse);
      expect(isSame(RegExp('a.b'), RegExp('a.b', dotAll: true)), isFalse);
      expect(isSame(RegExp('a.b'), RegExp('a.b', unicode: true)), isFalse);
    });

    test('compares Set values with insertion order sensitivity', () {
      final set1 = <Object?>{
        1,
        <String, Object?>{'a': 2},
      };
      final set2 = <Object?>{
        1,
        <String, Object?>{'a': 2},
      };
      final set3 = <Object?>{
        <String, Object?>{'a': 2},
        1,
      };
      final set4 = <Object?>{
        1,
        <String, Object?>{'a': 99},
      };

      expect(isSame(set1, set2), isTrue);
      expect(isSame(set1, set3), isFalse);
      expect(isSame(set1, set4), isFalse);
    });

    test('compares typed data by type and element values', () {
      final arr1 = Uint8List.fromList(<int>[1, 2, 3]);
      final arr2 = Uint8List.fromList(<int>[1, 2, 3]);
      final arr3 = Uint8List.fromList(<int>[1, 2, 4]);
      final arr4 = Float32List.fromList(<double>[1, 2, 3]);

      expect(isSame(arr1, arr2), isTrue);
      expect(isSame(arr1, arr3), isFalse);
      expect(isSame(arr1, arr4), isFalse);
    });

    test('keeps typed-data NaN semantics', () {
      final arr1 = Float32List.fromList(<double>[double.nan]);
      final arr2 = Float32List.fromList(<double>[double.nan]);
      expect(isSame(arr1, arr2), isFalse);
    });

    test('compares function references by identity', () {
      int fn() => 1;
      int fn2() => 1;
      final sameRef = fn;

      expect(isSame(fn, sameRef), isTrue);
      expect(isSame(fn, fn2), isFalse);
    });
  });

  group('isSame circular references', () {
    test('handles mutual map cycles', () {
      final a1 = <String, Object?>{};
      final a2 = <String, Object?>{};
      a1['next'] = a2;
      a2['next'] = a1;

      final b1 = <String, Object?>{};
      final b2 = <String, Object?>{};
      b1['next'] = b2;
      b2['next'] = b1;

      expect(isSame(a1, b1), isTrue);
    });

    test('keeps symmetry for non-isomorphic cyclic graphs', () {
      final a1 = <String, Object?>{};
      final a2 = <String, Object?>{};
      a1['next'] = a2;
      a2['next'] = a1;

      final b1 = <String, Object?>{};
      b1['next'] = b1;

      expect(isSame(a1, b1), isFalse);
      expect(isSame(b1, a1), isFalse);
    });

    test('handles self-referential lists', () {
      final left = <Object?>[];
      left.add(left);
      final right = <Object?>[];
      right.add(right);
      final changed = <Object?>[];
      changed.add(<Object?>[]);

      expect(isSame(left, right), isTrue);
      expect(isSame(left, changed), isFalse);
    });
  });

  group('isSame performance guard', () {
    test('very deep nesting does not overflow stack', () {
      Object deepList(int depth) {
        Object current = 0;
        for (var i = 0; i < depth; i++) {
          current = <Object?>[current];
        }
        return current;
      }

      final left = deepList(50000);
      final right = deepList(50000);

      expect(() => isSame(left, right), returnsNormally);
      expect(isSame(left, right), isTrue);
    });

    test('large nested structures stay within linear-time budget', () {
      List<Map<String, Object?>> build(int n) {
        return List<Map<String, Object?>>.generate(
          n,
          (int i) => <String, Object?>{
            'id': i,
            'payload': <Object?>[
              i,
              i + 1,
              <String, Object?>{'value': 'v$i'},
            ],
          },
          growable: false,
        );
      }

      // Warm up JIT on the same branch.
      isSame(build(200), build(200));

      final left = build(6000);
      final right = build(6000);

      final stopwatch = Stopwatch()..start();
      final result = isSame(left, right);
      stopwatch.stop();

      expect(result, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(1200));
    });

    test('tail mismatch path stays in the same ballpark as equality path', () {
      List<Map<String, Object?>> build(int n) {
        return List<Map<String, Object?>>.generate(
          n,
          (int i) => <String, Object?>{
            'id': i,
            'payload': <Object?>[i, i + 1, i + 2],
          },
          growable: false,
        );
      }

      int medianElapsedUs(bool Function() run) {
        final samples = <int>[];
        for (var i = 0; i < 5; i++) {
          final sw = Stopwatch()..start();
          run();
          sw.stop();
          samples.add(sw.elapsedMicroseconds);
        }
        samples.sort();
        return samples[samples.length ~/ 2];
      }

      const n = 5000;
      final equalLeft = build(n);
      final equalRight = build(n);
      final mismatchRight = build(n);
      mismatchRight[n - 1]['payload'] = <Object?>[-1, -2, -3];

      // Warm up JIT on both branches.
      isSame(build(200), build(200));
      isSame(build(200), build(200)..last['payload'] = <Object?>[-1, -2, -3]);

      final equalUs = medianElapsedUs(() => isSame(equalLeft, equalRight));
      final mismatchUs = medianElapsedUs(
        () => isSame(equalLeft, mismatchRight),
      );

      expect(equalUs, greaterThan(0));
      expect(mismatchUs, lessThan(equalUs * 2));
    });
  });
}
