import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';
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
  });
}
