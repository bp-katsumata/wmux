---
label: wayfinder:research
status: closed
assigned: agent
blocked-by: []
---

# T01 · herdr コードベースの精査

## Question

herdr のソースコードを深く読み込み、wmux への採用を検討する価値のある機能・設計パターンをすべて洗い出す。

各候補について：
- herdr での実装概要（どう動くか）
- wmux との差分（wmux には何があって何がないか）
- 採用検討対象として decision チケットを切るべきか

現時点で既知の候補（精査で追加・削除される可能性あり）：
1. セッション永続化（detach/reattach）
2. エージェント状態ダッシュボード（blocked/working/done）
3. エージェント間連携 API（agent が他 agent を待つ、pane を spawn する）
4. プラグインマーケットプレイス
5. IPC アーキテクチャパターン（ソケット API 設計思想）

---

## Resolution

herdr は Rust 製 AI エージェントオーケストレーション特化のターミナルマルチプレクサ（v0.7.3）。5 つの候補領域すべてを確認し、既存の T02–T06 チケットが妥当なスコープであることを確認した。

**各候補の採用推奨**:
- T02 セッション永続化 → YES（Phase 1: セッション ID 保存、Phase 2: ConPTY 調査）
- T03 エージェント状態ダッシュボード → MAYBE（設計会話で判断）
- T04 エージェント間連携 API → YES・高優先度（events.subscribe + 出力待機が orchestrator に直結）
- T05 プラグインマーケットプレイス → YES・低優先度（v0.8.0+）
- T06 IPC アーキテクチャ → MAYBE・段階的（Phase 1 は #4 と連動した events.subscribe のみ）

**追加観察**（既存チケット外）:
- Layout portability（export/apply ワークスペーステンプレート）— 新チケット候補
- Agent manifests hot-reload — T03 スコープ内
- Multi-window shared state / Integration system — 今回スコープ外

詳細レポート: `.wayfinder/assets/T01-herdr-research.md`
