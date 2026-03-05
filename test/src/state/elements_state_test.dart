import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/src/domain/elements/element_model.dart';
import 'package:patch_map_flutter/src/domain/elements/text_element.dart';
import 'package:patch_map_flutter/src/state/elements_state.dart';

void main() {
  group('ElementsState', () {
    test('publishes added/updated/removed events', () {
      final state = ElementsState();
      final events = <ElementsStateChangeKind>[];

      state.addListener((change) {
        events.add(change.kind);
      });

      final model = TextElement(id: 'txt-1', text: 'hello');
      state.upsert(model);
      state.removeById('txt-1');

      expect(events, <ElementsStateChangeKind>[
        ElementsStateChangeKind.added,
        ElementsStateChangeKind.removed,
      ]);
    });

    test('emits updated when registered model mutates', () {
      final state = ElementsState();
      final events = <ElementsStateChangeKind>[];
      final model = TextElement(id: 'txt-2', text: 'before');

      state.addListener((change) {
        events.add(change.kind);
      });

      state.upsert(model);
      model.apply(text: 'after');

      expect(events, <ElementsStateChangeKind>[
        ElementsStateChangeKind.added,
        ElementsStateChangeKind.updated,
      ]);
    });

    test('reuses selector root json until state changes', () {
      final state = ElementsState();
      final model = _CountingJsonElement(id: 'count-1');
      state.upsert(model);

      final first = state.selectorRootJson();
      expect(model.toJsonCallCount, 1);

      final second = state.selectorRootJson();
      expect(identical(first, second), isTrue);
      expect(model.toJsonCallCount, 1);

      model.bumpVersion();
      final third = state.selectorRootJson();
      expect(identical(second, third), isFalse);
      expect(model.toJsonCallCount, 2);
    });

    test('invalidates selector root cache on identical upsert', () {
      final state = ElementsState();
      final model = _CountingJsonElement(id: 'count-2');
      state.upsert(model);
      state.selectorRootJson();
      expect(model.toJsonCallCount, 1);

      state.upsert(model);
      state.selectorRootJson();
      expect(model.toJsonCallCount, 2);
    });

    test('returns read-only selector root snapshot', () {
      final state = ElementsState();
      state.upsert(
        TextElement(
          id: 'count-3',
          text: 'hello',
          attrs: <String, Object?>{'x': 10},
        ),
      );

      final snapshot = state.selectorRootJson();
      expect(snapshot, isA<Map<String, Object?>>());

      final root = snapshot as Map<String, Object?>;
      expect(() => root['x'] = 1, throwsUnsupportedError);
      final children = root['children'] as List<Object?>;
      expect(
        () => children.add(const <String, Object?>{}),
        throwsUnsupportedError,
      );
      final first = children.first as Map<String, Object?>;
      expect(() => first['id'] = 'mutated', throwsUnsupportedError);
      final attrs = first['attrs'] as Map<String, Object?>;
      expect(() => attrs['x'] = 999, throwsUnsupportedError);
    });
  });
}

final class _CountingJsonElement extends ElementModel {
  _CountingJsonElement({super.id}) : super(type: 'counting');

  int version = 0;
  int toJsonCallCount = 0;

  void bumpVersion() {
    version += 1;
    notifyChanged();
  }

  @override
  Map<String, Object?> toJson() {
    toJsonCallCount += 1;
    return toJsonBase()..['version'] = version;
  }
}
