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

### Known Build Gotcha

Project lives in `OneDrive - Pulsa` (path with spaces). This breaks:
- `npm link` / `node-gyp` (can't build node-pty)
- `electron-builder` winCodeSign (symlink errors)

**Workaround**: Don't use `electron-builder` for the final package. Use ASAR-based manual packaging (see Release Process below).

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
# Deploy to production (close wmux first — running processes will not be restored)
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

## Release Process

See `/release` skill for the full step-by-step process (build → ASAR pack → staging → zip → tag → publish).

---

## wmux-orchestrator Plugin

Claude Code plugin bundled in `resources/wmux-orchestrator/`. Auto-installed into `~/.claude/plugins/cache/` on startup by `ensureOrchestratorPlugin()` in `claude-context.ts`. Also published standalone: `github.com/amirlehmam/wmux-orchestrator`.

**What it does:** Decomposes complex dev tasks into parallel Claude Code agents coordinated through dependency-aware waves with automated review. With wmux: each agent in its own visible terminal pane. Without wmux: falls back to native subagents.

**Key design:** Skills handle intelligence (prompts), hooks handle reactivity (events), scripts handle wmux operations (CLI). State shared via JSON file in TMPDIR. No daemon.

---

## CLI Reference

```bash
# System
wmux ping | identify | capabilities

# Workspaces
wmux new-workspace [--title T] [--shell S] [--cwd D]
wmux close-workspace | select-workspace | rename-workspace | list-workspaces

# Surfaces (tabs within a pane)
wmux new-surface [--type terminal|browser|markdown]
wmux close-surface | focus-surface | list-surfaces

# Panes
wmux split [--down] [--type T] | close-pane | focus-pane | zoom-pane | list-panes | tree

# Terminal I/O
wmux send <text> | send-key <key> [--ctrl] [--shift] [--alt]
wmux read-screen [--lines N] | trigger-flash

# Browser (CDP)
wmux browser open <url> | snapshot | click @eN | type @eN <text>
wmux browser fill @eN <value> | get-text | screenshot | eval <js>
wmux browser back | forward | reload

# Agents
wmux agent spawn [--cmd C] [--label L] [--cwd D] [--pane P]
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
2. **After completing**: Use the `code-reviewer` subagent to review the diff against the criteria. Then go through each criterion and report pass ✅ or fail ❌. If any criterion fails, fix it before declaring the task done.

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
