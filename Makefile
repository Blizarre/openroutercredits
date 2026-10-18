.PHONY: build test run clean

build:
	./scripts/build.sh

test:
	./scripts/test.sh

run:
	./scripts/run.sh

clean:
	rm -rf .build
