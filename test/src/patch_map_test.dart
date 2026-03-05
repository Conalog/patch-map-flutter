import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';
import 'package:patch_map_flutter/src/domain/elements/element_model.dart';
import 'package:patch_map_flutter/src/domain/elements/text_element.dart';
import 'package:patch_map_flutter/src/render/layers/element_render_host.dart';
import 'package:patch_map_flutter/src/runtime/patchmap_asset_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Patchmap', () {
    test('can be instantiated', () {
      final instance = Patchmap();
      expect(instance, isA<Patchmap>());
    });

    test('can be instantiated with injected runtime', () {
      final runtime = PatchmapRuntime(
        assetRegistry: PatchmapAssetRegistry(
          assetStringLoader: (_) async => '<svg viewBox="0 0 24 24"></svg>',
        ),
      );
      final instance = Patchmap(runtime: runtime);
      expect(identical(instance.app, runtime), isTrue);
    });

    test('exposes runtime via app', () {
      final instance = Patchmap();
      expect(instance.app, isA<PatchmapRuntime>());
    });

    test('init marks runtime assets as ready', () async {
      final instance = Patchmap();

      expect(instance.app.assetsReady, isFalse);

      await instance.init();

      expect(instance.app.assetsReady, isTrue);
    });

    test('init is idempotent', () async {
      final instance = Patchmap();

      await instance.init();
      await instance.init();

      expect(instance.app.assetsReady, isTrue);
    });

    test('init preloads bundled icons', () async {
      final instance = Patchmap();

      expect(instance.app.assetsReady, isFalse);

      await instance.init();

      expect(instance.app.assetsReady, isTrue);
      expect(
        instance.app.iconSvgByAlias.keys,
        containsAll(<String>[
          'object',
          'inverter',
          'combiner',
          'device',
          'edge',
          'loading',
          'warning',
          'wifi',
        ]),
      );
    });

    test('init merges additional icon assets from options', () async {
      final instance = Patchmap();

      await instance.init(
        options: const PatchmapInitOptions(
          assets: PatchmapInitAssets(
            iconAssetPathByAlias: <String, String>{
              'custom-wifi': 'assets/icons/wifi.svg',
            },
          ),
        ),
      );

      expect(instance.app.iconSvgByAlias.keys, contains('custom-wifi'));
      expect(instance.app.iconSvgByAlias['custom-wifi'], contains('<svg'));
    });

    test('iconSprite creates and caches sprite by alias and size', () async {
      final instance = Patchmap();
      await instance.init();

      final spriteA = await instance.app.iconSprite('wifi');
      final spriteB = await instance.app.iconSprite('wifi');
      final spriteC = await instance.app.iconSprite('wifi', edgePx: 64);

      expect(spriteA, isA<Sprite>());
      expect(identical(spriteA, spriteB), isTrue);
      expect(identical(spriteA, spriteC), isFalse);
    });

    test('iconSprite throws for unknown alias', () async {
      final instance = Patchmap();
      await instance.init();

      expect(
        () => instance.app.iconSprite('does-not-exist'),
        throwsA(isA<StateError>()),
      );
    });

    test('init applies app background color option', () async {
      final instance = Patchmap();
      const background = Color(0xFF123456);

      await instance.init(
        options: const PatchmapInitOptions(
          app: PatchmapInitAppOptions(backgroundColor: background),
        ),
      );

      expect(instance.app.backgroundColor(), background);
    });

    test('runtime uses topLeft world origin after first layout', () async {
      final instance = Patchmap();

      await instance.init();
      instance.app.onGameResize(Vector2(320, 240));

      expect(instance.app.camera.viewfinder.anchor, Anchor.topLeft);
      expect(instance.app.camera.viewfinder.position.x, 0);
      expect(instance.app.camera.viewfinder.position.y, 0);
    });

    test('init mounts a single render host bound to elements state', () async {
      final instance = Patchmap();

      await instance.init();
      await instance.init();

      final hosts = instance.app.world.children
          .whereType<ElementRenderHost>()
          .toList();
      expect(hosts, hasLength(1));

      instance.draw(<Object?>[
        <String, Object?>{'type': 'text', 'id': 'txt-core', 'text': 'core'},
      ]);

      expect(hosts.single.layerByElementId('txt-core'), isNotNull);
    });

    test('update applies changes to explicit elements with default merge', () {
      final instance = Patchmap();
      final text =
          instance.draw(<Object?>[
                <String, Object?>{
                  'type': 'text',
                  'id': 'txt-1',
                  'text': 'before',
                  'attrs': <String, Object?>{'x': 10, 'y': 20, 'zIndex': 1},
                  'style': <String, Object?>{'fontSize': 12},
                },
              ]).single
              as TextElement;

      final updated = instance.update(
        options: PatchmapUpdateOptions(
          elements: <TextElement>[text],
          changes: <String, Object?>{
            'text': 'after',
            'attrs': <String, Object?>{'x': 30},
            'style': <String, Object?>{'fill': 'red'},
          },
        ),
      );

      expect(updated, [same(text)]);
      expect(text.text, 'after');
      expect(text.attrs, <String, Object?>{'x': 30, 'y': 20, 'zIndex': 1});
      expect(text.style, <String, Object?>{'fontSize': 12, 'fill': 'red'});
    });

    test('update resolves targets by path', () {
      final instance = Patchmap();
      final drawn = instance.draw(<Object?>[
        <String, Object?>{'type': 'text', 'id': 'txt-a', 'text': 'A'},
        <String, Object?>{'type': 'text', 'id': 'txt-b', 'text': 'B'},
      ]);
      final first = drawn[0] as TextElement;
      final second = drawn[1] as TextElement;

      final updated = instance.update(
        options: const PatchmapUpdateOptions(
          path: r'$..[?(@.id=="txt-b")]',
          changes: <String, Object?>{'show': false},
        ),
      );

      expect(updated, [same(second)]);
      expect(first.show, isTrue);
      expect(second.show, isFalse);
    });

    test('selector reads from fixed state root with path only', () {
      final instance = Patchmap();
      instance.draw(<Object?>[
        <String, Object?>{'type': 'text', 'id': 'txt-a', 'text': 'A'},
        <String, Object?>{'type': 'text', 'id': 'txt-b', 'text': 'B'},
      ]);

      final selected = instance.selector(r'$..[?(@.id=="txt-b")]');

      expect(selected, hasLength(1));
      expect((selected.single as Map<String, Object?>)['id'], 'txt-b');
    });

    test('selector applies opts for traversal restriction', () {
      final instance = Patchmap();
      instance.draw(<Object?>[
        <String, Object?>{
          'type': 'text',
          'id': 'txt-style',
          'style': <String, Object?>{'fontSize': 24},
        },
      ]);

      final withDefaultKeys = instance.selector(r'$..[?(@.fontSize==24)]');
      final withAllKeys = instance.selector(
        r'$..[?(@.fontSize==24)]',
        const PatchmapSelectorOptions(searchableKeys: null),
      );

      expect(withDefaultKeys, isEmpty);
      expect(withAllKeys, hasLength(1));
      expect((withAllKeys.single as Map<String, Object?>)['fontSize'], 24);
    });

    test('selector applies opts for flatten behavior', () {
      final instance = Patchmap();
      instance.draw(<Object?>[
        <String, Object?>{'type': 'text', 'id': 'txt-a', 'text': 'A'},
      ]);

      final flattened = instance.selector(r'$..children');
      final notFlattened = instance.selector(
        r'$..children',
        const PatchmapSelectorOptions(flatten: false),
      );

      expect(flattened, hasLength(1));
      expect(flattened.single, isA<Map<String, Object?>>());
      expect(notFlattened, hasLength(1));
      expect(notFlattened.single, isA<List<Object?>>());
    });

    test('update applies relative transform to attrs.x/y', () {
      final instance = Patchmap();
      final text =
          instance.draw(<Object?>[
                <String, Object?>{
                  'type': 'text',
                  'id': 'txt-rel',
                  'text': 'rel',
                  'attrs': <String, Object?>{'x': 10, 'y': 5},
                },
              ]).single
              as TextElement;

      instance.update(
        options: PatchmapUpdateOptions(
          elements: <TextElement>[text],
          relativeTransform: true,
          changes: <String, Object?>{
            'attrs': <String, Object?>{'x': 2, 'y': -3},
          },
        ),
      );

      expect(text.attrs['x'], 12);
      expect(text.attrs['y'], 2);
    });

    test('update deduplicates overlapping explicit and path targets', () {
      final instance = Patchmap();
      final text =
          instance.draw(<Object?>[
                <String, Object?>{
                  'type': 'text',
                  'id': 'txt-dedupe',
                  'text': 'dedupe',
                  'attrs': <String, Object?>{'x': 10},
                },
              ]).single
              as TextElement;

      instance.update(
        options: PatchmapUpdateOptions(
          elements: <TextElement>[text],
          path: r'$..[?(@.id=="txt-dedupe")]',
          relativeTransform: true,
          changes: <String, Object?>{
            'attrs': <String, Object?>{'x': 2},
          },
        ),
      );

      expect(text.attrs['x'], 12);
    });

    test('update with refresh keeps target stable', () {
      final instance = Patchmap();
      final text =
          instance.draw(<Object?>[
                <String, Object?>{
                  'type': 'text',
                  'id': 'txt-refresh',
                  'text': 'hello',
                },
              ]).single
              as TextElement;

      final updated = instance.update(
        options: PatchmapUpdateOptions(
          elements: <TextElement>[text],
          refresh: true,
        ),
      );

      expect(updated, [same(text)]);
      expect(text.text, 'hello');
    });

    test('update supports replace merge strategy for object fields', () {
      final instance = Patchmap();
      final text =
          instance.draw(<Object?>[
                <String, Object?>{
                  'type': 'text',
                  'id': 'txt-replace',
                  'text': 'before',
                  'attrs': <String, Object?>{'x': 10, 'y': 20},
                  'style': <String, Object?>{'fontSize': 12, 'fill': 'blue'},
                },
              ]).single
              as TextElement;

      instance.update(
        options: PatchmapUpdateOptions(
          elements: <TextElement>[text],
          mergeStrategy: PatchmapUpdateMergeStrategy.replace,
          changes: <String, Object?>{
            'attrs': <String, Object?>{'x': 1},
            'style': <String, Object?>{'fill': 'red'},
          },
        ),
      );

      expect(text.attrs, <String, Object?>{'x': 1});
      expect(text.style, <String, Object?>{'fill': 'red'});
    });

    test('draw accepts raw json elements and replaces current state', () {
      final instance = Patchmap();

      instance.draw(<Object?>[
        <String, Object?>{'type': 'text', 'id': 'stale', 'text': 'stale'},
      ]);

      final drawn = instance.draw(<Object?>[
        <String, Object?>{'type': 'text', 'id': 'txt-1', 'text': 'one'},
        <String, Object?>{
          'type': 'text',
          'id': 'txt-2',
          'text': 'two',
          'attrs': <String, Object?>{'x': 10, 'y': 20},
          'style': <String, Object?>{'fontSize': 18},
        },
      ]);

      expect(drawn, hasLength(2));
      expect(drawn.first, isA<TextElement>());
      final staleLookup = instance.update(
        options: const PatchmapUpdateOptions(path: r'$..[?(@.id=="stale")]'),
      );
      expect(staleLookup, isEmpty);
      final first = drawn[0] as TextElement;
      final second = drawn[1] as TextElement;
      expect(first.text, 'one');
      expect(second.text, 'two');
      expect(second.attrs, <String, Object?>{'x': 10, 'y': 20});
      expect(second.style, <String, Object?>{'fontSize': 18});
    });

    test('draw returns immutable element list', () {
      final instance = Patchmap();
      final drawn = instance.draw(<Object?>[
        <String, Object?>{'type': 'text', 'id': 'txt-draw', 'text': 'draw'},
      ]);

      expect(drawn, hasLength(1));
      expect(
        () => drawn.add(TextElement(id: 'another')),
        throwsUnsupportedError,
      );
    });

    test('update applies changes through element polymorphism', () {
      final instance = Patchmap();
      ElementModel.registerDecoder(
        _CustomElement.elementType,
        _decodeCustomElement,
      );
      final element =
          instance.draw(<Object?>[
                const <String, Object?>{
                  'type': _CustomElement.elementType,
                  'id': 'custom-1',
                  'value': 1,
                },
              ]).single
              as _CustomElement;

      final updated = instance.update(
        options: PatchmapUpdateOptions(
          elements: <ElementModel>[element],
          changes: const <String, Object?>{'value': 99},
        ),
      );

      expect(updated, [same(element)]);
      expect(element.value, 99);
    });

    test(
      'path update reuses selector snapshot and invalidates on mutation',
      () {
        final instance = Patchmap();
        ElementModel.registerDecoder(
          _CountingPathElement.elementType,
          _decodeCountingPathElement,
        );
        final element =
            instance.draw(<Object?>[
                  const <String, Object?>{
                    'type': _CountingPathElement.elementType,
                    'id': 'counting-path-1',
                    'value': 1,
                  },
                ]).single
                as _CountingPathElement;

        const byValueOnePath = r'$..[?(@.value==1)]';
        const byValueTwoPath = r'$..[?(@.value==2)]';

        instance.update(
          options: const PatchmapUpdateOptions(path: byValueOnePath),
        );
        expect(element.toJsonCallCount, 1);

        instance.update(
          options: const PatchmapUpdateOptions(path: byValueOnePath),
        );
        expect(element.toJsonCallCount, 1);

        instance.update(
          options: const PatchmapUpdateOptions(
            path: byValueOnePath,
            changes: <String, Object?>{'value': 2},
          ),
        );
        expect(element.value, 2);
        expect(element.toJsonCallCount, 1);

        instance.update(
          options: const PatchmapUpdateOptions(path: byValueTwoPath),
        );
        expect(element.toJsonCallCount, 2);
      },
    );
  });
}

