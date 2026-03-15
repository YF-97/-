#!/usr/bin/env bash
set -e

flutter build macos --release

echo "App 已生成：build/macos/Build/Products/Release/lan_clipboard_sync.app"
