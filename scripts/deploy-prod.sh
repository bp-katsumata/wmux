#!/usr/bin/env bash
set -e

PROD_RESOURCES="/mnt/c/Users/yuuki.katsumata/AppData/Local/wmux/resources"

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

echo "==> Deploying to production..."
if ! rm -rf "$PROD_RESOURCES/app.asar.unpacked" 2>/dev/null; then
  echo ""
  echo "ERROR: 本番 wmux が起動中です。Windows 側で wmux を終了してから再実行してください。"
  exit 1
fi
cp build-out/app.asar "$PROD_RESOURCES/app.asar"
cp -r build-out/app.asar.unpacked "$PROD_RESOURCES/app.asar.unpacked"

echo ""
echo "==> Done. 本番 wmux を起動してください:"
echo '    C:\Users\yuuki.katsumata\AppData\Local\wmux\wmux.exe'
