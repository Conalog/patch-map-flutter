.PHONY: get format analyze test depcheck pana verify verify-dev verify-release dry-run release-version release-bump-patch

get:
	flutter pub get

format:
	dart format .

analyze:
	flutter analyze

test:
	flutter test

depcheck:
	dart run dependency_validator

pana:
	dart run pana .

dry-run:
	flutter pub publish --dry-run

verify:
	./tool/verify-dev.sh

verify-dev:
	./tool/verify-dev.sh

verify-release:
	./tool/verify-release.sh

release-version:
	dart run cider version

release-bump-patch:
	dart run cider bump patch
