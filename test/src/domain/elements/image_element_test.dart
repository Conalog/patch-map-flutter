import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/domain/elements/element_model.dart';
import 'package:patch_map_flutter/src/domain/elements/image_element.dart';

void main() {
  group('ImageElement', () {
    test('uses fixed image type and patch-map defaults', () {
      final element = ImageElement();

      expect(element.type, 'image');
      expect(element.id, hasLength(15));
      expect(element.show, isTrue);
      expect(element.source, '');
      expect(element.size, isNull);
      expect(element.tint, isNull);
    });

    test('uses interaction policy from original image element', () {
      final element = ImageElement();

      expect(element.isSelectable, isTrue);
      expect(element.hitScope, ElementHitScope.children);
    });

    test('defensively copies size map', () {
      final size = <String, Object?>{'width': 120, 'height': 24};
      final element = ImageElement(size: size);

      size['width'] = 999;

      expect(element.size?['width'], 120);
      expect(() => element.size?['height'] = 42, throwsUnsupportedError);
    });

    test('serializes image payload on top of base fields', () {
      final element = ImageElement(
        id: 'img-1',
        label: 'logo',
        show: false,
        attrs: {'x': 10, 'y': 20, 'zIndex': 7},
        source: 'wifi',
        size: {'width': 120, 'height': 24},
        tint: '#336699',
      );

      expect(element.toJson(), <String, Object?>{
        'type': 'image',
        'id': 'img-1',
        'label': 'logo',
        'show': false,
        'attrs': {'x': 10, 'y': 20, 'zIndex': 7},
        'source': 'wifi',
        'size': {'width': 120, 'height': 24},
        'tint': '#336699',
      });
    });

    test('supports mutable image state updates', () {
      final element = ImageElement(
        source: 'before',
        size: {'width': 120, 'height': 24},
        attrs: {'zIndex': 1},
        tint: 'white',
      );

      element.apply(
        source: 'after',
        size: {'width': 200, 'height': 40},
        sizePatch: {'height': 44},
        tint: '#ff0000',
        show: false,
        label: 'icon',
        attrs: {'zIndex': 9},
      );

      expect(element.source, 'after');
      expect(element.size, <String, Object?>{'width': 200, 'height': 44});
      expect(element.tint, '#ff0000');
      expect(element.show, isFalse);
      expect(element.label, 'icon');
      expect(element.zIndex, 9);
    });

    test(
      'fromJson throws when source/tint is missing or size has invalid type',
      () {
        expect(
          () => ImageElement.fromJson(const <String, Object?>{'type': 'image'}),
          throwsFormatException,
        );
        expect(
          () => ImageElement.fromJson(const <String, Object?>{
            'type': 'image',
            'source': 'wifi',
            'size': true,
          }),
          throwsFormatException,
        );
        expect(
          () => ImageElement.fromJson(const <String, Object?>{
            'type': 'image',
            'source': 'wifi',
            'tint': true,
          }),
          throwsFormatException,
        );
      },
    );
  });
}
