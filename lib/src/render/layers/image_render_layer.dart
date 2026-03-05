import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../domain/elements/image_element.dart';
import '../../runtime/patchmap_runtime.dart';
import 'element_render_layer.dart';

typedef ImageSpriteLoader = Future<Sprite?> Function(String source);

final class ImageRenderLayer extends ElementRenderLayer<ImageElement> {
  ImageRenderLayer({
    ImageSpriteLoader? spriteLoader,
    ImageSpriteLoader? networkSpriteLoader,
  }) : _spriteLoaderOverride = spriteLoader,
       _networkSpriteLoaderOverride = networkSpriteLoader {
    add(_spriteComponent);
  }

  final ImageSpriteLoader? _spriteLoaderOverride;
  final ImageSpriteLoader? _networkSpriteLoaderOverride;
  final _OptionalSpriteComponent _spriteComponent = _OptionalSpriteComponent();
  final Map<String, Sprite> _networkSpriteBySource = <String, Sprite>{};
  static final Set<String> _reportedNetworkHintKeys = <String>{};

  String _renderedSource = '';
  Color? _renderedTint;
  int _loadToken = 0;

  String get renderedSource => _renderedSource;
  Color? get renderedTint => _renderedTint;

  Vector2 get renderedSize =>
      Vector2(_spriteComponent.size.x, _spriteComponent.size.y);

  @override
  void onMount() {
    super.onMount();
    if (_renderedSource.isNotEmpty && _spriteComponent.sprite == null) {
      _scheduleSpriteLoad(_renderedSource);
    }
  }

  @override
  void onRemove() {
    _networkSpriteBySource.clear();
    super.onRemove();
  }

  @override
  void syncFromModel(
    ImageElement model, {
    required Set<String>? changedKeys,
    required bool refresh,
  }) {
    if (refresh || changedKeys == null || _touchesSource(changedKeys)) {
      final nextSource = _normalizedSource(model.source);
      if (refresh || nextSource != _renderedSource) {
        _renderedSource = nextSource;
        _scheduleSpriteLoad(nextSource);
      }
    }

    if (refresh || changedKeys == null || _touchesSize(changedKeys)) {
      _applySize(model.size);
    }

    if (refresh || changedKeys == null || _touchesTint(changedKeys)) {
      _applyTint(model.tint);
    }
  }

  bool _touchesSource(Set<String> changedKeys) {
    for (final key in changedKeys) {
      if (key == 'source' || key.startsWith('source.')) {
        return true;
      }
    }
    return false;
  }

  bool _touchesSize(Set<String> changedKeys) {
    for (final key in changedKeys) {
      if (key == 'size' || key.startsWith('size.')) {
        return true;
      }
    }
    return false;
  }

  bool _touchesTint(Set<String> changedKeys) {
    for (final key in changedKeys) {
      if (key == 'tint' || key.startsWith('tint.')) {
        return true;
      }
    }
    return false;
  }

  void _applySize(Map<String, Object?>? size) {
    if (size == null) {
      return;
    }

    final width = _firstNonNegativeNumber(size, const <String>['w', 'width']);
    final height = _firstNonNegativeNumber(size, const <String>['h', 'height']);
    if (width != null) {
      _spriteComponent.size.x = width;
    }
    if (height != null) {
      _spriteComponent.size.y = height;
    }
  }

