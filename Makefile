build:
	swift build -c release

test:
	swift test \
		--enable-test-discovery \
		--parallel
	
