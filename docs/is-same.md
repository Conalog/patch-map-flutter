# isSame 규칙 문서

`isSame`은 diff 계산에서 사용하는 deep equality 유틸리티입니다.

## API

```dart
bool isSame(Object? value1, Object? value2)
```

## 기본 동작

1. 동일 참조(`identical`)면 `true`입니다.
2. `NaN` vs `NaN`은 `true`입니다.
3. 스칼라(`bool`, `num`, `String`, `Symbol`)는 `==`로 비교합니다.
4. 지원 타입이 아니면(함수/일반 객체 등) 동일 참조가 아닌 경우 `false`입니다.
5. composite 타입은 `runtimeType`이 다르면 `false`입니다.

## 지원 타입별 비교 규칙

1. `DateTime`: `isAtSameMomentAs` 기준
2. `RegExp`: `pattern`, `isCaseSensitive`, `isMultiLine`, `isDotAll`, `isUnicode` 모두 비교
3. `TypedData`: 타입/길이/원소(또는 바이트) 비교
4. `List`: 길이 + 인덱스 순서 기준 deep 비교
5. `Set`: 삽입 순서 기준 deep 비교
6. `Map`: 키 개수/키 존재/값 deep 비교

## 순환 참조 처리

`left -> right`, `right -> left` 양방향 매핑을 함께 추적해 순환 구조를 비교합니다.

1. 순환 참조가 있어도 무한 루프 없이 종료합니다.
2. 비동형(non-isomorphic) 순환 그래프는 `false`입니다.
3. 대칭성 보장: `isSame(a, b) == isSame(b, a)`.

## 깊은 중첩 안전성

재귀 대신 명시적 스택(반복 루프)으로 순회합니다.

1. 매우 깊은 중첩(테스트 기준 50,000 depth)에서도 콜스택 오버플로우를 피합니다.
2. 성능 회귀를 막기 위한 가드 테스트를 포함합니다.

## 예시

```dart
isSame(
  {'a': 1, 'nested': [1, 2, {'k': 'v'}]},
  {'a': 1, 'nested': [1, 2, {'k': 'v'}]},
);
// => true
```

```dart
isSame(RegExp('a.b'), RegExp('a.b', dotAll: true));
// => false
```

## 참고 파일

- `lib/src/utils/diff/is_same.dart`
- `test/src/utils/diff/is_same_test.dart`
