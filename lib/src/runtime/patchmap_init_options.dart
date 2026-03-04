import 'dart:ui';

final class PatchmapInitOptions {
  const PatchmapInitOptions({
    this.app = const PatchmapInitAppOptions(),
    this.assets = const PatchmapInitAssets(),
  });

  final PatchmapInitAppOptions app;

  final PatchmapInitAssets assets;
}

final class PatchmapInitAppOptions {
  const PatchmapInitAppOptions({this.backgroundColor});

  final Color? backgroundColor;
}

final class PatchmapInitAssets {
  const PatchmapInitAssets({
    this.iconAssetPathByAlias = const <String, String>{},
  });

  final Map<String, String> iconAssetPathByAlias;
}
