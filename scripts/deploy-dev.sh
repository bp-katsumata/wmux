#!/usr/bin/env bash
set -e

DEV_RESOURCES="/mnt/c/Users/yuuki.katsumata/Downloads/wmux-dev/resources"

echo "==> Building..."
npm run build:main
npx vite build

echo "==> Staging..."
rm -rf .asar-staging build-out
mkdir -p .asar-staging build-out
cp -r dist .asar-staging/dist
cp package.json .asar-staging/package.json
( cd .asar-staging && npm install --omit=dev --ignore-scripts )
rm -rf .asar-staging/node_modules/node-pty/build

echo "==> Packing ASAR..."
npx asar pack .asar-staging build-out/app.asar --unpack-dir "node_modules/node-pty/prebuilds"

echo "==> Deploying to wmux-dev..."
if ! rm -rf "$DEV_RESOURCES/app.asar.unpacked" 2>/dev/null; then
  echo ""
  echo "ERROR: wmux-dev のファイルが使用中です。Windows 側で wmux-dev を終了してから再実行してください。"
  exit 1
fi
cp build-out/app.asar "$DEV_RESOURCES/app.asar"
cp -r build-out/app.asar.unpacked "$DEV_RESOURCES/app.asar.unpacked"

echo "==> Done. Launch wmux-dev on Windows:"
echo '    $env:WMUX_INSTANCE="dev"; & "C:\Users\yuuki.katsumata\Downloads\wmux-dev\wmux.exe"'
