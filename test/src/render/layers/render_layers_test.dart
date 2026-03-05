import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/domain/elements/element_model.dart';
import 'package:patch_map_flutter/src/domain/elements/image_element.dart';
import 'package:patch_map_flutter/src/domain/elements/text_element.dart';
import 'package:patch_map_flutter/src/render/layers/builtin_element_render_layers.dart';
import 'package:patch_map_flutter/src/render/layers/element_render_host.dart';
import 'package:patch_map_flutter/src/render/layers/element_render_layer.dart';
import 'package:patch_map_flutter/src/render/layers/image_render_layer.dart';
import 'package:patch_map_flutter/src/render/layers/text_render_layer.dart';
import 'package:patch_map_flutter/src/state/elements_state.dart';

void main() {
  ensureBuiltinElementRenderLayersRegistered();

  group('ElementRenderLayer', () {
    test('applies shared render state from model', () {
      final layer = _FakeLayer();
      final model = TextElement(
        id: 'txt-1',
        show: false,
        attrs: {'x': 12, 'y': 34, 'zIndex': 7},
        text: 'hello',
      );

      layer.bind(model);

      expect(layer.model, same(model));
      expect(layer.priority, 7);
      expect(layer.isVisible, isFalse);
      expect(layer.position.x, 12);
      expect(layer.position.y, 34);
      expect(layer.syncCallCount, 1);
    });

    test('skips full sync for shared-only changed keys on partial bind', () {
      final layer = _FakeLayer();
      final model = TextElement(
        id: 'txt-1-partial',
        attrs: {'x': 12, 'y': 34, 'zIndex': 7},
        text: 'hello',
      );

      layer.bind(model);
      expect(layer.syncCallCount, 1);

      model.apply(attrsPatch: {'x': 20});
      layer.bind(model, changedKeys: const {'attrs', 'attrs.x'});

      expect(layer.position.x, 20);
      expect(layer.syncCallCount, 1);
    });
  });

  group('TextRenderLayer', () {
    test('reflects TextElement state into rendered text', () {
      final layer = TextRenderLayer();
      final model = TextElement(
        id: 'txt-2',
        text: 'before',
        attrs: {'x': 1, 'y': 2, 'zIndex': 3},
      );

      layer.bind(model);
      expect(layer.renderedText, 'before');
      expect(layer.priority, 3);
      expect(layer.position.x, 1);
      expect(layer.position.y, 2);
      expect(layer.isVisible, isTrue);

      model.apply(
        text: 'after',
        show: false,
        attrs: {'x': 10, 'y': 20, 'zIndex': 9},
      );
      layer.bind(model);

      expect(layer.renderedText, 'after');
      expect(layer.priority, 9);
      expect(layer.position.x, 10);
      expect(layer.position.y, 20);
      expect(layer.isVisible, isFalse);
    });

    test('applies patch-map-like text style defaults and overrides', () {
      final layer = TextRenderLayer();
      final model = TextElement(
        id: 'txt-style',
        text: 'styled',
        style: {'fontSize': 20},
      );

      layer.bind(model);

      expect(layer.renderedTextStyle.color, const Color(0xFF000000));
      expect(layer.renderedTextStyle.fontSize, 20);
      expect(layer.renderedTextStyle.fontFamily, endsWith('FiraCode'));

      model.apply(style: {'fill': '#ff0000', 'fontWeight': '700'});
      layer.bind(model);

      expect(layer.renderedTextStyle.color, const Color(0xFFFF0000));
      expect(layer.renderedTextStyle.fontWeight, FontWeight.w700);
    });

    test('does not force package when custom fontFamily is provided', () {
      final layer = TextRenderLayer();
      final model = TextElement(
        id: 'txt-custom-font',
        text: 'styled',
        style: {'fontFamily': 'Pretendard'},
      );

      layer.bind(model);

      expect(layer.renderedTextStyle.fontFamily, 'Pretendard');
    });

    test('uses fixed text box size and wraps when size is provided', () {
      final layer = TextRenderLayer();
      final model = TextElement(
        id: 'txt-wrap',
        text: 'one two three four five',
        style: {'fontSize': 16},
        size: {'w': 64, 'h': 48},
      );

      layer.bind(model);

      expect(layer.renderedSize.x, 64);
      expect(layer.renderedSize.y, 48);
      expect(layer.usesFixedSizeMode, isTrue);
    });

    test('applies maxWidth from size.w while keeping auto height', () {
      final baseline = TextRenderLayer();
      final baselineModel = TextElement(
        id: 'txt-baseline',
        text: 'one two three four five',
        style: {'fontSize': 16},
      );
      baseline.bind(baselineModel);
      final baselineHeight = baseline.renderedSize.y;

      final layer = TextRenderLayer();
      final model = TextElement(
        id: 'txt-width-only',
        text: 'one two three four five',
        style: {'fontSize': 16},
        size: {'w': 64},
      );

      layer.bind(model);

      expect(layer.usesFixedSizeMode, isFalse);
      expect(layer.renderedSize.x, 64);
      expect(layer.renderedSize.y, greaterThan(baselineHeight));
    });

    test('applies style before triggering text-box redraw', () {
      final spies = <_SpyTextBoxComponent>[];
      final layer = TextRenderLayer(
        componentBuilder: (size) {
          final spy = _SpyTextBoxComponent(size: size);
          spies.add(spy);
          return spy;
        },
      );
      final model = TextElement(
        id: 'txt-style-order',
        text: 'STYLE',
        style: {'fontSize': 36, 'fill': 'black'},
        size: {'w': 220, 'h': 80},
      );

      layer.bind(model);
      model.apply(style: {'fontSize': 36, 'fill': 'red'});
      layer.bind(model);

      final activeSpy = spies.last;
      expect(activeSpy.colorsAtBoxConfigSet, isNotEmpty);
      expect(activeSpy.colorsAtBoxConfigSet.last, const Color(0xFFFF0000));
    });

    test('avoids text renderer rebind when only position changed', () {
      final spies = <_SpyTextBoxComponent>[];
      final layer = TextRenderLayer(
        componentBuilder: (size) {
          final spy = _SpyTextBoxComponent(size: size);
          spies.add(spy);
          return spy;
        },
      );
      final model = TextElement(
        id: 'txt-partial',
        text: 'stable',
        style: {'fontSize': 16},
        attrs: {'x': 10, 'y': 10},
      );

      layer.bind(model);
      final activeSpy = spies.last;
      final boxConfigSetCountBefore = activeSpy.boxConfigSetCount;

      model.apply(attrsPatch: {'x': 99});
      layer.bind(model, changedKeys: const {'attrs', 'attrs.x'});

      expect(layer.position.x, 99);
      expect(activeSpy.boxConfigSetCount, boxConfigSetCountBefore);
    });
  });

  group('ImageRenderLayer', () {
    test('reflects ImageElement source and size into sprite state', () async {
      final loadedSources = <String>[];
      final layer = ImageRenderLayer(
        spriteLoader: (source) async {
          loadedSources.add(source);
          return null;
        },
      );
      final model = ImageElement(
        id: 'img-1',
        source: 'wifi',
        size: {'width': 80, 'height': 60},
        attrs: {'x': 3, 'y': 4, 'zIndex': 5},
      );

      layer.bind(model);
      await Future<void>.delayed(Duration.zero);

      expect(layer.renderedSource, 'wifi');
      expect(layer.renderedSize.x, 80);
      expect(layer.renderedSize.y, 60);
      expect(layer.priority, 5);
      expect(layer.position.x, 3);
      expect(layer.position.y, 4);
      expect(loadedSources, <String>['wifi']);

      model.apply(source: 'device', sizePatch: {'width': 120});
      layer.bind(model);
      await Future<void>.delayed(Duration.zero);

      expect(layer.renderedSource, 'device');
      expect(layer.renderedSize.x, 120);
      expect(layer.renderedSize.y, 60);
      expect(loadedSources, <String>['wifi', 'device']);
    });

    test('avoids sprite reload when only shared attrs changed', () async {
      final loadedSources = <String>[];
      final layer = ImageRenderLayer(
        spriteLoader: (source) async {
          loadedSources.add(source);
          return null;
        },
      );
      final model = ImageElement(
        id: 'img-partial',
        source: 'wifi',
        attrs: {'x': 10, 'y': 10},
      );

      layer.bind(model);
      await Future<void>.delayed(Duration.zero);
      expect(loadedSources, <String>['wifi']);

      model.apply(attrsPatch: {'x': 99});
      layer.bind(model, changedKeys: const {'attrs', 'attrs.x'});
      await Future<void>.delayed(Duration.zero);

      expect(layer.position.x, 99);
      expect(loadedSources, <String>['wifi']);
    });

    test('applies tint without forcing sprite reload', () async {
      final loadedSources = <String>[];
      final layer = ImageRenderLayer(
        spriteLoader: (source) async {
          loadedSources.add(source);
          return null;
        },
      );
      final model = ImageElement(
        id: 'img-tint',
        source: 'wifi',
        tint: '#00ff00',
      );

      layer.bind(model);
      await Future<void>.delayed(Duration.zero);

      expect(layer.renderedTint, const Color(0xFF00FF00));
      expect(loadedSources, <String>['wifi']);

      model.apply(tint: '#ff0000');
      layer.bind(model, changedKeys: const {'tint'});
      await Future<void>.delayed(Duration.zero);

      expect(layer.renderedTint, const Color(0xFFFF0000));
      expect(loadedSources, <String>['wifi']);
    });

    test('uses network fallback loader when source is http url', () async {
      final primaryLoads = <String>[];
      final networkLoads = <String>[];
      final layer = ImageRenderLayer(
        spriteLoader: (source) async {
          primaryLoads.add(source);
          return null;
        },
        networkSpriteLoader: (source) async {
          networkLoads.add(source);
          return null;
        },
      );
      const url =
          'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg';
      final model = ImageElement(id: 'img-url', source: url);

      layer.bind(model);
      await Future<void>.delayed(Duration.zero);

      expect(primaryLoads, <String>[url]);
      expect(networkLoads, <String>[url]);
    });

    test(
      'provides actionable macOS permission hint for errno=1 socket errors',
      () {
        const error =
            'SocketException: Connection failed (OS Error: Operation not '
            'permitted, errno = 1), address = images.conalog.com, port = 443';

        final hint = ImageRenderLayer.networkFailureHintFor(
          error,
          platform: TargetPlatform.macOS,
        );
        final key = ImageRenderLayer.networkFailureHintKeyFor(
          error,
          platform: TargetPlatform.macOS,
        );

        expect(hint, isNotNull);
        expect(hint, contains('com.apple.security.network.client'));
        expect(key, 'permission-denied-socket:TargetPlatform.macOS');
      },
    );

    test('provides widget-test guidance for http 400 network failures', () {
      const error =
          'Unable to load asset: "https://example.com/a.png". HTTP status '
          'code: 400';

      final hint = ImageRenderLayer.networkFailureHintFor(
        error,
        platform: TargetPlatform.android,
      );
      final key = ImageRenderLayer.networkFailureHintKeyFor(
        error,
        platform: TargetPlatform.android,
      );

      expect(hint, isNotNull);
      expect(hint, contains('Flutter widget tests'));
      expect(hint, contains('networkSpriteLoader'));
      expect(key, 'http-400');
    });
  });

  group('ElementRenderHost', () {
    test('upserts and removes text layers by element id', () {
      final host = ElementRenderHost();
      final model = TextElement(id: 'txt-host', text: 'hello');

      host.upsert(model);

      expect(host.layerCount, 1);
      final layer = host.layerByElementId('txt-host');
      expect(layer, isA<TextRenderLayer>());
      expect((layer as TextRenderLayer).renderedText, 'hello');

      model.apply(text: 'updated');
      host.upsert(model);
      expect(host.layerCount, 1);
      expect(
        (host.layerByElementId('txt-host') as TextRenderLayer).renderedText,
        'updated',
      );

      host.removeByElementId('txt-host');
      expect(host.layerCount, 0);
      expect(host.layerByElementId('txt-host'), isNull);
    });

    test('automatically reflects ElementsState changes', () {
      final host = ElementRenderHost();
      final state = ElementsState();
      host.bindElementsState(state);

      final model = TextElement(
        id: 'txt-auto',
        text: 'before',
        attrs: {'x': 5, 'y': 6, 'zIndex': 1},
      );

      state.upsert(model);
      final layer = host.layerByElementId('txt-auto') as TextRenderLayer;
      expect(layer.renderedText, 'before');
      expect(layer.position.x, 5);
      expect(layer.priority, 1);

      model.apply(
        text: 'after',
        show: false,
        attrs: {'x': 50, 'y': 60, 'zIndex': 9},
      );

      expect(layer.renderedText, 'after');
      expect(layer.isVisible, isFalse);
      expect(layer.position.x, 50);
      expect(layer.position.y, 60);
      expect(layer.priority, 9);

      state.removeById('txt-auto');
      expect(host.layerByElementId('txt-auto'), isNull);
      expect(host.layerCount, 0);
    });

    test('supports custom layer factory registration by element type', () {
      final host = ElementRenderHost();
      ElementRenderHost.registerLayerFactory(
        'custom-render-test',
        () => _CustomRenderLayer(),
      );

      final model = _CustomRenderElement(id: 'custom-render-id');
      host.upsert(model);

      expect(host.layerCount, 1);
      expect(
        host.layerByElementId('custom-render-id'),
        isA<_CustomRenderLayer>(),
      );
    });

    test('upserts image layer by element id', () {
      final host = ElementRenderHost();
      final model = ImageElement(
        id: 'img-host',
        source: 'wifi',
        size: {'width': 40, 'height': 30},
      );

      host.upsert(model);

      expect(host.layerCount, 1);
      expect(host.layerByElementId('img-host'), isA<ImageRenderLayer>());
    });
  });
}

