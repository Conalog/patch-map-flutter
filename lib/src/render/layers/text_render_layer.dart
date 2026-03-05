import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../domain/elements/text_element.dart';
import 'element_render_layer.dart';

final class TextRenderLayer extends ElementRenderLayer<TextElement> {
  TextRenderLayer() {
    add(_textComponent);
  }

  final TextComponent _textComponent = TextComponent(text: '');

  String get renderedText => _textComponent.text;
  TextStyle get renderedTextStyle {
    final renderer = _textComponent.textRenderer;
    if (renderer is TextPaint) {
      return renderer.style;
    }
    return TextPaint.defaultTextStyle;
  }

  @override
  void syncFromModel(TextElement model) {
    final customFontFamily = _normalizedFontFamily(model.style['fontFamily']);
    final fontFamily = customFontFamily ?? 'FiraCode';
    _textComponent.text = model.text;
    _textComponent.textRenderer = TextPaint(
      style: TextStyle(
        color: _colorFromFill(model.style['fill']) ?? const Color(0xFF000000),
        fontSize: _fontSizeFromStyle(model.style['fontSize']) ?? 16,
        fontFamily: fontFamily,
        fontWeight: _fontWeightFromStyle(model.style['fontWeight']),
        package: customFontFamily == null ? 'patch_map_flutter' : null,
      ),
    );
  }

  String? _normalizedFontFamily(Object? value) {
    final raw = _stringValue(value);
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _stringValue(Object? value) {
    if (value is! String) {
      return null;
    }
    return value;
  }

  double? _fontSizeFromStyle(Object? value) {
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    return null;
  }

  FontWeight _fontWeightFromStyle(Object? value) {
    final parsed = _parseFontWeight(value);
    return parsed ?? FontWeight.w400;
  }

  FontWeight? _parseFontWeight(Object? value) {
    if (value is num) {
      return _fontWeightFromNumber(value.toInt());
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) {
        return null;
      }
      final asNumber = int.tryParse(normalized);
      if (asNumber != null) {
        return _fontWeightFromNumber(asNumber);
      }
      return switch (normalized) {
        'thin' => FontWeight.w100,
        'extralight' => FontWeight.w200,
        'light' => FontWeight.w300,
        'regular' => FontWeight.w400,
        'medium' => FontWeight.w500,
        'semibold' => FontWeight.w600,
        'bold' => FontWeight.w700,
        'extrabold' => FontWeight.w800,
        'black' => FontWeight.w900,
        _ => null,
      };
    }
    return null;
  }

  FontWeight _fontWeightFromNumber(int value) {
    if (value <= 100) return FontWeight.w100;
    if (value <= 200) return FontWeight.w200;
    if (value <= 300) return FontWeight.w300;
    if (value <= 400) return FontWeight.w400;
    if (value <= 500) return FontWeight.w500;
    if (value <= 600) return FontWeight.w600;
    if (value <= 700) return FontWeight.w700;
    if (value <= 800) return FontWeight.w800;
    return FontWeight.w900;
  }

  Color? _colorFromFill(Object? value) {
    if (value is int) {
      final normalized = value <= 0xFFFFFF ? (0xFF000000 | value) : value;
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
