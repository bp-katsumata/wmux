---
label: wayfinder:grilling
status: closed
assigned: agent
blocked-by: []
---

# T03 · 決定：エージェント状態ダッシュボード

## Question

herdr のマルチエージェント監視ダッシュボード（blocked/working/done リアルタイム表示）の設計を見て、wmux に取り入れるかを決める。

wmux の既存の `wmux set-status` / sidebar との差分を踏まえ、統一エージェントビューを追加するかを一緒に検討する。

---

## Resolution

**採用する。**

- **検出対象**: Claude Code 専用（汎用マニフェストは不採用）
- **検出方法**: main process が PTY 出力バッファの末尾を定期スキャン、パターンマッチ
- **状態**: Working（作業中）/ Blocked（入力待ち）/ Idle（待機中）
- **表示場所**: サイドバーのワークスペース行に状態ドットを追加

採用理由: orchestrator 外で直接起動した Claude Code ペインの状態（特に Blocked = 入力待ち）を複数ワークスペース俯瞰で一目確認したいニーズがある。

スコープ外: herdr 方式の汎用 TOML マニフェスト、Surface タブへのアイコン表示、Claude Code 以外のエージェント。
