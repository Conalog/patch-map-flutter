# deepMerge 규칙 문서

`deepMerge`는 `target`과 `source`를 재귀적으로 병합해 새로운 값을 반환합니다.

## API

```dart
Object? deepMerge(
  Object? target,
  Object? source, {
  List<String> mergeBy = const ['id', 'label', 'type'],
  DeepMergeStrategy mergeStrategy = DeepMergeStrategy.merge,
})
```

```dart
enum DeepMergeStrategy { merge, replace }
```

## 기본 규칙

1. `source`가 `Map`/`List`가 아니면 `source`가 최종 결과가 됩니다.
2. `target`과 `source`가 모두 `Map`이면 키 단위로 deep merge 합니다.
3. `target`과 `source`가 모두 `List`이면 `mergeStrategy`에 따라 동작합니다.
4. 컬렉션 타입이 다르면 `source` 컬렉션을 복제해 반환합니다.

## List 병합 규칙

`mergeStrategy: DeepMergeStrategy.merge`일 때:

1. 원시값(예: `int`, `String`)은 인덱스 기준으로 덮어씁니다.
2. `Map` 아이템은 `mergeBy` 키 우선순위로 매칭합니다.
3. 매칭되는 아이템이 있으면 deep merge 합니다.
4. 매칭이 없으면 새 아이템을 append 합니다.
5. 기본 `mergeBy` 우선순위는 `id -> label -> type` 입니다.

`mergeStrategy: DeepMergeStrategy.replace`일 때:

1. 대상 리스트를 유지하지 않고 `source` 리스트 전체를 복제해 사용합니다.

## 불변성 및 참조 보장

1. 결과값의 `Map`/`List`는 `target`/`source`의 mutable 노드를 직접 공유하지 않습니다.
2. `source`가 self-reference(순환 참조)를 포함해도 무한 재귀 없이 구조를 보존합니다.
3. 함수/객체 같은 non-collection 값은 `source` 참조를 그대로 사용합니다.

## 예시

```dart
deepMerge(
  {'show': true, 'style': {'color': 'red', 'width': 100}},
  {'show': false, 'style': {'height': 200}},
);
// => {'show': false, 'style': {'color': 'red', 'width': 100, 'height': 200}}
```

```dart
deepMerge(
  {'arr': [1, 2, 3]},
  {'arr': [4, 5]},
  mergeStrategy: DeepMergeStrategy.replace,
);
// => {'arr': [4, 5]}
```

```dart
deepMerge(
  {
    'components': [
      {'id': 1, 'value': 10}
    ]
  },
  {
    'components': [
      {'id': 1, 'value': 20}
    ]
  },
);
// => {
//   'components': [
//     {'id': 1, 'value': 20}
//   ]
// }
```

## 참고 테스트

- `test/src/utils/deepmerge/deep_merge_test.dart`
