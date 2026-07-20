ipadid=$(shell xcrun simctl list devices | grep 'iPad (A16)' | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')

build-onmac:
	xcodebuild -scheme "SwiftVN" \
		-destination 'platform=macOS,arch=arm64,name=My Mac' \
		-configuration Debug
build-ipadsim:
	xcodebuild -scheme "SwiftVN" \
		-destination 'platform=iOS Simulator,arch=arm64,name=iPad (A16)' \
		-configuration Debug \
		-derivedDataPath ./app

install-ipadsim:
	xcrun simctl install ${ipadid} ./app/Build/Products/Debug-iphonesimulator/SwiftVN.app

open-ipadsim:
	xcrun simctl launch ${ipadid} me.octonezd.SwiftVN

explore-ipadsim:
	open $(shell xcrun simctl get_app_container ${ipadid} me.octonezd.SwiftVN data)

terminate-ipadsim:
	xcrun simctl terminate ${ipadid} me.octonezd.SwiftVN

run-ipadsim: terminate-ipadsim build-ipadsim install-ipadsim open-ipadsim
	exit 0


open-simdir:
	open $(xcrun simctl get_app_container booted me.octonezd.SwiftVN data)
