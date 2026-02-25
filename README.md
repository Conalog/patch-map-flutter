# patch_map_flutter

`patch_map_flutter` 패키지는 현재 초기 세팅 단계이며, 제공 기능은 준비 중입니다.

## Getting Started

```bash
flutter pub add patch_map_flutter
```

## Development

```bash
./tool/verify-dev.sh
./tool/verify-release.sh
make depcheck
make pana
make release-version
```

## Publish Checklist

1. Update `version` in `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Run `./tool/verify-release.sh`
4. Publish with `flutter pub publish`
