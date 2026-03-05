import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/domain/elements/text_element.dart';
import 'package:patch_map_flutter/src/render/layers/text_render_layer.dart';

void main() {
  group('partial bind performance guard', () {
    test('attrs-only updates are faster than forced full bind', () {
      const iterations = 12000;
      const warmupIterations = 800;

      int runScenario({required bool partial}) {
        final layer = TextRenderLayer();
        final model = TextElement(
          id: partial ? 'bench-partial' : 'bench-full',
          text: 'benchmark-text',
          style: const <String, Object?>{
            'fontSize': 16,
            'fill': '#112233',
            'fontWeight': 700,
          },
          attrs: const <String, Object?>{'x': 0, 'y': 0, 'zIndex': 1},
          size: const <String, Object?>{'w': 180, 'h': 42},
        );
        layer.bind(model);

        for (var i = 0; i < warmupIterations; i++) {
          model.apply(attrsPatch: <String, Object?>{'x': i.toDouble()});
          if (partial) {
            layer.bind(model, changedKeys: const <String>{'attrs', 'attrs.x'});
          } else {
            layer.bind(model, changedKeys: const <String>{'*'});
          }
        }

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          model.apply(attrsPatch: <String, Object?>{'x': i.toDouble()});
          if (partial) {
            layer.bind(model, changedKeys: const <String>{'attrs', 'attrs.x'});
          } else {
            layer.bind(model, changedKeys: const <String>{'*'});
          }
        }
        sw.stop();
        return sw.elapsedMicroseconds;
      }

      int medianElapsedUs({required bool partial}) {
        final samples = <int>[];
        for (var i = 0; i < 5; i++) {
          samples.add(runScenario(partial: partial));
        }
        samples.sort();
        return samples[samples.length ~/ 2];
      }

      final fullUs = medianElapsedUs(partial: false);
      final partialUs = medianElapsedUs(partial: true);
      final speedup = fullUs / partialUs;

      print(
        '[bench] partial-bind attrs-only: full=${fullUs}us partial=${partialUs}us speedup=${speedup.toStringAsFixed(2)}x',
      );

      expect(partialUs, lessThan(fullUs));
    });
  });
}
