# selector 규칙 문서

`selector`는 JSON 데이터에서 JSONPath 표현식으로 값을 조회하는 유틸리티입니다.

## API

```dart
List<Object?> selector(
  Object? json,
  String? path, {
  List<String>? searchableKeys = const ['children'],
  bool flatten = true,
})
```

## 기본 동작

1. `path`가 `null`이면 빈 리스트를 반환합니다.
2. `json`이 `null`이면 빈 객체(`{}`)로 간주합니다.
3. 유효하지 않은 경로 문법은 내부 파서의 `FormatException`이 전파됩니다.

## searchableKeys

`searchableKeys`는 재귀 순회/와일드카드/필터 평가 시 객체 탐색 키를 제한합니다.

1. 기본값은 `['children']` 입니다.
2. 기본값에서는 `children` 아래 트리만 탐색합니다.
3. `null`로 주면 키 제한 없이 전체 키를 탐색합니다.

## flatten

1. 기본값 `true`: 매치 결과 중 `List` 값을 펼쳐(flatten) 단일 리스트로 반환합니다.
2. `false`: 각 매치 값을 그대로 반환합니다(리스트는 리스트 형태 유지).

## 지원 표현식(테스트 기반)

아래 항목은 `selector_test.dart`에서 검증된 패턴입니다.

1. 기본 경로: `$.meta.id`
2. 재귀 하강: `$..price`
3. 와일드카드: `$.*`
4. 필터: `$.items[?@.flag]`, `$.book[?@.price < 10]`
5. 필터 논리식/그룹: `&&`, `||`, 괄호식
6. 브라켓 키 접근: `$.store['weird.key']`, `@['price']`
7. 배열 인덱스: 음수 인덱스 포함(`[-1]`)
8. 유니온: `[0,2,4]`, `['a','b']`
9. 슬라이스: `[1:5:2]`, `[:3]`, `[3:]`, `[5:1:-2]`

## 캐시 동작

동일한 경로 문자열과 동일한 필터 표현식은 내부 캐시를 재사용합니다.

1. 경로 토크나이징 결과 캐시
2. 필터 컴파일 결과 캐시

## 예시

```dart
final data = {
  'children': [
    {'id': 'group-a', 'type': 'group', 'children': []},
  ],
};

selector(data, r'$..[?(@.id=="group-a")]');
// => [{'id': 'group-a', 'type': 'group', 'children': []}]
```

```dart
selector(data, r'$..children');
// flatten 기본값 true
// => [{'id': 'group-a', 'type': 'group', 'children': []}]
```

```dart
selector(
  {
    'meta': {
      'children': [
        {'id': 'meta-child'}
      ]
    }
  },
  r'$..[?(@.id=="meta-child")]',
  searchableKeys: null,
);
// => [{'id': 'meta-child'}]
```

## 참고 파일

- `lib/src/utils/selector/selector.dart`
- `lib/src/utils/selector/json_search.dart`
- `test/src/utils/selector/selector_test.dart`