  double? _firstNonNegativeNumber(
    Map<String, Object?> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = source[key];
      if (raw is num && raw.isFinite) {
        final value = raw.toDouble();
        if (value >= 0) {
          return value;
        }
      }
    }
    return null;
  }

  String _normalizedSource(String source) => source.trim();

  void _applyTint(Object? tintValue) {
    final nextTint = _colorFromTint(tintValue);
    if (_renderedTint == nextTint) {
      return;
    }
    _renderedTint = nextTint;
    if (nextTint == null) {
      _spriteComponent.paint.colorFilter = null;
      return;
    }
    _spriteComponent.paint.colorFilter = ColorFilter.mode(
      nextTint,
      BlendMode.modulate,
    );
  }

  void _scheduleSpriteLoad(String source) {
    final token = ++_loadToken;
    if (source.isEmpty) {
      _spriteComponent.sprite = null;
      return;
    }

    unawaited(
      _loadSprite(source)
          .then((sprite) {
            if (token != _loadToken || source != _renderedSource) {
              return;
            }
            _spriteComponent.sprite = sprite;
          })
          .catchError((_) {
            if (token != _loadToken || source != _renderedSource) {
              return;
            }
            _spriteComponent.sprite = null;
          }),
    );
  }

  Future<Sprite?> _loadSprite(String source) {
    return _loadSpriteWithFallback(source);
  }

  Future<Sprite?> _loadSpriteWithFallback(String source) async {
    final loader = _spriteLoaderOverride;
    final primary = loader == null
        ? await _loadSpriteFromRuntime(source)
        : await loader(source);
    if (primary != null) {
      return primary;
    }

    if (!_isNetworkImageSource(source)) {
      return null;
    }

    final networkLoader = _networkSpriteLoaderOverride;
    if (networkLoader != null) {
      return networkLoader(source);
    }
    final networkSprite = await _loadSpriteFromNetwork(source);
    if (networkSprite == null && kDebugMode) {
      debugPrint('[patch_map_flutter:image] failed to load source: $source');
    }
    return networkSprite;
  }

  Future<Sprite?> _loadSpriteFromRuntime(String source) async {
    final game = findGame();
    if (game is! PatchmapRuntime) {
      return null;
    }

    try {
      return await game.iconSprite(source);
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkImageSource(String source) {
    final uri = Uri.tryParse(source);
    if (uri == null || !uri.hasScheme) {
      return false;
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Future<Sprite?> _loadSpriteFromNetwork(String source) async {
    final cached = _networkSpriteBySource[source];
    if (cached != null) {
      return cached;
    }

    final uri = Uri.tryParse(source);
    if (uri == null) {
      return null;
    }

    try {
      final sprite = await _loadSpriteFromImageProvider(source);
      _networkSpriteBySource[source] = sprite;
      return sprite;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[patch_map_flutter:image] network decode failed for "$source": $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        final hint = networkFailureHintFor(error);
        if (hint != null) {
          final key = networkFailureHintKeyFor(error);
          if (_reportedNetworkHintKeys.add(key)) {
            debugPrint('[patch_map_flutter:image] hint: $hint');
          }
        }
      }
      return null;
    }
  }

  Future<Sprite> _loadSpriteFromImageProvider(String source) async {
    final provider = NetworkImage(source);
    final stream = provider.resolve(const ImageConfiguration());
    final completer = Completer<ImageInfo>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, _) {
        if (!completer.isCompleted) {
          completer.complete(imageInfo);
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace ?? StackTrace.current);
        }
      },
    );
    stream.addListener(listener);
    try {
      final imageInfo = await completer.future;
      return Sprite(imageInfo.image);
    } finally {
      stream.removeListener(listener);
    }
  }

  @visibleForTesting
  static String? networkFailureHintFor(
    Object error, {
    TargetPlatform? platform,
  }) {
    final normalized = error.toString().toLowerCase();
    final targetPlatform = platform ?? defaultTargetPlatform;
    if (_looksLikePermissionDeniedSocketError(normalized)) {
      return switch (targetPlatform) {
        TargetPlatform.macOS =>
          'macOS sandbox blocks outbound traffic. Add '
              '`com.apple.security.network.client`=`true` to '
              '`Runner/DebugProfile.entitlements` and `Runner/Release.entitlements`.',
        TargetPlatform.android =>
          'Android blocks network access without INTERNET permission. Add '
              '`<uses-permission android:name="android.permission.INTERNET" />` '
              'to `android/app/src/main/AndroidManifest.xml`.',
        TargetPlatform.iOS =>
          'iOS requires App Transport Security exceptions for non-HTTPS URLs. '
              'Prefer HTTPS or update `Info.plist` ATS settings.',
        TargetPlatform.windows || TargetPlatform.linux =>
          'Desktop app cannot open outbound socket. Check OS firewall/sandbox '
              'policies and ensure HTTPS egress is allowed.',
        TargetPlatform.fuchsia =>
          'Platform policy blocked outbound socket. Check runtime network '
              'permissions for the host app.',
      };
    }
    if (_looksLikePlatformVersionUnsupported(normalized)) {
      return 'Flutter Web cannot use an IO-based network decode path. '
          'Load network sprites with `NetworkImage` and verify CORS allows '
          'the image origin.';
    }
    if (normalized.contains('http status code: 400')) {
      return 'HTTP 400 while loading image URL. In Flutter widget tests, '
          'outbound HTTP is blocked by default; inject `networkSpriteLoader` '
          'or mock the network path. In real apps, verify the URL directly '
          'returns image bytes with HTTP 200.';
    }
    if (normalized.contains('failed host lookup')) {
      return 'DNS lookup failed. Check hostname and network connectivity.';
    }
    if (normalized.contains('connection refused')) {
      return 'Remote host refused the connection. Check server availability '
          'and firewall policy.';
    }
    if (normalized.contains('handshake') ||
        normalized.contains('certificate')) {
      return 'TLS handshake/certificate error. Check certificate chain, '
          'device time, and HTTPS endpoint configuration.';
    }
    return null;
  }

  @visibleForTesting
  static String networkFailureHintKeyFor(
    Object error, {
    TargetPlatform? platform,
  }) {
    final normalized = error.toString().toLowerCase();
    final targetPlatform = platform ?? defaultTargetPlatform;
    if (_looksLikePermissionDeniedSocketError(normalized)) {
      return 'permission-denied-socket:$targetPlatform';
    }
    if (_looksLikePlatformVersionUnsupported(normalized)) {
      return 'web-platform-version-unsupported';
    }
    if (normalized.contains('http status code: 400')) {
      return 'http-400';
    }
    if (normalized.contains('failed host lookup')) {
      return 'dns-failed-host-lookup';
    }
    if (normalized.contains('connection refused')) {
      return 'connection-refused';
    }
    if (normalized.contains('handshake') ||
        normalized.contains('certificate')) {
      return 'tls-certificate';
    }
    return 'unknown-network-error';
  }

  static bool _looksLikePermissionDeniedSocketError(String normalized) {
    return normalized.contains('operation not permitted') ||
        normalized.contains('errno = 1');
  }

  static bool _looksLikePlatformVersionUnsupported(String normalized) {
    return normalized.contains('unsupported operation: platform._version');
  }

  Color? _colorFromTint(Object? value) {
    if (value is int) {
      final normalized = value <= 0xFFFFFF ? (0xFF000000 | value) : value;
      return Color(normalized);
    }
    if (value is num && value.isFinite) {
      final normalizedInt = value.toInt();
      final normalized = normalizedInt <= 0xFFFFFF
          ? (0xFF000000 | normalizedInt)
          : normalizedInt;
      return Color(normalized);
    }
    if (value is! String) {
      return null;
    }

    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final named = switch (normalized) {
      'black' => const Color(0xFF000000),
      'white' => const Color(0xFFFFFFFF),
      'red' => const Color(0xFFFF0000),
      'green' => const Color(0xFF00AA00),
      'blue' => const Color(0xFF0000FF),
      'yellow' => const Color(0xFFFFFF00),
      'orange' => const Color(0xFFFFA500),
      'gray' || 'grey' => const Color(0xFF808080),
      'transparent' => const Color(0x00000000),
      _ => null,
    };
    if (named != null) {
      return named;
    }

    final hex = normalized.startsWith('#') ? normalized.substring(1) : '';
    if (hex.isEmpty) {
      return null;
    }
    if (hex.length == 3) {
      final expanded = StringBuffer();
      for (final rune in hex.runes) {
        final ch = String.fromCharCode(rune);
        expanded
          ..write(ch)
          ..write(ch);
      }
      final rgb = int.tryParse(expanded.toString(), radix: 16);
      if (rgb == null) {
        return null;
      }
      return Color(0xFF000000 | rgb);
    }
    if (hex.length == 6) {
      final rgb = int.tryParse(hex, radix: 16);
      if (rgb == null) {
        return null;
      }
      return Color(0xFF000000 | rgb);
    }
    if (hex.length == 8) {
      final argb = int.tryParse(hex, radix: 16);
      if (argb == null) {
        return null;
      }
      return Color(argb);
    }

    return null;
  }
}

final class _OptionalSpriteComponent extends PositionComponent with HasPaint {
  Sprite? sprite;

  @override
  void render(Canvas canvas) {
    final renderedSprite = sprite;
    if (renderedSprite == null) {
      return;
    }
    renderedSprite.render(canvas, size: size, overridePaint: paint);
  }
}
