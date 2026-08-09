# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# wmux — Development Guide

Electron-based Windows terminal multiplexer for AI agents. TypeScript, React 19, Zustand, xterm.js, node-pty.

**This repo**: Personal fork (`github.com/bp-katsumata/wmux`) of the upstream `github.com/amirlehmam/wmux`. Purpose: add and modify features for personal use. No upstream release planned.
**Dev environment**: WSL (Ubuntu on Windows)
**Upstream**: github.com/amirlehmam/wmux (fetch-only reference, do not push)

**Instances:**
- Production: `C:\Users\yuuki.katsumata\AppData\Local\wmux\wmux.exe`
- Dev/test: `C:\Users\yuuki.katsumata\Downloads\wmux-dev\wmux.exe` (`WMUX_INSTANCE=dev`)

---

## Build & Dev

```bash
npm run dev            # Vite (port 5199) + Electron hot-reload
npm run build:main     # tsc main/preload/cli only (fast iteration)
npm run build:renderer # Vite production build (renderer only)
npm run build          # Full: tsc + vite + electron-builder
npm test               # Vitest unit tests
npm run test:watch     # Vitest watch mode
npm run lint           # ESLint src/
```

### WSL Development

#### node-pty rebuild
Nix's npm (glibc 2.42) conflicts with Electron's Ubuntu glibc (2.39). Always rebuild node-pty with the system gcc:
```bash
rm -rf node_modules/node-pty/build
CC=/usr/bin/gcc CXX=/usr/bin/g++ npx @electron/rebuild -f -w node-pty
```

#### Running Electron in WSL
`npm run dev` crashes with SIGTRAP. Use instead:
```bash
npx concurrently "vite --port 5199" "wait-on http://localhost:5199 && electron . --no-sandbox --disable-gpu"
```

#### Deploy workflow

```bash
# Test in dev instance (safe — won't affect current session)
npm run deploy:dev
```

```powershell
# Launch dev instance on Windows
$env:WMUX_INSTANCE="dev"; & "C:\Users\yuuki.katsumata\Downloads\wmux-dev\wmux.exe"
```

```bash
# Deploy to production (hot-swap対応 — 起動中でも上書き可。変更反映には再起動が必要)
npm run deploy:prod
```

```powershell
# Production wmux location
C:\Users\yuuki.katsumata\AppData\Local\wmux\wmux.exe
```

---

## Architecture

```
src/
  main/           Electron main process
  renderer/       React UI (Vite)
  preload/        contextBridge (window.wmux)
  cli/            CLI → named pipe (\\.\pipe\wmux)
  shared/         Shared types (IPC channels, branded IDs)
  shell-integration/  Shell hooks (bash/zsh/PowerShell/cmd)

resources/        Runtime assets (icons, themes, sounds, shell-integration, CLI)
  wmux-orchestrator/  Claude Code plugin (auto-installed on startup)
site/             Landing page (static HTML, Netlify)
tests/            Unit + e2e (Vitest)
docs/             Planning docs
```

### Main Process (`src/main/`)

