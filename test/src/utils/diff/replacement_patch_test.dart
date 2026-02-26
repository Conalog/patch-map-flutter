import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/utils/diff/replacement_patch.dart';

void main() {
  group('buildReplacementPatch basics', () {
    test('returns empty map for identical objects', () {
      final left = <String, Object?>{
        'a': 1,
        'b': <String, Object?>{'c': 3},
      };
      final right = <String, Object?>{
        'a': 1,
        'b': <String, Object?>{'c': 3},
      };

      expect(buildReplacementPatch(left, right), <Object?, Object?>{});
    });

    test('adds a new root key from next object', () {
      expect(
        buildReplacementPatch(
          <String, Object?>{'a': 1},
          <String, Object?>{'a': 1, 'b': 2},
        ),
        <Object?, Object?>{'b': 2},
      );
    });

    test('replaces changed primitive value', () {
      expect(
        buildReplacementPatch(
          <String, Object?>{'a': 1, 'b': 'hello'},
          <String, Object?>{'a': 1, 'b': 'world'},
        ),
        <Object?, Object?>{'b': 'world'},
      );
    });

    test('ignores keys removed from next object', () {
      final prev = <String, Object?>{'a': 1, 'b': 2, 'c': 3};
      final next = <String, Object?>{'a': 1};

      expect(buildReplacementPatch(prev, next), <Object?, Object?>{});
      expect(buildReplacementPatch(next, prev), <Object?, Object?>{
        'b': 2,
        'c': 3,
      });
    });

    test('replaces nested object when key set changes', () {
      final prev = <String, Object?>{
        'style': <String, Object?>{'width': 2, 'color': '#0C73BF'},
      };
      final next = <String, Object?>{
        'style': <String, Object?>{
          'width': 2,
          'color': '#0C73BF',
          'cap': 'round',
        },
      };

      expect(buildReplacementPatch(prev, next), <Object?, Object?>{
        'style': <String, Object?>{
          'width': 2,
          'color': '#0C73BF',
          'cap': 'round',
        },
      });
    });

    test('replaces nested object when deep value changes', () {
      final prev = <String, Object?>{
        'level1': <String, Object?>{
          'level2': <String, Object?>{
            'value': 10,
            'config': <String, Object?>{'enabled': true},
          },
          'static': 'A',
        },
      };
      final next = <String, Object?>{
        'level1': <String, Object?>{
          'level2': <String, Object?>{
            'value': 10,
            'config': <String, Object?>{'enabled': false},
          },
          'static': 'A',
        },
      };

      expect(buildReplacementPatch(prev, next), <Object?, Object?>{
        'level1': <String, Object?>{
          'level2': <String, Object?>{
            'value': 10,
            'config': <String, Object?>{'enabled': false},
          },
          'static': 'A',
        },
      });
    });
  });

  group('buildReplacementPatch type handling', () {
    test('returns empty map for identical top-level arrays', () {
      expect(
        buildReplacementPatch(
          <Object?>[
            <String, Object?>{'id': 1, 'value': 'a'},
          ],
          <Object?>[
            <String, Object?>{'id': 1, 'value': 'a'},
          ],
        ),
        <Object?, Object?>{},
      );
    });

    test('returns whole top-level array when changed', () {
      final next = <Object?>[
        <String, Object?>{'id': 1, 'value': 'a'},
        <String, Object?>{'id': 2, 'value': 'c'},
      ];

      expect(
        buildReplacementPatch(<Object?>[
          <String, Object?>{'id': 1, 'value': 'a'},
          <String, Object?>{'id': 2, 'value': 'b'},
        ], next),
        same(next),
      );
    });

    test('returns whole value when top-level value is not map', () {
      expect(
        buildReplacementPatch(null, <String, Object?>{'a': 1}),
        <String, Object?>{'a': 1},
      );
      expect(buildReplacementPatch(<String, Object?>{'a': 1}, null), isNull);
      expect(buildReplacementPatch(1, 2), 2);
    });

    test('returns whole map when runtime map type differs', () {
      final next = HashMap<String, Object?>.from(<String, Object?>{'a': 1});
      final prev = <String, Object?>{'a': 1};

      expect(buildReplacementPatch(prev, next), same(next));
    });

    test(
      'does not force full replacement for generic-only map type difference',
      () {
        final prev = <String, Object?>{
          'a': 1,
          'b': <String, Object?>{'x': 1},
        };
        final next = <Object?, Object?>{
          'a': 1,
          'b': <Object?, Object?>{'x': 2},
        };

        expect(buildReplacementPatch(prev, next), <Object?, Object?>{
          'b': <Object?, Object?>{'x': 2},
        });
      },
    );

    test('replaces changed nested list value', () {
      final next = <Object?>[
        <String, Object?>{'id': 1, 'value': 'a'},
        <String, Object?>{'id': 2, 'value': 'c'},
      ];

      expect(
        buildReplacementPatch(
          <String, Object?>{
            'data': <Object?>[
              <String, Object?>{'id': 1, 'value': 'a'},
              <String, Object?>{'id': 2, 'value': 'b'},
            ],
          },
          <String, Object?>{'data': next},
        ),
        <Object?, Object?>{'data': next},
      );
    });

    test('supports function replacement by reference', () {
      int fn1() => 1;
      int fn2() => 2;

      final result =
          buildReplacementPatch(
                <String, Object?>{'action': fn1},
                <String, Object?>{'action': fn2},
              )
              as Map<Object?, Object?>;

      expect(result['action'], same(fn2));
      expect(
        buildReplacementPatch(
          <String, Object?>{'action': fn1},
          <String, Object?>{'action': fn1},
        ),
        <Object?, Object?>{},
      );
    });

    test('supports DateTime and NaN semantics through isSame', () {
      final sameTime = DateTime.parse('2025-01-01T00:00:00Z');
      final sameTime2 = DateTime.parse('2025-01-01T00:00:00Z');
      final changedTime = DateTime.parse('2025-01-02T00:00:00Z');

      expect(
        buildReplacementPatch(
          <String, Object?>{'timestamp': sameTime},
          <String, Object?>{'timestamp': sameTime2},
        ),
        <Object?, Object?>{},
      );
      expect(
        buildReplacementPatch(
          <String, Object?>{'timestamp': sameTime},
          <String, Object?>{'timestamp': changedTime},
        ),
        <Object?, Object?>{'timestamp': changedTime},
      );

      expect(
        buildReplacementPatch(
          <String, Object?>{'v': double.nan},
          <String, Object?>{'v': double.nan},
        ),
        <Object?, Object?>{},
      );
    });
  });

  group('buildReplacementPatch circular references', () {
    test('does not throw and returns expected delta for cycles', () {
      final prev = <String, Object?>{'name': 'obj1'};
      prev['self'] = prev;

      final next = <String, Object?>{'name': 'obj2'};
      next['self'] = next;

      final sameGraph = <String, Object?>{'name': 'obj1'};
      sameGraph['self'] = sameGraph;

      expect(() => buildReplacementPatch(prev, next), returnsNormally);
      final changed =
          buildReplacementPatch(prev, next) as Map<Object?, Object?>;
      expect(changed['name'], 'obj2');
      expect(changed['self'], same(next));

      expect(buildReplacementPatch(prev, sameGraph), <Object?, Object?>{});
    });
  });

  group('buildReplacementPatch performance guard', () {
    test('large equal map stays within linear-time budget', () {
      Map<String, Object?> build(int n) {
        return Map<String, Object?>.fromEntries(
          List<MapEntry<String, Object?>>.generate(
            n,
            (int i) => MapEntry<String, Object?>('k$i', <Object?>[
              i,
              i + 1,
              <String, Object?>{'value': 'v$i'},
            ]),
            growable: false,
          ),
        );
      }

      buildReplacementPatch(build(200), build(200));

      final prev = build(6000);
      final next = build(6000);
      final stopwatch = Stopwatch()..start();
      final diff = buildReplacementPatch(prev, next);
      stopwatch.stop();

      expect(diff, <Object?, Object?>{});
      expect(stopwatch.elapsedMilliseconds, lessThan(1200));
    });

    test('tail mismatch path stays in same ballpark as equal path', () {
      Map<String, Object?> build(int n) {
        return Map<String, Object?>.fromEntries(
          List<MapEntry<String, Object?>>.generate(
            n,
            (int i) => MapEntry<String, Object?>('k$i', <String, Object?>{
              'id': i,
              'payload': <Object?>[i, i + 1, i + 2],
            }),
            growable: false,
          ),
        );
      }

      int medianElapsedUs(Object? Function() run) {
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
      final equalPrev = build(n);
      final equalNext = build(n);
      final mismatchNext = build(n);
      mismatchNext['k${n - 1}'] = <String, Object?>{
        'id': n - 1,
        'payload': <Object?>[-1, -2, -3],
      };

      buildReplacementPatch(build(200), build(200));
      buildReplacementPatch(
        build(200),
        build(200)
          ..['k199'] = <String, Object?>{
            'id': 199,
            'payload': [-1],
          },
      );

      final equalUs = medianElapsedUs(
        () => buildReplacementPatch(equalPrev, equalNext),
      );
      final mismatchUs = medianElapsedUs(
        () => buildReplacementPatch(equalPrev, mismatchNext),
      );

      expect(equalUs, greaterThan(0));
      expect(mismatchUs, lessThan(equalUs * 2));
    });
  });
}
