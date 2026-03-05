import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/domain/elements/element_model.dart';
import 'package:patch_map_flutter/src/domain/elements/text_element.dart';

void main() {
  group('TextElement', () {
    test('uses fixed text type and patch-map defaults', () {
      final element = TextElement();

      expect(element.type, 'text');
      expect(element.id, hasLength(15));
      expect(element.show, isTrue);
      expect(element.text, '');
      expect(element.style, isEmpty);
      expect(element.size, isNull);
    });

    test('uses interaction policy from original text element', () {
      final element = TextElement();

      expect(element.isSelectable, isTrue);
      expect(element.hitScope, ElementHitScope.children);
    });

    test('defensively copies style and size maps', () {
      final style = <String, Object?>{'fontSize': 16};
      final size = <String, Object?>{'width': 120, 'height': 24};
      final element = TextElement(style: style, size: size);

      style['fontSize'] = 20;
      size['width'] = 999;

      expect(element.style['fontSize'], 16);
      expect(element.size?['width'], 120);
      expect(() => element.style['color'] = 'red', throwsUnsupportedError);
      expect(() => element.size?['height'] = 42, throwsUnsupportedError);
    });

    test('serializes text payload on top of base fields', () {
      final element = TextElement(
        id: 'txt-1',
        label: 'header',
        show: false,
        attrs: {'x': 10, 'y': 20, 'zIndex': 7},
        text: 'Hello',
        style: {'fontSize': 14},
        size: {'width': 120, 'height': 24},
      );

      expect(element.toJson(), <String, Object?>{
        'type': 'text',
        'id': 'txt-1',
        'label': 'header',
        'show': false,
        'attrs': {'x': 10, 'y': 20, 'zIndex': 7},
        'text': 'Hello',
        'style': {'fontSize': 14},
        'size': {'width': 120, 'height': 24},
      });
    });

    test('supports mutable text state updates', () {
      final element = TextElement(
        text: 'before',
        style: {'fontSize': 14},
        size: {'width': 120, 'height': 24},
        attrs: {'zIndex': 1},
      );

      element.apply(
        text: 'after',
        style: {'fontWeight': '700'},
        stylePatch: {'fill': 'white'},
        size: {'width': 200, 'height': 40},
        sizePatch: {'height': 44},
        show: false,
        label: 'title',
        attrs: {'zIndex': 9},
      );

      expect(element.text, 'after');
      expect(element.style, <String, Object?>{
        'fontWeight': '700',
        'fill': 'white',
      });
      expect(element.size, <String, Object?>{'width': 200, 'height': 44});
      expect(element.show, isFalse);
      expect(element.label, 'title');
      expect(element.zIndex, 9);
    });

    test('fromJson throws when attrs/style/size are invalid types', () {
      expect(
        () => TextElement.fromJson(const <String, Object?>{
          'type': 'text',
          'attrs': 'invalid',
        }),
        throwsFormatException,
      );
      expect(
        () => TextElement.fromJson(const <String, Object?>{
          'type': 'text',
          'style': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => TextElement.fromJson(const <String, Object?>{
          'type': 'text',
          'size': true,
        }),
        throwsFormatException,
      );
    });
  });
}
