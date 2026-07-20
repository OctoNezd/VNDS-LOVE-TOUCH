DEVICE_ID ?= iPad (A16)
SIM_ID=$(shell xcrun simctl list devices | grep '${DEVICE_ID}' | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')

build-onmac:
	xcodebuild -scheme "SwiftVN" \
		-destination 'platform=macOS,arch=arm64,name=My Mac' \
		-configuration Debug

boot-sim:
	xcrun simctl boot ${SIM_ID} || true
	open -a Simulator

build-sim: boot-sim
	xcodebuild -scheme "SwiftVN" \
		-destination 'id=${SIM_ID}' \
		-configuration Debug \
		-derivedDataPath ./app

install-sim: boot-sim
	xcrun simctl install ${SIM_ID} ./app/Build/Products/Debug-iphonesimulator/SwiftVN.app

open-sim: boot-sim
	xcrun simctl launch ${SIM_ID} me.octonezd.SwiftVN

explore-sim: boot-sim
	open $(shell xcrun simctl get_app_container ${SIM_ID} me.octonezd.SwiftVN data)

terminate-sim: boot-sim
	xcrun simctl terminate ${SIM_ID} me.octonezd.SwiftVN || true

run-sim: terminate-sim build-sim install-sim open-sim
	exit 0

print-simid:
	echo ${SIM_ID}

open-simdir: boot-sim
	open $(shell xcrun simctl get_app_container ${SIM_ID} me.octonezd.SwiftVN data)

copy-samples: install-sim
	container=$$(xcrun simctl get_app_container ${SIM_ID} me.octonezd.SwiftVN data); \
	rsync -av --exclude="save*" ../sample_vns/* $$container/documents  
