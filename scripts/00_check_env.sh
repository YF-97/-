#!/usr/bin/env bash
set -e

echo "[1/3] 检查 Flutter"
flutter --version

echo "[2/3] 启用 macOS 桌面支持"
flutter config --enable-macos-desktop

echo "[3/3] 环境体检"
flutter doctor

echo "完成：环境检查通过。"
