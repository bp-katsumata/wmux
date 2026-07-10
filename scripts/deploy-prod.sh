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
# node-pty 1.1.0 bug: `dir` already ends with "/" but adds another "/"
# before the module name, producing a double slash that breaks Electron's
# ASAR → app.asar.unpacked path remapping on Windows.
sed -i 's|require(dir + "/" + name + ".node")|require(dir + name + ".node")|g' \
  .asar-staging/node_modules/node-pty/lib/utils.js
rm -rf .asar-staging/node_modules/node-pty/build

echo "==> Packing ASAR..."
npx asar pack .asar-staging build-out/app.asar --unpack-dir "node_modules/node-pty/prebuilds"

echo "==> Deploying shell-integration..."
rm -rf "$PROD_RESOURCES/shell-integration"
cp -r src/shell-integration "$PROD_RESOURCES/shell-integration"

echo "==> Deploying CLI..."
cp dist/cli/wmux.js "$PROD_RESOURCES/cli/wmux.js"

echo "==> Deploying cli-bin..."
rm -rf "$PROD_RESOURCES/cli-bin"
cp -r src/cli-bin "$PROD_RESOURCES/cli-bin"
chmod +x "$PROD_RESOURCES/cli-bin/wmux"

echo "==> Deploying to production..."
if rm -rf "$PROD_RESOURCES/app.asar.unpacked" 2>/dev/null; then
  cp build-out/app.asar "$PROD_RESOURCES/app.asar"
  cp -r build-out/app.asar.unpacked "$PROD_RESOURCES/app.asar.unpacked"
  echo ""
  echo "==> Done. 本番 wmux を起動してください:"
  echo '    C:\Users\yuuki.katsumata\AppData\Local\wmux\wmux.exe'
else
  echo "    wmux 起動中 — app.asar のみ差し替えます (native modules は次回起動時に更新)"
  if cp build-out/app.asar "$PROD_RESOURCES/app.asar" 2>/dev/null; then
    echo ""
    echo "==> Done (hot-swap). 変更を反映するには wmux を再起動してください:"
    echo '    C:\Users\yuuki.katsumata\AppData\Local\wmux\wmux.exe'
  else
    echo ""
    echo "ERROR: app.asar も使用中です。wmux を終了してから再実行してください。"
    exit 1
  fi
fi
