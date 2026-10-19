.PHONY: build release test run icon clean

build:
	./scripts/build.sh

release:
	./scripts/build.sh Release

test:
	./scripts/test.sh

run:
	./scripts/run.sh

icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build