final class _FakeLayer extends ElementRenderLayer<TextElement> {
  int syncCallCount = 0;

  @override
  void syncFromModel(
    TextElement model, {
    required Set<String>? changedKeys,
    required bool refresh,
  }) {
    syncCallCount += 1;
  }
}

final class _CustomRenderElement extends ElementModel {
  _CustomRenderElement({super.id}) : super(type: 'custom-render-test');

  @override
  Map<String, Object?> toJson() => toJsonBase();
}

final class _CustomRenderLayer
    extends ElementRenderLayer<_CustomRenderElement> {
  @override
  void syncFromModel(
    _CustomRenderElement model, {
    required Set<String>? changedKeys,
    required bool refresh,
  }) {}
}

final class _SpyTextBoxComponent extends TextBoxComponent<TextPaint> {
  _SpyTextBoxComponent({super.size})
    : super(
        text: '',
        textRenderer: TextPaint(),
        boxConfig: TextBoxConfig(
          maxWidth: size?.x ?? 1,
          margins: EdgeInsets.zero,
        ),
      );

  final List<Color?> colorsAtBoxConfigSet = <Color?>[];
  int boxConfigSetCount = 0;

  @override
  set boxConfig(TextBoxConfig value) {
    boxConfigSetCount += 1;
    final renderer = textRenderer;
    if (renderer is TextPaint) {
      colorsAtBoxConfigSet.add(renderer.style.color);
    } else {
      colorsAtBoxConfigSet.add(null);
    }
    super.boxConfig = value;
  }
}
