---
label: wayfinder:grilling
status: closed
assigned: agent
blocked-by: []
---

# T04 · 決定：エージェント間連携 API

## Question

herdr のエージェント間連携 API（agent が他 agent の完了を待つ、pane を自律 spawn する）の設計を見て、wmux に取り入れるかを決める。

wmux-orchestrator の wave 実行との重複・補完関係を踏まえながら一緒に検討する。

---

## Resolution

**採用する。**

`wmux agent wait --id <agentId> --timeout <seconds>` を名前付きパイプ API に追加する。

設計:
- **方式**: push 型 — pipe server が result file の出現を watch し、CLI クライアントに通知
- **完了の定義**: result file が出現した時点
- **タイムアウト時**: exit 1 を返すのみ。kill するかは orchestrator が判断（自動 kill なし）
- **単位**: 1 コマンド 1 agent。複数待機は bash の `&` + `wait` で組み合わせる
- **スコープ外**: 出力パターン待機（`wait_for_output`）、タイムアウト時自動 kill、複数 ID 一括

採用理由: orchestrator でのエージェント詰まり（無言停止）を検出できない実害があった。
現行の 15〜20 秒ポーリングを push + 明示的タイムアウトで置き換えることで解決する。
