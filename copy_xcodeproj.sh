#!/bin/bash
rm -rf xcode
mkdir -p xcode
cp -rv ./love/platform/xcode/Images.xcassets xcode
cp -rv ./love/platform/xcode/ios/love-ios.plist xcode
cp -rv ./love/platform/xcode/vnds.xcodeproj xcode