final class _CustomElement extends ElementModel {
  static const String elementType = 'custom-update-test';

  _CustomElement({required this.value, super.id}) : super(type: elementType);

  int value;

  @override
  void applyJsonPatch(
    Map<String, Object?> changes, {
    required bool mergeObjects,
  }) {
    final next = changes['value'];
    if (next is int && value != next) {
      value = next;
      notifyChanged();
    }
  }

  @override
  Map<String, Object?> toJson() {
    return toJsonBase()..['value'] = value;
  }
}

_CustomElement _decodeCustomElement(Map<String, Object?> map) {
  final value = map['value'];
  if (value is! int) {
    throw const FormatException('"value" must be int for custom element');
  }
  return _CustomElement(id: map['id'] as String?, value: value);
}

final class _CountingPathElement extends ElementModel {
  static const String elementType = 'counting-path-test';

  _CountingPathElement({required this.value, super.id})
    : super(type: elementType);

  int value;
  int toJsonCallCount = 0;

  @override
  void applyJsonPatch(
    Map<String, Object?> changes, {
    required bool mergeObjects,
  }) {
    final next = changes['value'];
    if (next is int && value != next) {
      value = next;
      notifyChanged();
    }
  }

  @override
  Map<String, Object?> toJson() {
    toJsonCallCount += 1;
    return toJsonBase()..['value'] = value;
  }
}

_CountingPathElement _decodeCountingPathElement(Map<String, Object?> map) {
  final value = map['value'];
  if (value is! int) {
    throw const FormatException(
      '"value" must be int for counting path element',
    );
  }
  return _CountingPathElement(id: map['id'] as String?, value: value);
}
