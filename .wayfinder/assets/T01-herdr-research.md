# T01 Research: herdr コードベース精査レポート

> Generated: 2026-07-11  
> Source: https://github.com/ogulcancelik/herdr (v0.7.3, 15.2k stars)

---

## herdr とは

Rust 製ターミナルマルチプレクサ。tmux の拡張ではなく、**AI エージェントのオーケストレーション**に特化した設計。PTY を保持したままプロセスを detach/reattach でき、エージェントの状態をターミナル出力から自動検出し、ソケット API でエージェント間連携を実現する。

---

## 1. セッション永続化（detach/reattach）

### herdr の実装

- ワークスペース/タブ/ペインの状態を `~/.config/herdr/session.json` に変更ごとにスナップショット
- PTY ファイルデスクリプタを Unix ソケット経由で `HandoffManifest` として渡す（プロトコルバージョン管理あり）
- Claude / Pi / Devin などエージェントのセッション ID を `PersistedAgentSession` 構造体で保持
- スクロールバックを `session-history.json` から再生（オプション）
- 主要ファイル: `src/persist.rs`, `src/server/handoff.rs`, `src/agent_resume.rs`

### wmux との差分

| | herdr | wmux |
|---|---|---|
| レイアウト保存 | ✅ | ✅ (`~/.wmux/config.json`) |
| PTY 引き継ぎ | ✅ FD 渡し | ❌ プロセス消える |
| エージェントセッション | ✅ | ❌ |
| スクロールバック再生 | ✅ | ❌ |

### 採用検討

**推奨: YES**。Windows では名前付きパイプが FD 渡しに対応しないため、Phase 1 は「Claude Code セッション ID を `~/.wmux/state.json` に保存し、再起動後に resume コマンドを提供」が現実的。PTY 完全引き継ぎは Phase 2 以降（ConPTY 調査要）。

---

## 2. エージェント状態ダッシュボード

### herdr の実装

- ペインのターミナル出力末尾 8 KB を定期取得し、TOML 定義の 20+ エージェントマニフェストとパターンマッチ
- `AgentState`: Idle / Working / Blocked / Unknown を生成
- 信頼度メタデータ（`visible_idle`, `visible_blocker`, `visible_working`）でUI文字列と本文を区別
- ヒステリシス: Working→Idle 遷移を 700ms + 3 確認で安定化（チラつき防止）
- 主要ファイル: `src/detect/mod.rs`, `src/pane/agent_detection.rs`, `src/detect/manifest.rs`

### wmux との差分

- wmux のシェル統合は汎用 idle/running/interrupted のみ
- エージェント識別・画面パターンマッチ・複数エージェント対応はなし

### 採用検討

**推奨: MAYBE（設計会話優先）**。TOML マニフェスト方式を TypeScript に移植しエージェント名をサイドバーに表示するのは中規模改修。wmux の既存 `set-status` / sidebar との棲み分けを決定チケットで整理すべき。

---

## 3. エージェント間連携 API

### herdr の実装

- エージェント A が `agent.start()` で B を env 注入付きで spawn（`HERDR_PANE_ID`, `HERDR_SESSION` 等）
- `events.wait` サブスクリプションでタイムアウト付きに B の状態完了を待機
- `pane.report_agent()` / `pane.report_agent_session()` / `pane.report_metadata()` で状態を報告
- レイアウト参照: `pane.neighbor`, `pane.edges`, `layout.export` で spawn 先を動的選択
- **直接メッセージングなし**: ヘルダーの state/API を通じた間接連携
- 主要ファイル: `src/app/agents.rs`, `src/api/schema/agents.rs`

### wmux との差分

- wmux の名前付きパイプ API は agent spawn をサポート済み
- イベントサブスクリプション・セッション ref・レイアウトクエリ・regex 出力待機はなし

### 採用検討

