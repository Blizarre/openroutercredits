.PHONY: build test run icon clean

build:
	./scripts/build.sh

test:
	./scripts/test.sh

run:
	./scripts/run.sh

icon:
	swift scripts/make-icon.swift

clean:
	rm -rf .build
