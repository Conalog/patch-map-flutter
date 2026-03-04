import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter_svg/flutter_svg.dart' as vg;

typedef SvgSourceResolver = String? Function(String alias);

final class PatchmapSpriteFactory {
  PatchmapSpriteFactory({required SvgSourceResolver svgSourceResolver})
    : _svgSourceResolver = svgSourceResolver;

  final SvgSourceResolver _svgSourceResolver;

  final Map<_SpriteCacheKey, Sprite> _spriteByCacheKey =
      <_SpriteCacheKey, Sprite>{};
  final List<ui.Image> _ownedImages = <ui.Image>[];

  Future<Sprite> iconSprite(String alias, {int edgePx = 96}) async {
    if (edgePx <= 0) {
      throw ArgumentError.value(edgePx, 'edgePx', 'Must be greater than zero.');
    }

    final cacheKey = _SpriteCacheKey(alias: alias, edgePx: edgePx);
    final cached = _spriteByCacheKey[cacheKey];
    if (cached != null) {
      return cached;
    }

    final svgSource = _svgSourceResolver(alias);
    if (svgSource == null) {
      throw StateError('Icon alias not found: $alias');
    }

    final sprite = await _rasterizeSvgToSprite(svgSource, edgePx: edgePx);
    _spriteByCacheKey[cacheKey] = sprite;
    return sprite;
  }

  Future<Map<String, Sprite>> iconSprites(
    Iterable<String> aliases, {
    int edgePx = 96,
  }) async {
    final result = <String, Sprite>{};
    for (final alias in aliases) {
      result[alias] = await iconSprite(alias, edgePx: edgePx);
    }
    return result;
  }

  void clear() {
    _spriteByCacheKey.clear();
    for (final image in _ownedImages) {
      image.dispose();
    }
    _ownedImages.clear();
  }

  Future<Sprite> _rasterizeSvgToSprite(
    String svgSource, {
    required int edgePx,
  }) async {
    final pictureInfo = await vg.vg.loadPicture(
      vg.SvgStringLoader(svgSource),
      null,
    );
    final sourceSize = pictureInfo.size;
    final scale = edgePx / math.max(sourceSize.width, sourceSize.height);
    final targetWidth = sourceSize.width * scale;
    final targetHeight = sourceSize.height * scale;
    final offsetX = (edgePx - targetWidth) / 2;
    final offsetY = (edgePx - targetHeight) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);
    canvas.drawPicture(pictureInfo.picture);
    final scaledPicture = recorder.endRecording();

    final image = await scaledPicture.toImage(edgePx, edgePx);
    scaledPicture.dispose();
    pictureInfo.picture.dispose();

    _ownedImages.add(image);
    return Sprite(image);
  }
}

final class _SpriteCacheKey {
  const _SpriteCacheKey({required this.alias, required this.edgePx});

  final String alias;
  final int edgePx;

  @override
  bool operator ==(Object other) {
    return other is _SpriteCacheKey &&
        other.alias == alias &&
        other.edgePx == edgePx;
  }

  @override
  int get hashCode => Object.hash(alias, edgePx);
}
