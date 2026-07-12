# upstream v0.20.0 → v0.24.0 変更内容

> 調査日: 2026-07-12  
> 調査対象: `github.com/amirlehmam/wmux` タグ v0.20.0 〜 v0.24.0  
> 現在のフォーク: `github.com/bp-katsumata/wmux` @ v0.20.0  

---

## コミット一覧（7件、no-merges）

| ハッシュ | バージョン | 概要 |
|---------|-----------|------|
| `900fbb8` | v0.21.0 | サイドバー色・手動ステータス・フォントリフィット修正 |
| `b5f2a75` | v0.21.x | CDP バグ修正（ポート9222競合クラッシュ） |
| `b3997c2` | v0.21.x | `agent spawn --replace-tab` 追加 |
| `6cb6672` | v0.21.x | xterm.js 5.5.0 → 6.0.0 アップグレード |
| `1f40b85` | v0.22.0 | i18n 修正 + セッション上書き保存 |
| `0e00043` | v0.23.0 | OSC 9;4 プログレスバー対応 |
| `13c70a4` | v0.24.0 | カスタム背景 + システムフォントピッカー |

---

## 変更詳細

### v0.21.0 — サイドバー / ターミナル UX 修正（`900fbb8`）

**サイドバーのワークスペース色表示改善 (#80)**  
非アクティブのカラーつきワークスペース行に solid カラーレール + 15% ティントを追加（従来は 5% で暗いテーマでは事実上見えなかった）。

**手動ステータスオーバーライド (#81)**  
右クリックメニュー `Status Indicator` から、ワークスペースを `Running` / `Idle` に手動固定できるようになった。オーケストレーションが TUI アイドル状態を誤判定したときのフォールバック。

**フォントサイズ変更時の PTY リフィット (#82)**  
フォントサイズ変更後にターミナルがリフィットされ、PTY がリサイズされるようになった。以前はプロンプトが画面下部からずれたまま残っていた。

変更ファイル: `WorkspaceRow.tsx`, `WorkspaceContextMenu.tsx`, `useTerminal.ts`, `shared/types.ts`, `i18n/core.ts`

---

### v0.21.x — CDP クラッシュ修正（`b5f2a75`）

ポート 9222 が他のプロセスに使用されている場合、メインプロセスがクラッシュしていた問題を修正。

---

### v0.21.x — `agent spawn --replace-tab` 追加（`b3997c2`）

**問題:** `wmux layout grid --type terminal` で作成されたペインは必ずデフォルトシェルタブ（pwsh）を持ち、`wmux agent spawn` はエージェントサーフェスを 2 枚目のタブとして追加していた。オーケストレーション後、全エージェントペインに未使用シェルタブが残っていた。

**解決:** `wmux agent spawn --replace-tab` フラグを追加。ターゲットペインが「サーフェス 1 枚・ターミナル・エージェントでない」条件を満たす場合のみ、そのサーフェスをエージェントで置き換え PTY を kill する。条件不一致時は従来の追加動作にフォールバック。

変更ファイル: `wmux.ts`, `App.tsx`, `split-utils.ts`, `shared/types.ts`  
新規ヘルパー: `split-utils.ts` の `replaceSoleTerminalSurface()` (ユニットテストつき)

---

### v0.21.x — xterm.js 5.5.0 → 6.0.0（`6cb6672`）

**重大変更（破壊的）:**

| 項目 | 変更内容 |
|------|---------|
| `@xterm/addon-canvas` | **削除**（xterm 6.0 で Canvas レンダラ廃止） |
| `force-sync-cursor.ts` | **削除**（Canvas カーソル層のバグ回避コードだったため不要に） |
| レンダラーチェーン | WebGL → Canvas → DOM から **WebGL → DOM** に簡略化 |

**改善点:**
- CJK 文字の描画バグ (#23/#30) 修正（Canvas の幅広文字問題）
- Synchronized Output (DEC 2026) 対応でTUI のちらつき減少
- スクロールバー/ビューポートのリワーク、高速サーチ、メモリリーク修正
- Korean IME composition パッチは 6.0 でも引き続き有効

依存パッケージの変化:

```
削除: @xterm/addon-canvas 0.7.0
更新: @xterm/xterm         5.5.0 → 6.0.0
更新: @xterm/addon-image   0.8.0 → 0.9.0
追加: @xterm/addon-progress ^0.2.0  ← v0.23.0 で使用
更新: @xterm/addon-search   0.15.0 → 0.16.0
更新: @xterm/addon-serialize 0.13.0 → 0.14.0
更新: @xterm/addon-unicode11 0.8.0 → 0.9.0
更新: @xterm/addon-web-links 0.11.0 → 0.12.0
更新: @xterm/addon-webgl    0.18.0 → 0.19.0
```

---

### v0.22.0 — i18n 修正 + セッション上書き保存（`1f40b85`）

**UpdateBadge tooltip の i18n 修正 (#88)**  
アップデートバッジの tooltip がフランス語にハードコードされていた → `useT()` 経由で en/fr/zh 対応。

**セッション上書き保存 (#87)**  
保存ボタンがセッションメニューを「保存モード」で開くようになった。新しい名前を入力するか、既存セッションをクリックして上書き保存できる。

---

### v0.23.0 — OSC 9;4 プログレスバー（`0e00043`）

xterm 6 アップグレードで解禁された `@xterm/addon-progress` を使用。ConEmu / Windows Terminal 互換のプログレスシーケンスをサーフェスごとに解析する。

**新規実装:**

| コンポーネント | 変更内容 |
|--------------|---------|
| `progress-slice.ts` | サーフェスごとのプログレス状態を管理。集計ロジック: エラー > 通常 > 一時停止 > 不確定、determinate は平均値 |
| `useTerminal.ts` | ProgressAddon をストアに接続。PTY 終了・アンマウント時にクリア |
| `SurfaceTabBar.tsx` | タブ下端に 2px のプログレスストリップ |
| `WorkspaceRow.tsx` | ステータスラインの下に集計プログレスバー + パーセンテージ表示 |
| Windows タスクバー | `window:setProgress` IPC で `BrowserWindow.setProgressBar()` に転送 |

---

### v0.24.0 — カスタム背景 + システムフォントピッカー（`13c70a4`）

**カスタム背景（Wave 風スタイル）**  
任意の CSS 背景（グラデーション、単色、`url()` 画像）をターミナルエリア背景に設定可能。`allowTransparency` + alpha 付きテーマ背景でターミナルから透過。

- Settings > General > Custom background に設定 UI
- 透明度スライダーと名前付きプリセット
- i18n: en / fr / zh 対応

**システムフォントピッカー**  
メインプロセス側でWindowsフォントレジストリ (`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts`) からインストール済みフォントファミリーを列挙する `font-detector.ts` を新規追加。

- `system:getFonts` IPC で renderer から呼び出し
- Settings > Terminal にドロップダウン + ライブプレビュー
- 詳細用途向けのフリーテキストスタック入力も維持

新規ファイル: `src/main/font-detector.ts`, `tests/unit/font-detector.test.ts`

---

## マージ判断の参考

| 変更 | 影響 | メモ |
|------|------|------|
| xterm 6.0 | **高** | `@xterm/addon-canvas` 削除が必須。`force-sync-cursor.ts` と関連テスト削除。`useTerminal.ts` と `terminal-renderer.ts` の書き換えが大きい |
| `--replace-tab` | 低 | オーケストレーターのスクリプトと CLI 拡張のみ。このフォーク自身の `App.tsx`/`wmux.ts` 変更と競合チェックが必要 |
| OSC 9;4 プログレス | 中 | 新規 Zustand スライス追加のため競合しにくいが、`App.tsx`/`SurfaceTabBar.tsx` に変更あり |
| カスタム背景 | 低〜中 | 新規ファイル中心。既存の `useTerminal.ts` に `allowTransparency` 設定が追加される |
| セッション上書き | 低 | `SessionMenu.tsx` / `Sidebar.tsx` のみ |
| CDP クラッシュ修正 | 低 | 1ファイル修正、競合なしと思われる |

**推奨マージ順:**  
1. CDP クラッシュ修正（リスクゼロ）  
2. xterm 6.0 アップグレード（最大の変更、先に取り込んで動作確認）  
3. `--replace-tab` + OSC プログレス（xterm 6 後に追加）  
4. v0.22.0〜v0.24.0 の UI 機能（順番は任意）
