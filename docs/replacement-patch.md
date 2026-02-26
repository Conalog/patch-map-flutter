# buildReplacementPatch 규칙 문서

`buildReplacementPatch`는 "부분 갱신을 위한 교체형 diff"를 계산하는 유틸리티입니다.

## API

```dart
Object? buildReplacementPatch(Object? previous, Object? next)
```

## 기본 동작

1. `previous`/`next`가 둘 다 `Map`이 아니면 `isSame`으로 동일성 확인 후:
2. 동일하면 빈 맵(`{}`)을 반환합니다.
3. 다르면 `next` 전체를 반환합니다.
4. `previous`/`next`가 둘 다 `Map`이면 map implementation 호환성 검사를 먼저 수행합니다.
5. 호환되지 않으면 `next` 전체를 반환합니다.
6. 호환되면 `next`에 존재하는 키만 순회해 변경된 키만 결과 맵에 담아 반환합니다.

## Map 타입 호환 규칙

JS의 constructor 비교 의도를 유지하되 Dart 제네릭 차이로 과도한 전체 교체가 발생하지 않도록 구현되어 있습니다.

1. `LinkedHashMap`, `HashMap`, `SplayTreeMap`은 구현체 단위로 비교합니다.
2. 동일 구현체라면 제네릭 파라미터가 달라도 호환으로 간주합니다.
3. 서로 다른 구현체면 전체 교체(`next`)를 반환합니다.

## 키 비교 규칙

1. `next`에 없는 키(삭제된 키)는 diff에 포함하지 않습니다.
2. `next`에 있는 키만 비교합니다.
3. 값 비교는 `isSame`을 사용합니다(순환 참조, `DateTime`, `NaN` 등 동일 규칙 적용).
4. `previous`에 키가 없던 경우와 `null` 값을 구분해 처리합니다.

## 예시

```dart
buildReplacementPatch(
  {'a': 1, 'b': 2},
  {'a': 1, 'b': 3, 'c': 4},
);
// => {'b': 3, 'c': 4}
```

```dart
buildReplacementPatch(
  {'a': {'x': 1}},
  {'a': {'x': 1}},
);
// => {}
```

```dart
buildReplacementPatch(
  {'a': 1},
  HashMap<String, Object?>.from({'a': 1}),
);
// => next 전체 (구현체가 다르면 전체 교체)
```

## 성능 메모

1. 맵 경로에서는 선행 전체 deep-compare를 하지 않고 키 단위 비교만 수행합니다.
2. tail mismatch와 equality 경로 성능 회귀를 막기 위한 가드 테스트를 포함합니다.

## 참고 파일

- `lib/src/utils/diff/replacement_patch.dart`
- `test/src/utils/diff/replacement_patch_test.dart`
