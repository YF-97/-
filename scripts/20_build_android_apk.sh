#!/usr/bin/env bash
set -e

flutter build apk --release

echo "APK 已生成：build/app/outputs/flutter-apk/app-release.apk"
