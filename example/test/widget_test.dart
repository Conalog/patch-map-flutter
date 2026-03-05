import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_map_flutter/patch_map_flutter.dart';
import 'package:patch_map_flutter_example/main.dart';

const String _publicImageUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg';

const List<Object?> _testElements = <Object?>[
  <String, Object?>{
    'type': 'image',
    'id': 'status-image',
    'label': 'status-image',
    'show': true,
    'attrs': <String, Object?>{'x': 24, 'y': 140, 'zIndex': 1},
    'source': _publicImageUrl,
    'tint': '#ffffff',
    'size': <String, Object?>{'w': 48, 'h': 48},
  },
  <String, Object?>{
    'type': 'text',
    'id': 'title',
    'label': 'initial-label',
    'show': true,
    'attrs': <String, Object?>{'x': 0, 'y': 0, 'zIndex': 1},
    'text': 'Initial title',
    'style': <String, Object?>{'fontSize': 14, 'fill': 'black'},
    'size': <String, Object?>{'w': 120, 'h': 28},
  },
];

void main() {
  testWidgets('buttons update all target TextElement states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(PatchmapExampleApp(initialElements: _testElements));
    await _pumpUntilFound(tester, find.text('text=Initial title'));

    expect(find.text('text=Initial title'), findsOneWidget);
    expect(find.text('label=initial-label'), findsOneWidget);
    expect(find.text('show=true'), findsOneWidget);
    expect(find.text('attrs.x=0 attrs.y=0 attrs.zIndex=1'), findsOneWidget);
    expect(find.text('style.fontSize=14 style.fill=black'), findsOneWidget);
    expect(find.text('size.w=120 size.h=28'), findsOneWidget);
    expect(find.text('image.source=$_publicImageUrl'), findsOneWidget);
    expect(find.text('image.tint=#ffffff'), findsOneWidget);
    expect(find.text('image.size.w=48 image.size.h=48'), findsOneWidget);
    expect(
      find.text('image.attrs.x=24 image.attrs.y=140 image.attrs.zIndex=1'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('btn-update-text')));
    await _pumpFrames(tester, 3);
    expect(find.text('text=Updated title'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-update-label')));
    await _pumpFrames(tester, 3);
    expect(find.text('label=updated-label'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-hide')));
    await _pumpFrames(tester, 3);
    expect(find.text('show=false'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-show')));
    await _pumpFrames(tester, 3);
    expect(find.text('show=true'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-update-attrs')));
    await _pumpFrames(tester, 3);
    expect(find.text('attrs.x=120 attrs.y=32 attrs.zIndex=9'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-update-style')));
    await _pumpFrames(tester, 3);
    expect(find.text('style.fontSize=20 style.fill=red'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-update-size')));
    await _pumpFrames(tester, 3);
    expect(find.text('size.w=300 size.h=60'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-image-warning')));
    await _pumpFrames(tester, 3);
    expect(find.text('image.source=warning'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-image-size')));
    await _pumpFrames(tester, 3);
    expect(find.text('image.size.w=72 image.size.h=72'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-image-tint')));
    await _pumpFrames(tester, 3);
    expect(find.text('image.tint=#ff0000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('btn-image-move')));
    await _pumpFrames(tester, 3);
    expect(
      find.text('image.attrs.x=180 image.attrs.y=140 image.attrs.zIndex=5'),
      findsOneWidget,
    );

    // TextBoxComponent internally uses delayed timers when refreshing cache.
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('loads downloaded svg asset via init options', (
    WidgetTester tester,
  ) async {
    final patchmap = Patchmap();

    await patchmap.init(
      options: const PatchmapInitOptions(
        assets: PatchmapInitAssets(
          iconAssetPathByAlias: <String, String>{
            'downloaded-bolt': 'assets/icons/downloaded-bolt.svg',
          },
        ),
      ),
    );

    expect(patchmap.app.iconSvgByAlias.keys, contains('downloaded-bolt'));
    expect(patchmap.app.iconSvgByAlias['downloaded-bolt'], contains('<svg'));
  });
}

Future<void> _pumpFrames(WidgetTester tester, int frameCount) async {
  for (var i = 0; i < frameCount; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  const maxFrames = 1200;
  for (var i = 0; i < maxFrames; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}
