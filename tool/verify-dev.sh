#!/usr/bin/env bash
set -euo pipefail

export LANG=C
export LC_ALL=C

flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
dart run dependency_validator
dart run pana .