**推奨: YES（高優先度）**。Phase 1: `events.subscribe` + フィルターを名前付きパイプに追加。Phase 2: `pane.wait_for_output`（regex + タイムアウト）。wmux-orchestrator の wave 実行を大幅に強化できる。

---

## 4. プラグインマーケットプレイス

### herdr の実装

`herdr-plugin.toml` マニフェスト:
- `id`, `name`, `version`, `min_herdr_version` で宣言
- `[[build]]`: プラットフォーム条件付きビルドコマンド
- `[[actions]]`: ユーザー起動, `[[events]]`: フック, `[[panes]]`: カスタム UI, `[[link_handlers]]`: URL パターン
- `herdr plugin install owner/repo[/subdir]` でクローン→プレビュー→ビルド→レジストリ登録
- トラストモデル: サンドボックスなし、ユーザー権限で実行
- 主要ファイル: `src/cli/plugin.rs`, `src/persist/plugin_registry.rs`

### wmux との差分

- wmux にはプラグインシステムなし。orchestrator は Claude Code プラグインとしてバンドル済み
- マニフェスト解析・アクションレジストリ・イベントフック・GitHub マーケットプレイス連携はなし

### 採用検討

**推奨: YES（低優先度、v0.8.0 以降）**。herdr の設計が実証済みで参照実装として使える。v1 はバンドル orchestrator で十分。

---

## 5. IPC アーキテクチャパターン

### herdr の実装

Unix ソケット / Windows 名前付きパイプ上の独自プロトコル:
- **フレーミング**: 4 バイト little-endian 長 + シリアライズメッセージ（最大 2 MB、グラフィクス 32 MB）
- **ハンドシェイク**: クライアントがプロトコルバージョン・エンコーディング・キーバインドを送信、サーバーが capabilities を返答
- **リクエスト/レスポンス**: JSON-RPC 的（id, method, params/result/error）
- **イベントサブスクリプション**: フィルター付きサブスクリプション、サーバーが非同期 EventEnvelope をプッシュ
- **多重化**: リクエスト ID で並行リクエスト管理
- **バージョニング**: プロトコルバージョン定数（現在 v16）、ハンドシェイクで交渉
- 主要ファイル: `src/ipc.rs`, `src/protocol/wire.rs`, `src/server/client_transport.rs`

### wmux との差分

| 側面 | herdr | wmux |
|---|---|---|
| フレーミング | 長さプレフィックス binary | 行区切り JSON |
| バージョニング | v16、交渉あり | なし |
| サブスクリプション | フィルター付き | なし |
| 多重化 | リクエスト ID | 単一同期 |
| タイムアウト | 明示的 | 暗黙 |

### 採用検討

**推奨: MAYBE（段階的）**。Phase 1: 既存プロトコルに `events.subscribe` を追加（#3 と連動）。Phase 2: バイナリフレーミングへの移行は将来の polish。

---

## その他の注目ポイント

1. **Worktrees** — Git ワークツリー対応ワークスペース（マルチリポジトリ作業に有用）
2. **Layout portability** — `layout.export` / `layout.apply` でワークスペーステンプレートの export/import
3. **Agent manifests hot-reload** — `~/.config/herdr/agent-detection/*.toml` でユーザー上書き
4. **Multi-window shared state** — 複数ローカルクライアント、1 サーバー、ワークスペース共有
5. **Integration system** — Claude Code / VS Code Remote / GitHub Actions 向けビルトインフック

---

## 採用優先度まとめ

| Tier | 対象 | チケット | ROI |
|---|---|---|---|
| 1（高） | エージェント間連携 API | T04 | 高：orchestrator 強化に直結 |
| 1（高） | セッション永続化 Phase 1 | T02 | 高：再起動後の resume |
| 2（中） | エージェント状態ダッシュボード | T03 | 中：UX 改善 |
| 2（中） | IPC プロトコルバージョニング | T06 | 中：将来互換 |
| 3（低） | プラグインマーケットプレイス | T05 | 低：v0.8.0 以降 |