| File | Role |
|------|------|
| `index.ts` | Entry point, AppUserModelId, auto-save (30s), pipe server startup, V2 pipe handlers (workspace/pane/surface/markdown/sidebar/notification) |
| `pty-manager.ts` | PTY lifecycle (create with surfaceId, write, resize, kill) |
| `pipe-server.ts` | Named pipe `\\.\pipe\wmux` — V1 text (shell hooks), V2 JSON-RPC (CLI/agents) |
| `cdp-bridge.ts` | Browser webview control via Chrome DevTools Protocol |
| `cdp-proxy.ts` | CDP WebSocket proxy |
| `agent-manager.ts` | Agent PTY spawning, round-robin distribution across panes |
| `window-manager.ts` | Electron BrowserWindow creation/management |
| `ipc-handlers.ts` | All IPC channel handlers |
| `claude-context.ts` | Injects wmux instructions into `~/.claude/CLAUDE.md`, configures hooks, installs wmux-orchestrator plugin — **and the inverse of each**, since 0.40.0 |
| `agent-integration.ts` | Consent gate for every write outside `%APPDATA%\wmux` (issue #132). Asks on first launch, stores `unset`/`granted`/`declined` in wmux's own settings.json, and reconciles `~/.claude` + `~/.config/opencode` to match. Nothing in `claude-context.ts` or `opencode-context.ts` may be called directly from startup any more — route it through here |
| `claude-observer.ts` | Monitors Claude Code activity for sidebar display |
| `agent-state.ts` | Declared agent run state — blocked/working/idle, run refcount, `seq` dedupe, metadata TTL (issue #128). Also the back-channel: declared `choices` + `answerAgent`. **Answering never clears `blocked`** — the agent must confirm, or a mis-declared key silently stops a stuck pane asking for help |
| `agent-state-rpc.ts` | `pane.report_agent` & friends, routed off the main V2 switch |
| `agent-hook-bridge.ts` | Claude Code hooks → declared state, so it works with no plugin to install |
| `session-persistence.ts` | Auto-save/restore window state |
| `port-scanner.ts` | Active port detection for running dev servers |
| `shell-context-menu.ts` | "Open in wmux" Explorer verb — HKCU shell keys for Directory/Directory\Background/Drive, plus `directoryFromArgv` for the launch path. Win11 places it under "Show more options"; the modern menu needs a signed MSIX, which unsigned wmux cannot ship |
| `theme-loader.ts` | Theme loading |
| `config-loader.ts` | WT/Ghostty config import |
| `shell-detector.ts` | Available shells detection |
| `updater.ts` | Auto-update (electron-updater) |

### Renderer (`src/renderer/`)

**Components** (in `components/`):
- `SplitPane/` — PaneWrapper, SplitContainer, SplitDivider, SurfaceTabBar
- `Terminal/` — TerminalPane, FindBar, CopyMode, NotificationRing
- `Browser/` — BrowserPane, AddressBar
- `Sidebar/` — Sidebar, WorkspaceRow, SessionMenu, SidebarResizeHandle
- `Titlebar/` — Titlebar, NotificationBell, NotificationPanel
- `Settings/` — SettingsWindow + per-category panels
- `CommandPalette/` — CommandPalette
- `Markdown/` — MarkdownPane
- `Tutorial/` — Tutorial

**Hooks** (in `hooks/`):
- `useTerminal.ts` — xterm.js lifecycle, PTY connection, OSC notifications, WebGL renderer
- `useKeyboardShortcuts.ts` — 51+ shortcut actions, safe interception

**Pipe Bridge** (`pipe-bridge.ts`):
- Exposes Zustand store operations as `window.__wmux_*` globals
- Called by main process via `executeJavaScript` to bridge V2 pipe commands to renderer
- Covers: workspace CRUD, pane split/close/list, surface CRUD, markdown content, notifications

**Store** (Zustand, in `store/`):
- `workspace-slice.ts` — Workspace CRUD, split tree updates
- `surface-slice.ts` — Surface/tab add/close/move/navigate
- `settings-slice.ts` — Shortcuts, sidebar prefs, theme
- `notification-slice.ts` — Notification lifecycle (max 200)
- `agent-slice.ts` — Agent metadata tracking
- `split-utils.ts` — Immutable split tree helpers

### Preload API (`window.wmux`)

```
pty:      create, write, resize, kill, has, onData, onExit
system:   platform, getShells, openExternal, toggleDevTools, pickFolder,
          getContextMenu, setContextMenu   # "Open in wmux" Explorer verb (HKCU)
config:   getTheme, getThemeList, importWindowsTerminal, importGhostty
metadata: onUpdate
notification: fire, onFocusSurface
browser:  navigate
agent:    list, status, onUpdate
clipboard: pasteImage
hook:     onEvent
claudeActivity: onUpdate
agentState: onUpdate   # declared blocked/working/idle (issue #128)
session:  save, load, list, delete
cdp:      attach, detach
window:   create, close, focus, list, minimize, maximize, isMaximized
```

---

## Key Design Decisions

### No MCP — CLI Only
Do NOT build MCP servers. Use the wmux CLI (`wmux <command>`) via Bash instead.
The CLI talks to the named pipe, which is simpler and more reliable.
For new Claude Code integrations, add CLI commands in `src/cli/wmux.ts`.

### Branded ID Types
`WorkspaceId`, `PaneId`, `SurfaceId`, `WindowId` — branded string types in `src/shared/types.ts`.
Pattern: `surf-{uuid}`, `pane-{uuid}`, `ws-{uuid}`, `win-{uuid}`.

### Instance Isolation
`src/shared/instance.ts` exports `getPipePath()` and `getAppDataDir()`. Setting `WMUX_INSTANCE=<name>` appends a `-<name>` suffix to both the named pipe and APPDATA dir, allowing a dev build to run alongside a production wmux without pipe collision. All code that needs the pipe path or app data dir must use these helpers — never hardcode `\\.\pipe\wmux` or a fixed APPDATA path.

### Keyboard Shortcut Interception

Shortcuts are blocked from the PTY via a two-layer mechanism:

1. **`useTerminal.ts`** — `attachCustomKeyEventHandler` returns `false` for any key matching a configured shortcut (reads Zustand store via a ref so the terminal effect is never re-created on binding changes). Exceptions: `copy` and `paste`, which have dedicated terminal-side logic (copy only when selection exists; paste via Electron clipboard API).
2. **`useKeyboardShortcuts.ts`** — `handleKeyDown` iterates all shortcut bindings and fires the matching action. There is no key whitelist — any configured binding works regardless of which key it uses. `copy`/`paste`/`find`/`copyMode` are skipped here (each has its own handler path).

Adding a new shortcut only requires adding it to `DEFAULT_SHORTCUTS` in `settings-slice.ts` and a handler in `useKeyboardShortcuts.ts` — no whitelist to update.

### Keep-Alive Tabs
Terminal tabs in a pane are ALL rendered simultaneously (hidden with `visibility: hidden`).
When switching tabs, only CSS changes — the xterm instance stays alive, no PTY reconnection needed.
The `surfaceId` is passed to `pty.create()` so PTY ID = Surface ID (enables reliable re-attachment).

### Split Tree
Pane layouts use an immutable binary tree (`SplitNode`). Each leaf = one pane with N surfaces (tabs).
Mutations go through `splitNode()`, `removeLeaf()`, `findLeaf()`, `getAllPaneIds()` in `split-utils.ts`.

---

## Release Process (CRITICAL)

wmux is distributed as a **portable zip** (not NSIS installer) because without code-signing, Windows SmartScreen flags installers more aggressively than zip extractions.

### Step-by-step

```bash
# 1. Build everything
npm run build:main        # Compile TS → dist/main/, dist/preload/, dist/cli/
npx vite build            # Build renderer → dist/renderer/

# 2. Verify compiled code
# Check that fixes are in the compiled output:
python -c "import re; f=open('dist/renderer/assets/index-*.js').read(); print('OK' if 'your_fix_marker' in f else 'MISSING')"
grep -c 'your_fix_string' dist/main/index.js

# 3. Create ASAR staging
# IMPORTANT: always run from the project root (use absolute paths or cd back
# after any `cd .asar-staging`). If cwd drifts into .asar-staging during this
# section, subsequent `mkdir build-out` lands INSIDE the staging dir and the
# next asar pack will recursively include its own previous output → 188M asar.
rm -rf .asar-staging build-out
mkdir -p .asar-staging build-out
cp -r dist .asar-staging/dist          # explicit dest path — trailing-slash form is flaky on Git Bash
cp package.json .asar-staging/package.json
( cd .asar-staging && npm install --omit=dev --ignore-scripts )   # subshell — cwd doesn't leak
rm -rf .asar-staging/node_modules/node-pty/build   # force prebuilds load path: conpty.dll (useConptyDll) resolves relative to the LOADED conpty.node, and only prebuilds/win32-x64/ has the conpty/ dir next to it

# 4. Pack ASAR (with native module unpacking)
# Use --unpack-dir (path-based), NOT --unpack "**/*.node" — the glob form
# silently fails on Git Bash for Windows (shell eats the pattern, asar produces
# the asar but creates no .unpacked dir, no error). Output to build-out/ so we
# never touch the live resources/app.asar while wmux may be running.
npx asar pack .asar-staging build-out/app.asar --unpack-dir "node_modules/node-pty/prebuilds"

# 5. Verify native modules are unpacked
ls build-out/app.asar.unpacked/node_modules/node-pty/prebuilds/win32-x64/
# Must contain: conpty.node, conpty_console_list.node, pty.node
# Sanity: ASAR should be ~24M (natives unpacked). 80M+ means natives weren't
# moved out; 180M+ means staging got polluted (see step 3 warning).

# 5b. Verify the PRs/fixes you intended to ship are actually inside the ASAR.
# extract-file's stdout piping is unreliable on Windows — extract to /tmp instead.
rm -rf /tmp/asar-verify && mkdir -p /tmp/asar-verify
( cd /tmp/asar-verify && npx --prefix "$(pwd)" asar extract "$(pwd)/build-out/app.asar" . )
grep -c 'your_fix_marker' /tmp/asar-verify/dist/renderer/assets/index-*.js
grep -c 'your_fix_string' /tmp/asar-verify/dist/main/index.js

# 6. Create release staging
# Easiest base: the previous release zip. Avoids needing a separate
# wmux_v_extracted/ dir and avoids picking up stray files from the project root.
rm -rf ../wmux-release-staging
mkdir -p ../wmux-release-staging
( cd ../wmux-release-staging && unzip -q ../wmux/wmux-<PREV_VERSION>-win-x64.zip )

# 7. Copy ASAR + resources into release staging
cp build-out/app.asar ../wmux-release-staging/resources/app.asar
rm -rf ../wmux-release-staging/resources/app.asar.unpacked
cp -r build-out/app.asar.unpacked ../wmux-release-staging/resources/app.asar.unpacked
cp resources/icon.png ../wmux-release-staging/resources/
rm -rf ../wmux-release-staging/resources/themes && cp -r resources/themes ../wmux-release-staging/resources/themes
rm -rf ../wmux-release-staging/resources/sounds && cp -r resources/sounds ../wmux-release-staging/resources/sounds
mkdir -p ../wmux-release-staging/resources/cli && cp dist/cli/wmux.js ../wmux-release-staging/resources/cli/wmux.js
cp dist/cli/wmux-hook.js ../wmux-release-staging/resources/cli/wmux-hook.js   # Claude hooks exec this via bare node — MUST ship outside the asar (missing until 0.29.1 → sidebar stuck on "Running", issue #81)
rm -rf ../wmux-release-staging/resources/shell-integration && mkdir -p ../wmux-release-staging/resources/shell-integration
cp -r src/shell-integration/* ../wmux-release-staging/resources/shell-integration/
rm -rf ../wmux-release-staging/resources/wmux-orchestrator && cp -r resources/wmux-orchestrator ../wmux-release-staging/resources/wmux-orchestrator

# 8. Embed icon + metadata in exe (rcedit)
# CRITICAL: rcedit exports `{ rcedit }` (named export). `const rcedit =
# require('rcedit')` followed by `rcedit(...)` throws "rcedit is not a function".
# Always destructure: `const { rcedit } = require('rcedit')`.
node -e "
  const { rcedit } = require('rcedit');
  rcedit('../wmux-release-staging/wmux.exe', {
    icon: 'resources/icons/icon.ico',
    'version-string': {
      ProductName: 'wmux',
      FileDescription: 'wmux',
      CompanyName: 'wmux',
      InternalName: 'wmux',
      OriginalFilename: 'wmux.exe',
      LegalCopyright: 'Copyright (c) 2026 wmux'
    },
    'file-version': '0.7.20',
    'product-version': '0.7.20'
  }).then(() => console.log('rcedit done'), e => { console.error(e); process.exit(1); });
"
# NOTE: rcedit CANNOT modify a running exe. The staging copy is fine; never
# point rcedit at the wmux.exe living in the project root if it's running.

# 9. Create zip
powershell -NoProfile -Command "Compress-Archive -Path '..\wmux-release-staging\*' -DestinationPath '..\wmux-<VERSION>-win-x64.zip' -CompressionLevel Optimal"

# 9b. latest.yml — DO NOT generate one pointing at the zip for a manual
# release. Installed clients use NsisUpdater: a zip in latest.yml downloads
# but never installs (endless update loop, issue #96). latest.yml must point
# at an NSIS setup.exe, which only the CI build produces — so for a full
# release, prefer tagging and letting CI ship setup.exe + zip + latest.yml.
# A manual zip-only release simply ships WITHOUT latest.yml (the updater
# handles its absence gracefully since 0.28; the notify-only checker still
# surfaces the new version). Legacy snippet kept for reference:
node -e "
  const crypto = require('crypto'); const fs = require('fs');
  const version = '<VERSION>';
  const zip = '../wmux-' + version + '-win-x64.zip';
  const data = fs.readFileSync(zip);
  const sha512 = crypto.createHash('sha512').update(data).digest('base64');
  const yaml = ['version: ' + version, 'files:', '  - url: wmux-' + version + '-win-x64.zip',
    '    sha512: ' + sha512, '    size: ' + data.length, 'path: wmux-' + version + '-win-x64.zip',
    'sha512: ' + sha512, 'releaseDate: ' + JSON.stringify(new Date().toISOString()), ''].join('\n');
  fs.writeFileSync('../latest.yml', yaml);
  console.log('latest.yml written:', data.length, 'bytes,', sha512.slice(0, 16) + '...');
"

# 10. Tag, push, publish (zip AND latest.yml — both assets are required)
git add package.json package-lock.json && git commit -m "chore(release): bump to <VERSION>"
git push origin master
git tag -a v<VERSION> -m "wmux <VERSION>" && git push origin v<VERSION>
gh release create v<VERSION> ../wmux-<VERSION>-win-x64.zip ../latest.yml --repo amirlehmam/wmux --title "v<VERSION>" --notes "..."

# 11. (Optional) Hot-swap into the locally running wmux for immediate testing
cp build-out/app.asar resources/app.asar
rm -rf resources/app.asar.unpacked && cp -r build-out/app.asar.unpacked resources/app.asar.unpacked
# Then restart wmux to pick up changes

# 12. Cleanup
rm -rf .asar-staging build-out /tmp/asar-verify ../wmux-release-staging
```

### Release Checklist

- [ ] `npm run build:main` succeeds
- [ ] `npx vite build` succeeds
- [ ] Compiled code verified (grep for key changes in dist/)
- [ ] ASAR packed with `--unpack-dir node_modules/node-pty/prebuilds` (NOT `--unpack` glob)
- [ ] ASAR size is ~24M (natives unpacked). 80M+ ⇒ unpack didn't take. 180M+ ⇒ staging polluted.
- [ ] node-pty native modules present in `app.asar.unpacked/node_modules/node-pty/prebuilds/win32-x64/`
- [ ] PR-specific markers grep-confirmed inside the packed ASAR (extracted to /tmp)
- [ ] wmux-orchestrator plugin copied to release staging
- [ ] rcedit applied (icon + version metadata) — `{ rcedit }` destructured
- [ ] `latest.yml` generated (sha512 + size of the final zip) and uploaded as a release asset — electron-updater 404s without it (issue #68)
- [ ] Zip created and uploaded to GitHub release
- [ ] Mark of the Web: remind user to right-click > Unblock after download

### Important Notes

- **rcedit can't modify a running exe** — always work on a copy
- **rcedit named export**: `const { rcedit } = require('rcedit')`. Non-destructured `const rcedit = require('rcedit')` throws "rcedit is not a function" (different from older docs).
- **asar `--unpack` glob silently fails on Git Bash for Windows**: pattern like `"**/*.node"` gets shell-eaten and asar emits no `.unpacked/` dir, no error. Use `--unpack-dir node_modules/node-pty/prebuilds` (path-based) instead.
- **Bash cwd drift can recursively pollute staging**: if you `cd .asar-staging` and forget to come back, the next `mkdir build-out && asar pack` creates `.asar-staging/build-out/app.asar`, and a re-pack will swallow its own output into the new asar (188M). Always use subshells `( cd dir && cmd )` or absolute paths.
- **Don't pack ASAR directly to `resources/app.asar`** if wmux may be running — pack to `build-out/` and copy at step 7.
- **MOTW (Mark of the Web)**: Downloaded zips get `Zone.Identifier` NTFS stream. Fix: `powershell "Get-ChildItem -Recurse | Unblock-File"`
- **Windows taskbar pinning** uses PE `FileDescription` for the shortcut name — ensure rcedit sets it to "wmux"
- **AppUserModelId** is set to `com.wmux.app` in `src/main/index.ts` for proper taskbar grouping

---

## Named Pipe V2 Handlers

The pipe server in `index.ts` handles V2 JSON-RPC methods. Most delegate to the renderer via `executeJavaScript('window.__wmux_*(...)')`. The renderer's `pipe-bridge.ts` exposes Zustand store operations as these globals.

**Fully implemented V2 methods:**
- `system.identify`, `system.capabilities`, `system.tree`
- `workspace.create`, `workspace.close`, `workspace.select`, `workspace.rename`, `workspace.list`
- `pane.split`, `pane.close`, `pane.focus`, `pane.zoom`, `pane.list`
- `surface.create`, `surface.close`, `surface.focus`, `surface.rename`, `surface.list`
- `surface.send_text`, `surface.send_key`, `surface.read_text`, `surface.trigger_flash`
- `markdown.set_content`, `markdown.load_file`, `markdown.get_content`
- `notification.list`, `notification.clear`
- `sidebar.set_status`, `sidebar.set_progress`, `sidebar.log`, `sidebar.get_state`
- `browser.*` (via CDP bridge)
- `agent.spawn`, `agent.spawn_batch`, `agent.status`, `agent.list`, `agent.kill`
- `pane.report_agent`, `pane.report_agent_session`, `pane.report_metadata`, `pane.release_agent`, `pane.agent_state`
- `pane.answer_agent` — the back-channel (issue #128). The only non-`report_*` method: it WRITES into a pane's PTY. Guarded — refuses unless the pane is currently `blocked`, and only ever sends a payload the agent itself declared
- `hook.event`, `diff.refresh`

---

## wmux-orchestrator Plugin

Claude Code plugin bundled in `resources/wmux-orchestrator/`. Installed into `~/.claude/plugins/cache/` on startup by `ensureOrchestratorPlugin()` in `claude-context.ts` — but only when the user has granted the `orchestrator` feature (issue #132); `agent-integration.ts` owns that call. Also published standalone: `github.com/amirlehmam/wmux-orchestrator`.

**What it does:** Decomposes complex dev tasks into parallel Claude Code agents coordinated through dependency-aware waves with automated review. With wmux: each agent in its own visible terminal pane. Without wmux: falls back to native subagents.

**Key design:** Skills handle intelligence (prompts), hooks handle reactivity (events), scripts handle wmux operations (CLI). State shared via JSON file in TMPDIR. No daemon.

---

## CLI Reference

```bash
# System
wmux ping | identify | capabilities
wmux new-window | list-windows | focus-window <id>

# Workspaces
wmux new-workspace [--title T] [--shell S] [--cwd D]   # --shell accepts args: --shell "ssh user@host"
wmux close-workspace | select-workspace | rename-workspace | list-workspaces
wmux ssh [ssh options] <user@host> [--title T]         # remote terminal in a new workspace (issue #78)

# Remote wmux management (issue #78): drive another machine's wmux over an SSH tunnel
wmux bridge [--port P] [--host H]     # on the remote: expose its pipe on TCP (default 127.0.0.1:9787)
wmux token                            # on the remote: print its auth token
wmux --remote host[:port] --token T <any command>   # on the client (through `ssh -L port:127.0.0.1:port`)
                                      # env equivalents: WMUX_REMOTE, WMUX_REMOTE_TOKEN

# Markdown surfaces
wmux markdown <file> | markdown set <id> --content <text> [--title T] | --file <path>
wmux markdown get <id>                                 # read a surface's buffer back out

# Surfaces (tabs within a pane)
wmux new-surface [--type terminal|browser|markdown]
wmux close-surface | focus-surface | rename-surface | list-surfaces

# Panes
wmux split [--down] [--type T] | close-pane | focus-pane | zoom-pane | list-panes | tree

# Terminal I/O
wmux send <text> | send-key <key> [--ctrl] [--shift] [--alt]
wmux read-screen [--lines N] [--surface <id>] | trigger-flash

# Browser (CDP)
wmux browser open <url> | snapshot | click eN | type eN <text>
wmux browser fill eN <value> | get-text | screenshot | eval <js>
wmux browser back | forward | reload

# Declared agent state (issue #128) — blocked / working / idle, no screen scraping.
# Surface defaults to $WMUX_SURFACE_ID, so an agent inside a pane needs no id.
wmux report-agent --blocked "permission: Bash"   # parked on a human
wmux report-agent --blocked "Run it?" --choices '[{"id":"y","label":"Yes","key":"1"}]'
wmux answer-agent --surface <id> --choice y      # reply to ANOTHER pane, from yours
wmux report-agent --unblocked                    # the human answered
wmux report-agent --run-start | --run-end        # refcount, so nested subagents nest
wmux report-agent --run-depth N [--seq N]        # absolute depth; --seq drops replays
wmux report-metadata [--model M] [--tokens T] [--context-pct N] [--ttl ms]
wmux report-session <id> | release-agent
wmux agent-state [--surface <id>]                # no --surface → all panes + blocked list

# Agents
wmux agent spawn [--cmd C] [--label L] [--cwd D] [--pane P] [--replace-tab]
wmux agent spawn-batch --json '[...]' [--strategy distribute|stack|split]
wmux agent status <id> | list | kill <id>

# Notifications & Sidebar
wmux notify <text> | list-notifications | clear-notifications
wmux set-status <key> <value> | set-progress <val> [--label L]
wmux log <level> <message> | sidebar-state

# Hooks
wmux hook --event <type> --tool <name> [--agent <id>]
```

---

## IPC Channels

All defined in `src/shared/types.ts` → `IPC_CHANNELS`:

```
PTY:     pty:create, pty:write, pty:resize, pty:kill, pty:has, pty:data, pty:exit
Window:  window:create/close/focus/list/minimize/maximize/isMaximized
Config:  config:getTheme/getThemeList/importWindowsTerminal/importGhostty
System:  system:getShells/openExternal
Notify:  notification:fire/list/clear/jump
Agent:   agent:spawn/spawn-batch/status/list/kill/update
CDP:     cdp:attach/detach
Session: session:save-named/load-named/list-named/delete-named
Meta:    metadata:update, hook:event, claude:activity, agent:state
```

---


## Shell Integration

Scripts in `src/shell-integration/` (deployed to `resources/shell-integration/`):

| Script | Reports |
|--------|---------|
| `wmux-powershell-integration.ps1` | cwd, git branch/dirty, shell state, PR polling (45s) |
| `wmux-bash-integration.sh` | cwd, git branch/dirty, shell state, ports |
| `wmux-cmd-integration.cmd` | Basic OSC 9 escape sequences |

Env vars set by wmux in spawned shells: `WMUX=1`, `WMUX_SURFACE_ID`, `WMUX_PIPE`, `WMUX_CLI`.

---


## Testing

```bash
npm test                    # Run all unit tests
npm run test:watch          # Watch mode
npx vitest run tests/unit/pty-manager.test.ts  # Single file
```

Test files in `tests/unit/`: agent-manager, cdp-bridge, config-loader, notification-slice, pipe-server, port-scanner, pty-manager, session-persistence, shell-detector, split-tree.

---

## Session Management

- **Between unrelated tasks** (e.g. renderer fix → release work): run `/clear` to reset context
- **After correcting the same mistake twice**: run `/clear` and start fresh with a more specific prompt — accumulated failed attempts degrade performance
- **After a long debugging session**: run `/compact` to compress history while preserving key decisions
- Use `/rewind` to restore a previous conversation + code state if a direction went wrong

When compacting, always preserve: the full list of modified files, any verification criteria checklist, build errors encountered and how they were resolved.

**Investigation**: When a task requires reading many files to understand existing behavior (e.g. tracing a bug, mapping an unfamiliar subsystem), delegate to a subagent: `"use subagents to investigate X"`. The subagent explores in its own context and reports findings, keeping the main conversation clean for implementation.

**Side questions**: Use `/btw` for quick lookups (type signatures, function names, config values) that don't need to stay in conversation history. The answer appears in a dismissible overlay and adds no tokens to context.

---

## Verification Criteria

For any task that produces a deliverable (new feature, code modification, UI component, document, etc.):

1. **Before starting**: Write a checklist of concrete, verifiable criteria in the conversation and wait for user approval. If the criteria are not clear from the request, ask the user to clarify them first — do not start work until criteria are confirmed.
2. **After completing**: If the task modified source code or config files (i.e. `git diff` is non-empty), use the `code-reviewer` subagent to review the diff against the criteria. Then go through each criterion and report pass ✅ or fail ❌. If any criterion fails, fix it before declaring the task done.

Example format:
```
Verification criteria:
- [ ] TypeScript compiles with no errors (`npm run build:main`)
- [ ] Existing tests pass (`npm test`)
- [ ] The new shortcut is intercepted from the terminal and does not pass through to the PTY
```

---

## Prompt Clarity

For any prompt that may involve code or config changes:

1. **Check if both the target and the change are explicitly stated.** If either is missing or ambiguous, present your interpretation before starting: _"I'm interpreting this as [X]. Is that correct?"_
2. **Wait for confirmation** before proceeding. If the interpretation is wrong, adjust and re-confirm.
3. This applies even when Claude could infer the intent from reading the code — the goal is to align before acting, not after.

Skip this step only when the target file(s) and the specific change are both unambiguously stated in the prompt.

---

## Conventions

- **Context7 MCP**: Always use Context7 MCP (`mcp__plugin_context7_context7__resolve-library-id` + `mcp__plugin_context7_context7__query-docs`) when referencing library or API documentation, generating code that depends on a framework, or following setup/configuration instructions — do this automatically without being asked explicitly.
- **Source transparency**: When answering investigations or questions, always list every file read and every web source consulted — never omit or abbreviate them.
- **State**: Zustand slices in `src/renderer/store/`, composed in `index.ts`
- **IPC**: Channels defined in `src/shared/types.ts`, never use magic strings
- **CSS**: `src/renderer/styles/`, class prefix per component (`.pane-wrapper__*`, `.surface-tab__*`)
- **Immutable trees**: Split tree mutations always produce new objects via `patchLeaf()`
- **PTY IDs = Surface IDs**: Always pass `surfaceId` when creating PTYs for reliable re-attachment
- **No MCP**: All Claude Code integration via CLI commands
- **French comms**: User communicates in French, code/docs in English

---

## Terminology (from `CONTEXT.md`)

Use these exact terms in code, comments, and UI strings:

| Term | Meaning | Avoid |
|------|---------|-------|
| **Surface** | A single terminal/browser/markdown/diff instance shown as a tab inside a pane | Console window, terminal window, panel |
| **Pane** | A rectangular region in the split tree containing one or more surfaces | Console window, tab |
| **Live Layout Preview** | Temporary workspace preview shown while dragging a surface tab | Drop zone highlight, ghost split preview |

---

## Agent skills

### Issue tracker

Issues live in GitHub Issues for `bp-katsumata/wmux`. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — `CONTEXT.md` at the repo root plus `docs/adr/`. See `docs/agents/domain.md`.
