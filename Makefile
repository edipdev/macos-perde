.PHONY: build run test clean

build:
	@bash Scripts/build-app.sh release

run: build
	@pkill -f "Perde.app/Contents/MacOS/Perde" 2>/dev/null; sleep 1; open build/Perde.app

test:
	@swift test

clean:
	@rm -rf .build build
