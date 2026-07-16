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
# node-pty 1.1.0 bug: `dir` already ends with "/" but adds another "/"
# before the module name, producing a double slash that breaks Electron's
# ASAR → app.asar.unpacked path remapping on Windows.
sed -i 's|require(dir + "/" + name + ".node")|require(dir + name + ".node")|g' \
  .asar-staging/node_modules/node-pty/lib/utils.js
rm -rf .asar-staging/node_modules/node-pty/build

echo "==> Packing ASAR..."
npx asar pack .asar-staging build-out/app.asar --unpack-dir "node_modules/node-pty/prebuilds"

echo "==> Deploying shell-integration..."
rm -rf "$DEV_RESOURCES/shell-integration"
cp -r src/shell-integration "$DEV_RESOURCES/shell-integration"

echo "==> Deploying CLI..."
cp dist/cli/wmux.js "$DEV_RESOURCES/cli/wmux.js"
cp dist/cli/wmux-hook.js "$DEV_RESOURCES/cli/wmux-hook.js"

echo "==> Deploying cli-bin..."
rm -rf "$DEV_RESOURCES/cli-bin"
cp -r src/cli-bin "$DEV_RESOURCES/cli-bin"
chmod +x "$DEV_RESOURCES/cli-bin/wmux"

echo "==> Deploying to wmux-dev..."
if rm -rf "$DEV_RESOURCES/app.asar.unpacked" 2>/dev/null; then
  cp build-out/app.asar "$DEV_RESOURCES/app.asar"
  cp -r build-out/app.asar.unpacked "$DEV_RESOURCES/app.asar.unpacked"
  echo "==> Done. Launch wmux-dev on Windows:"
  echo '    $env:WMUX_INSTANCE="dev"; & "C:\Users\yuuki.katsumata\Downloads\wmux-dev\wmux.exe"'
else
  echo "    wmux-dev 起動中 — app.asar のみ差し替えます (native modules は次回起動時に更新)"
  if cp build-out/app.asar "$DEV_RESOURCES/app.asar" 2>/dev/null; then
    echo "==> Done (hot-swap). 変更を反映するには wmux-dev を再起動してください:"
    echo '    $env:WMUX_INSTANCE="dev"; & "C:\Users\yuuki.katsumata\Downloads\wmux-dev\wmux.exe"'
  else
    echo ""
    echo "ERROR: app.asar も使用中です。wmux-dev を終了してから再実行してください。"
    exit 1
  fi
fi
