import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';
import 'package:patch_map_flutter/src/utils/selector/json_search.dart';

void main() {
  group('selector', () {
    final sample = {
      'id': 'root',
      'meta': {
        'id': 'root-meta',
        'children': [
          {'id': 'meta-child', 'type': 'item'},
        ],
      },
      'children': [
        {
          'id': 'group-a',
          'type': 'group',
          'parent': {'type': 'viewport'},
          'children': [
            {
              'id': 'item-b',
              'type': 'item',
              'parent': {'type': 'group'},
              'children': [],
            },
          ],
        },
        {
          'id': 'group-blocked',
          'type': 'group',
          'parent': {'type': 'item'},
          'children': [],
        },
        {
          'id': 'no-type',
          'parent': {'type': 'viewport'},
          'children': [],
        },
      ],
    };

    test('returns an empty list when path is null', () {
      expect(selector(sample, null), isEmpty);
    });

    test('finds descendants by default through children only', () {
      final result = selector(sample, r'$..[?(@.id=="item-b")]');
      expect(result, hasLength(1));
      expect((result.first as Map<String, Object?>)['id'], 'item-b');
    });

    test(
      'does not include descendants only reachable through non-children keys',
      () {
        final result = selector(sample, r'$..[?(@.id=="meta-child")]');
        expect(result, isEmpty);
      },
    );

    test('flattens list results by default', () {
      final result = selector(sample, r'$..children');
      expect(result.map((e) => (e as Map<String, Object?>)['id']), [
        'group-a',
        'group-blocked',
        'no-type',
        'item-b',
      ]);
    });

    test('can disable flattening', () {
      final result = selector(sample, r'$..children', flatten: false);
      expect(result, hasLength(5));
      expect(result.every((entry) => entry is List), isTrue);
    });

    test('supports wildcard and keeps searchable key restriction', () {
      final result = selector(sample, r'$.*');
      expect(result.map((e) => (e as Map<String, Object?>)['id']), [
        'group-a',
        'group-blocked',
        'no-type',
      ]);
    });

    test('can disable searchable key restriction', () {
      final result = selector(
        sample,
        r'$..[?(@.id=="meta-child")]',
        searchableKeys: null,
      );
      expect(result, hasLength(1));
      expect((result.first as Map<String, Object?>)['id'], 'meta-child');
    });

    test('supports filter expression used by focus/fit flow', () {
      final result = selector(
        sample,
        r'$..children[?(@.type != null && @.parent.type !== "item" && @.parent.type !== "relations")]',
      );

      expect(result.map((e) => (e as Map<String, Object?>)['id']), [
        'group-a',
        'item-b',
      ]);
    });

    test('supports direct non-recursive path access', () {
      final result = selector(sample, r'$.meta.id');
      expect(result, ['root-meta']);
    });
  });

  group('selector RFC 9535 edge cases', () {
    final sample = {
      'store': {
        'book': [
          {
            'category': 'reference',
            'author': 'Nigel Rees',
            'title': 'Sayings of the Century',
            'price': 8.95,
          },
          {
            'category': 'fiction',
            'author': 'Evelyn Waugh',
            'title': 'Sword of Honour',
            'price': 12.99,
          },
          {
            'category': 'fiction',
            'author': 'Herman Melville',
            'title': 'Moby Dick',
            'isbn': '0-553-21311-3',
            'price': 8.99,
          },
        ],
        'bicycle': {'color': 'red', 'price': 19.95},
        'weird.key': {'value': 1},
      },
      'arr': [0, 1, 2, 3, 4, 5],
      'mixed': [
        {'id': 1},
        {'id': '1'},
        {'id': null},
      ],
    };

    test('supports recursive descent for object members', () {
      final result = selector(sample, r'$..price', searchableKeys: null);
      expect(result, [8.95, 12.99, 8.99, 19.95]);
    });

    test('supports quoted member names in bracket selectors', () {
      final result = selector(
        sample,
        r"$.store['weird.key'].value",
        searchableKeys: null,
      );
      expect(result, [1]);
    });

    test('supports negative array index selector', () {
      final result = selector(sample, r'$.arr[-1]', searchableKeys: null);
      expect(result, [5]);
    });

    test('supports index union selector', () {
      final result = selector(sample, r'$.arr[0,2,4]', searchableKeys: null);
      expect(result, [0, 2, 4]);
    });

    test('supports member name union selector', () {
      final result = selector(
        sample,
        r"$.store['bicycle','weird.key']",
        searchableKeys: null,
        flatten: false,
      );
      expect(result, [
        {'color': 'red', 'price': 19.95},
        {'value': 1},
      ]);
    });

    test('supports array slices with explicit step', () {
      final result = selector(sample, r'$.arr[1:5:2]', searchableKeys: null);
      expect(result, [1, 3]);
    });

    test('supports array slices with omitted start or stop', () {
      final first = selector(sample, r'$.arr[:3]', searchableKeys: null);
      final second = selector(sample, r'$.arr[3:]', searchableKeys: null);
      expect(first, [0, 1, 2]);
      expect(second, [3, 4, 5]);
    });

    test('supports array slices with negative step', () {
      final result = selector(sample, r'$.arr[5:1:-2]', searchableKeys: null);
      expect(result, [5, 3]);
    });

    test('supports existence filters', () {
      final result = selector(
        sample,
        r'$.store.book[?@.isbn].title',
        searchableKeys: null,
      );
      expect(result, ['Moby Dick']);
    });

    test('treats path filters as existence checks, not truthy checks', () {
      final local = {
        'items': [
          {'id': 1, 'flag': ''},
          {'id': 2, 'flag': 0},
          {'id': 3, 'flag': false},
          {'id': 4, 'flag': null},
          {'id': 5},
        ],
      };

      final result = selector(local, r'$.items[?@.flag]', searchableKeys: null);

      expect(result.map((e) => (e as Map<String, Object?>)['id']), [
        1,
        2,
        3,
        4,
      ]);
    });

    test('supports logical and grouping in filters', () {
      final result = selector(
        sample,
        r"$.store.book[?(@.price < 10 && (@.category == 'fiction' || @.category == 'reference'))].title",
        searchableKeys: null,
      );
      expect(result, ['Sayings of the Century', 'Moby Dick']);
    });

    test('does not match missing keys when comparing with null', () {
      final local = {
        'items': [
          {'id': 1, 'maybe': null},
          {'id': 2},
          {'id': 3, 'maybe': 'value'},
        ],
      };

      final result = selector(
        local,
        r'$.items[?@.maybe == null]',
        searchableKeys: null,
      );

      expect(result.map((e) => (e as Map<String, Object?>)['id']), [1]);
    });

    test('respects grouped OR conditions in parenthesized expressions', () {
      final local = {
        'store': {
          'book': [
            {'category': 'reference', 'title': 'A', 'price': 8.95},
            {'category': 'fiction', 'title': 'B', 'price': 8.99},
            {'category': 'science', 'title': 'C', 'price': 7.5},
          ],
        },
      };

      final result = selector(
        local,
        r"$.store.book[?(@.price < 10 && (@.category == 'fiction' || @.category == 'reference'))].title",
        searchableKeys: null,
      );

      expect(result, ['A', 'B']);
    });

    test('supports bracket notation in filter paths', () {
      final result = selector(
        sample,
        r"$.store.book[?@['price'] >= 10].title",
        searchableKeys: null,
      );
      expect(result, ['Sword of Honour']);
    });

    test('keeps equality type-sensitive in filters', () {
      final result = selector(
        sample,
        r'$.mixed[?@.id == 1]',
        searchableKeys: null,
      );
      expect(result, [
        {'id': 1},
      ]);
    });

    test('returns no result for out-of-range index', () {
      final result = selector(sample, r'$.arr[100]', searchableKeys: null);
      expect(result, isEmpty);
    });
  });

  group('selector cache behavior', () {
    final sample = {
      'children': [
        {
          'id': 'a',
          'type': 'group',
          'children': [
            {'id': 'b', 'type': 'item', 'children': []},
          ],
        },
      ],
    };

    test('reuses tokenized path for same expression', () {
      resetJsonSearchCachesForTest();

      selector(sample, r'$..children');
      final first = jsonSearchCacheStatsForTest();
      selector(sample, r'$..children');
      final second = jsonSearchCacheStatsForTest();

      expect(first.tokenParseCount, 1);
      expect(second.tokenParseCount, 1);
    });

    test('reuses compiled filter expression across calls', () {
      resetJsonSearchCachesForTest();

      selector(sample, r'$..[?(@.id=="b")]');
      final first = jsonSearchCacheStatsForTest();
      selector(sample, r'$..[?(@.id=="b")]');
      final second = jsonSearchCacheStatsForTest();

      expect(first.filterCompileCount, 1);
      expect(second.filterCompileCount, 1);
    });

    test('reuses compiled filter expression across different paths', () {
      resetJsonSearchCachesForTest();

      selector(sample, r'$..children[?(@.id=="b")]');
      selector(sample, r'$..[?(@.id=="b")]');
      final stats = jsonSearchCacheStatsForTest();

      expect(stats.filterCompileCount, 1);
    });
  });
}
