import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import 'patchmap_asset_registry.dart';
import 'patchmap_init_options.dart';
import 'patchmap_sprite_factory.dart';

final class PatchmapRuntime extends FlameGame<World> {
  PatchmapRuntime({
    super.world,
    super.camera,
    PatchmapAssetRegistry? assetRegistry,
  }) : _assetRegistry = assetRegistry ?? PatchmapAssetRegistry();

  final PatchmapAssetRegistry _assetRegistry;
  Color? _backgroundColorOverride;
  late final PatchmapSpriteFactory _spriteFactory = PatchmapSpriteFactory(
    svgSourceResolver: (alias) => _assetRegistry.iconSvgByAlias[alias],
  );

  bool get assetsReady => _assetRegistry.isReady;

  Map<String, String> get iconSvgByAlias => _assetRegistry.iconSvgByAlias;

  void configureApp(PatchmapInitAppOptions appOptions) {
    _backgroundColorOverride = appOptions.backgroundColor;
  }

  Future<void> preloadAssets({
    PatchmapInitAssets assets = const PatchmapInitAssets(),
  }) => _assetRegistry.preload(assets: assets);

  Future<Sprite> iconSprite(String alias, {int edgePx = 96}) =>
      _spriteFactory.iconSprite(alias, edgePx: edgePx);

  Future<Map<String, Sprite>> iconSprites(
    Iterable<String> aliases, {
    int edgePx = 96,
  }) => _spriteFactory.iconSprites(aliases, edgePx: edgePx);

  @override
  Color backgroundColor() =>
      _backgroundColorOverride ?? super.backgroundColor();

  @override
  void onRemove() {
    _spriteFactory.clear();
    super.onRemove();
  }
}
