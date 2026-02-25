import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/utils/deepmerge/deep_merge.dart';

void main() {
  group('deepMerge basics', () {
    test('replaces primitive with primitive', () {
      expect(deepMerge(1, 2), 2);
    });

    test('replaces primitive with object', () {
      expect(deepMerge(1, {'a': 1}), {'a': 1});
    });

    test('null source clears value', () {
      expect(deepMerge({'a': 1}, null), isNull);
    });

    test('deep merges nested maps', () {
      final left = <String, Object?>{
        'show': true,
        'style': <String, Object?>{'color': 'red', 'width': 100},
      };
      final right = <String, Object?>{
        'show': false,
        'style': <String, Object?>{'height': 200},
      };

      final merged = deepMerge(left, right) as Map<Object?, Object?>;
      expect(merged, {
        'show': false,
        'style': {'color': 'red', 'width': 100, 'height': 200},
      });
      expect(left, {
        'show': true,
        'style': {'color': 'red', 'width': 100},
      });
    });
  });

  group('deepMerge list behavior', () {
    test('merges primitive list values by index and keeps tail', () {
      expect(deepMerge([1, 2, 3], [9, 8]), [9, 8, 3]);
    });

    test('appends primitive items when source list is longer', () {
      expect(deepMerge([1], [9, 8, 7]), [9, 8, 7]);
    });

    test('merges object list values by id', () {
      final left = {
        'components': [
          {
            'id': 1,
            'value': 10,
            'style': {'color': 'blue'},
          },
        ],
      };
      final right = {
        'components': [
          {
            'id': 1,
            'value': 20,
            'style': {'fontSize': 12},
          },
        ],
      };

      final merged = deepMerge(left, right) as Map<Object?, Object?>;
      expect(merged['components'], [
        {
          'id': 1,
          'value': 20,
          'style': {'color': 'blue', 'fontSize': 12},
        },
      ]);
    });

    test('uses id -> label -> type priority order', () {
      final left = {
        'components': [
          {'type': 'bar', 'value': 1},
          {'label': 'legend', 'visible': false},
        ],
      };
      final right = {
        'components': [
          {'label': 'legend', 'visible': true},
          {'type': 'bar', 'value': 2},
        ],
      };

      final merged = deepMerge(left, right) as Map<Object?, Object?>;
      expect(merged['components'], [
        {'type': 'bar', 'value': 2},
        {'label': 'legend', 'visible': true},
      ]);
    });

    test('same target item is merged only once for duplicate ids', () {
      final left = {
        'components': [
          {'id': 1, 'value': 1},
        ],
      };
      final right = {
        'components': [
          {'id': 1, 'value': 2},
          {'id': 1, 'value': 3},
        ],
      };

      final merged = deepMerge(left, right) as Map<Object?, Object?>;
      expect(merged['components'], [
        {'id': 1, 'value': 2},
        {'id': 1, 'value': 3},
      ]);
    });

    test('replace strategy replaces entire list', () {
      final merged =
          deepMerge(
                {
                  'arr': [1, 2, 3],
                },
                {
                  'arr': [4, 5],
                },
                mergeStrategy: DeepMergeStrategy.replace,
              )
              as Map<Object?, Object?>;

      expect(merged['arr'], [4, 5]);
    });

    test('custom mergeBy key is supported', () {
      final left = {
        'components': [
          {'key': 'alpha', 'value': 1},
        ],
      };
      final right = {
        'components': [
          {'key': 'alpha', 'value': 2},
        ],
      };

      final merged =
          deepMerge(left, right, mergeBy: const ['key'])
              as Map<Object?, Object?>;
      expect(merged['components'], [
        {'key': 'alpha', 'value': 2},
      ]);
    });

    test('map item without merge keys is appended', () {
      final left = {
        'components': [
          {'id': 1, 'value': 10},
        ],
      };
      final right = {
        'components': [
          {'value': 20},
        ],
      };

      final merged = deepMerge(left, right) as Map<Object?, Object?>;
      expect(merged['components'], [
        {'id': 1, 'value': 10},
        {'value': 20},
      ]);
    });
  });

  group('deepMerge edge cases', () {
    test('function value is replaced', () {
      int f1() => 1;
      int f2() => 2;

      final merged = deepMerge({'f': f1}, {'f': f2}) as Map<Object?, Object?>;
      expect(merged['f'], same(f2));
    });

    test('non-collection source object replaces target', () {
      final left = {'a': 1};
      final right = DateTime.utc(2025, 1, 1);
      expect(deepMerge(left, right), same(right));
    });

    test('source self-reference is preserved without infinite recursion', () {
      final patch = <String, Object?>{'a': 1};
      patch['self'] = patch;

      final merged = deepMerge(<String, Object?>{}, patch)!;
      expect(merged, isA<Map>());
      final map = merged as Map<Object?, Object?>;
      expect(map['a'], 1);
      expect(identical(map['self'], map), isTrue);
    });

    test('self-referential object merge keeps cycle intact', () {
      final source = <String, Object?>{};
      source['self'] = source;

      final merged = deepMerge(source, source)! as Map<Object?, Object?>;
      expect(identical(merged['self'], merged), isTrue);
    });

    test(
      'result map does not alias source map when replacing non-map target',
      () {
        final source = <String, Object?>{
          'nested': <String, Object?>{'value': 1},
        };

        final merged = deepMerge(1, source)! as Map<Object?, Object?>;
        (merged['nested'] as Map<Object?, Object?>)['value'] = 99;

        expect((source['nested'] as Map<Object?, Object?>)['value'], 1);
      },
    );

    test('replace strategy list result does not alias source list', () {
      final source = <Object?>[1, 2];

      final merged =
          deepMerge(
                <Object?>[],
                source,
                mergeStrategy: DeepMergeStrategy.replace,
              )!
              as List<Object?>;
      merged.add(3);

      expect(source, [1, 2]);
    });

    test('replace strategy clones self-referential list', () {
      final source = <Object?>[];
      source.add(source);

      final merged =
          deepMerge(
                const <Object?>[],
                source,
                mergeStrategy: DeepMergeStrategy.replace,
              )!
              as List<Object?>;

      expect(identical(merged.first, merged), isTrue);
      expect(identical(source.first, source), isTrue);
      expect(identical(merged, source), isFalse);
    });

    test('appended source map item is cloned in merged list', () {
      final right = <Object?>[
        <String, Object?>{'id': 1, 'value': 1},
      ];

      final merged = deepMerge(<Object?>[], right)! as List<Object?>;
      (merged.first as Map<Object?, Object?>)['value'] = 9;

      expect((right.first as Map<Object?, Object?>)['value'], 1);
    });

    test('untouched target nested branch is cloned in result', () {
      final left = <String, Object?>{
        'keep': <String, Object?>{'value': 1},
      };
      final right = <String, Object?>{'other': true};

      final merged = deepMerge(left, right)! as Map<Object?, Object?>;
      (merged['keep'] as Map<Object?, Object?>)['value'] = 7;

      expect((left['keep'] as Map<Object?, Object?>)['value'], 1);
    });
  });

  group('deepMerge performance guard', () {
    test('large no-match keyed list merge stays within regression budget', () {
      List<Map<String, Object?>> build(int n, int offset) {
        return List<Map<String, Object?>>.generate(
          n,
          (int i) => <String, Object?>{'id': i + offset, 'value': i},
          growable: false,
        );
      }

      // Warm up JIT for the same code path.
      deepMerge(build(200, 0), build(200, 100000));

      final left = build(8000, 0);
      final right = build(8000, 1000000);

      final stopwatch = Stopwatch()..start();
      final merged = deepMerge(left, right)! as List<Object?>;
      stopwatch.stop();

      expect(merged.length, 16000);
      expect(stopwatch.elapsedMilliseconds, lessThan(1200));
    });

    test('duplicate-key merge does not regress far beyond unique-key path', () {
      List<Map<String, Object?>> buildUnique(int n, int offset) {
        return List<Map<String, Object?>>.generate(
          n,
          (int i) => <String, Object?>{'id': i + offset, 'value': i},
          growable: false,
        );
      }

      List<Map<String, Object?>> buildAllSame(int n) {
        return List<Map<String, Object?>>.generate(
          n,
          (int i) => <String, Object?>{'id': 1, 'value': i},
          growable: false,
        );
      }

      int medianElapsedUs(void Function() run) {
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

      // Warm up JIT for both paths.
      deepMerge(buildUnique(600, 0), buildUnique(600, 100000));
      deepMerge(buildAllSame(600), buildAllSame(600));

      const n = 5000;
      final uniqueUs = medianElapsedUs(
        () => deepMerge(buildUnique(n, 0), buildUnique(n, 1000000)),
      );
      final duplicateUs = medianElapsedUs(
        () => deepMerge(buildAllSame(n), buildAllSame(n)),
      );

      // Duplicate-key path should stay in the same linear ballpark.
      expect(duplicateUs, lessThan(uniqueUs * 3));
    });
  });
}
