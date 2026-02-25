.PHONY: get format analyze test verify dry-run

get:
	flutter pub get

format:
	dart format .

analyze:
	flutter analyze

test:
	flutter test

dry-run:
	flutter pub publish --dry-run

verify:
	./tool/verify.sh
