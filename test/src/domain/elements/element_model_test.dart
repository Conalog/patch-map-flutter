import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/domain/elements/element_model.dart';

void main() {
  group('ElementModel', () {
    test('defaults follow patch-map base semantics', () {
      final element = _TestElement(type: 'item');

      expect(element.type, 'item');
      expect(element.id, isNotNull);
      expect(element.id, hasLength(15));
      expect(
        element.id,
        matches(RegExp(r'^[0-9A-Za-z]{15}$')),
      );
      expect(element.label, isNull);
      expect(element.show, isTrue);
      expect(element.attrs, isEmpty);
      expect(element.zIndex, 0);
    });

    test('keeps explicitly provided id as-is', () {
      final element = _TestElement(type: 'item', id: 'custom-id');

      expect(element.id, 'custom-id');
    });

    test('exposes base interaction policy used by flutter port', () {
      final element = _TestElement(type: 'grid');

      expect(element.isSelectable, isFalse);
      expect(element.hitScope, ElementHitScope.self);
    });

    test('derives zIndex from attrs when numeric', () {
      final intValue = _TestElement(type: 'item', attrs: {'zIndex': 10});
      final doubleValue = _TestElement(type: 'item', attrs: {'zIndex': 3.5});
      final invalidValue = _TestElement(type: 'item', attrs: {'zIndex': 'x'});

      expect(intValue.zIndex, 10);
      expect(doubleValue.zIndex, 3.5);
      expect(invalidValue.zIndex, 0);
    });

    test('defensively copies attrs to keep model deterministic', () {
      final source = <String, Object?>{'zIndex': 9};
      final element = _TestElement(type: 'item', attrs: source);

      source['zIndex'] = 99;

      expect(element.zIndex, 9);
      expect(() => element.attrs['foo'] = 1, throwsUnsupportedError);
    });

    test('toJsonBase serializes only defined common fields', () {
      final element = _TestElement(
        type: 'relations',
        id: 'el-1',
        label: 'links',
        show: false,
        attrs: {'zIndex': 12},
      );

      expect(element.toJson(), <String, Object?>{
        'type': 'relations',
        'id': 'el-1',
        'label': 'links',
        'show': false,
        'attrs': {'zIndex': 12},
      });
    });

    test('supports mutable base state updates', () {
      final element = _TestElement(
        type: 'item',
        label: 'before',
        attrs: {'zIndex': 1},
      );

      element.apply(
        label: 'after',
        show: false,
        attrs: {'zIndex': 5, 'x': 10},
        attrsPatch: {'y': 20, 'x': null},
      );

      expect(element.label, 'after');
      expect(element.show, isFalse);
      expect(element.zIndex, 5);
      expect(element.attrs, <String, Object?>{'zIndex': 5, 'y': 20});
    });
  });
}

final class _TestElement extends ElementModel {
  _TestElement({
    required super.type,
    super.id,
    super.label,
    super.show,
    super.attrs,
  });

  @override
  Map<String, Object?> toJson() => toJsonBase();
}
