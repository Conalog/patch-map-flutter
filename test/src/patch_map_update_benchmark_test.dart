import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';
import 'package:patch_map_flutter/src/domain/elements/element_model.dart';
import 'package:patch_map_flutter/src/domain/elements/text_element.dart';
import 'package:patch_map_flutter/src/render/layers/element_render_host.dart';
import 'package:patch_map_flutter/src/render/layers/element_render_layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('patchmap.update performance guard', () {
    test('attrs-only updates are faster without refresh full-bind', () async {
      const iterations = 3000;
      const warmupIterations = 300;

      Future<int> runScenario({required bool refresh}) async {
        final patchmap = Patchmap();
        await patchmap.init();
        final text =
            patchmap.draw(<Object?>[
                  const <String, Object?>{
                    'type': 'text',
                    'id': 'bench-text',
                    'text': 'bench',
                    'style': <String, Object?>{
                      'fontSize': 16,
                      'fill': '#112233',
                    },
                    'attrs': <String, Object?>{'x': 0, 'y': 0, 'zIndex': 1},
                    'size': <String, Object?>{'w': 160, 'h': 32},
                  },
                ]).single
                as TextElement;

        for (var i = 0; i < warmupIterations; i++) {
          patchmap.update(
            options: PatchmapUpdateOptions(
              elements: <TextElement>[text],
              changes: <String, Object?>{
                'attrs': <String, Object?>{'x': i.toDouble()},
              },
              refresh: refresh,
            ),
          );
        }

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          patchmap.update(
            options: PatchmapUpdateOptions(
              elements: <TextElement>[text],
              changes: <String, Object?>{
                'attrs': <String, Object?>{'x': i.toDouble()},
              },
              refresh: refresh,
            ),
          );
        }
        sw.stop();
        return sw.elapsedMicroseconds;
      }

      Future<int> medianElapsedUs({required bool refresh}) async {
        final samples = <int>[];
        for (var i = 0; i < 3; i++) {
          samples.add(await runScenario(refresh: refresh));
        }
        samples.sort();
        return samples[samples.length ~/ 2];
      }

      final partialUs = await medianElapsedUs(refresh: false);
      final fullUs = await medianElapsedUs(refresh: true);
      final speedup = fullUs / partialUs;

      print(
        '[bench] patchmap.update attrs-only: refresh=false ${partialUs}us, refresh=true ${fullUs}us, speedup=${speedup.toStringAsFixed(2)}x',
      );

      expect(partialUs, lessThan(fullUs));
    });

    test(
      'path updates stay in same ballpark as explicit element updates',
      () async {
        const elementCount = 400;
        const updateRounds = 20;

        ElementModel.registerDecoder(
          _BenchValueElement.elementType,
          _decodeBenchValueElement,
        );
        ElementRenderHost.registerLayerFactory(
          _BenchValueElement.elementType,
          () => _BenchValueRenderLayer(),
        );

        Future<({int explicitUs, int pathUs})> runScenario() async {
          final patchmap = Patchmap();
          await patchmap.init();

          final payload = List<Object?>.generate(
            elementCount,
            (int i) => <String, Object?>{
              'type': _BenchValueElement.elementType,
              'id': 'bench-$i',
              'value': i.isEven ? 1 : 2,
            },
            growable: false,
          );
          final models = patchmap
              .draw(payload)
              .cast<_BenchValueElement>()
              .toList(growable: false);
          final even = models
              .where((e) => e.value == 1)
              .toList(growable: false);
          final odd = models.where((e) => e.value == 2).toList(growable: false);

          // Warm up both paths.
          patchmap.update(
            options: const PatchmapUpdateOptions(
              path: r'$..[?(@.value==1)]',
              changes: <String, Object?>{'value': 2},
            ),
          );
          patchmap.update(
            options: const PatchmapUpdateOptions(
              path: r'$..[?(@.value==2)]',
              changes: <String, Object?>{'value': 1},
            ),
          );

          final explicitSw = Stopwatch()..start();
          for (var i = 0; i < updateRounds; i++) {
            patchmap.update(
              options: PatchmapUpdateOptions(
                elements: even,
                changes: const <String, Object?>{'value': 2},
              ),
            );
            patchmap.update(
              options: PatchmapUpdateOptions(
                elements: odd,
                changes: const <String, Object?>{'value': 1},
              ),
            );
            patchmap.update(
              options: PatchmapUpdateOptions(
                elements: even,
                changes: const <String, Object?>{'value': 1},
              ),
            );
            patchmap.update(
              options: PatchmapUpdateOptions(
                elements: odd,
                changes: const <String, Object?>{'value': 2},
              ),
            );
          }
          explicitSw.stop();

          final pathSw = Stopwatch()..start();
          for (var i = 0; i < updateRounds; i++) {
            patchmap.update(
              options: const PatchmapUpdateOptions(
                path: r'$..[?(@.value==1)]',
                changes: <String, Object?>{'value': 2},
              ),
            );
            patchmap.update(
              options: const PatchmapUpdateOptions(
                path: r'$..[?(@.value==2)]',
                changes: <String, Object?>{'value': 1},
              ),
            );
          }
          pathSw.stop();

          return (
            explicitUs: explicitSw.elapsedMicroseconds,
            pathUs: pathSw.elapsedMicroseconds,
          );
        }

        Future<({int explicitUs, int pathUs})> medianScenario() async {
          final samples = <({int explicitUs, int pathUs})>[];
          for (var i = 0; i < 3; i++) {
            samples.add(await runScenario());
          }
          samples.sort((a, b) => a.pathUs.compareTo(b.pathUs));
          return samples[samples.length ~/ 2];
        }

        final measured = await medianScenario();
        final ratio = measured.pathUs / measured.explicitUs;
        print(
          '[bench] path vs explicit: explicit=${measured.explicitUs}us path=${measured.pathUs}us ratio=${ratio.toStringAsFixed(2)}x',
        );

        expect(measured.pathUs, lessThan(measured.explicitUs * 4));
      },
    );
  });
}

final class _BenchValueElement extends ElementModel {
  static const String elementType = 'bench-value';

  _BenchValueElement({required this.value, super.id})
    : super(type: elementType);

  int value;

  @override
  void applyJsonPatch(
    Map<String, Object?> changes, {
    required bool mergeObjects,
  }) {
    final next = changes['value'];
    if (next is int && value != next) {
      value = next;
      notifyChanged(changedKeys: const <String>{'value'});
    }
  }

  @override
  Map<String, Object?> toJson() => toJsonBase()..['value'] = value;

  @override
  Object? selectorRootValue(String key) {
    if (key == 'value') {
      return value;
    }
    return super.selectorRootValue(key);
  }
}

_BenchValueElement _decodeBenchValueElement(Map<String, Object?> map) {
  final value = map['value'];
  if (value is! int) {
    throw const FormatException('"value" must be int for bench value element');
  }
  return _BenchValueElement(id: map['id'] as String?, value: value);
}

final class _BenchValueRenderLayer
    extends ElementRenderLayer<_BenchValueElement> {
  @override
  void syncFromModel(
    _BenchValueElement model, {
    required Set<String>? changedKeys,
    required bool refresh,
  }) {}
}
