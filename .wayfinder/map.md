---
label: wayfinder:map
status: closed
---

# herdr × wmux 比較：決定記録マップ

## Destination

herdr のコードベースを精査し、wmux に取り入れる価値のある機能・設計パターンを洗い出す。各項目について「herdr の設計を提示しながら一緒に判断する」会話を経て、**取り入れる / 取り入れない ＋ 理由** の決定記録を残す。

## Notes

- herdr: https://github.com/ogulcancelik/herdr (Rust + TUI、detach/reattach、ソケット IPC)
- wmux: Electron + React + TypeScript、Windows ターミナルマルチプレクサ、AI agent 支援特化
- 各 decision チケットは **grilling スタイル**（コスト試算なし、herdr 設計を見せながら一緒に判断）
- スキル: /grilling、/domain-modeling

## Decisions so far

- [T01 · herdr コードベースの精査](tickets/T01-research-herdr.md) — 5 候補すべて確認。T02–T06 のスコープは妥当。T04（エージェント間連携 API）が最高優先度。詳細: [レポート](assets/T01-herdr-research.md)
- [T04 · 決定：エージェント間連携 API](tickets/T04-decision-agent-coordination-api.md) — 採用。`wmux agent wait --id <agentId> --timeout <s>` を追加。push 型（result file watch）、タイムアウトは exit 1 のみ、kill 判断は orchestrator に委ねる。
- [T02 · 決定：セッション永続化（detach/reattach）](tickets/T02-decision-session-persistence.md) — 今は不採用。PTY デーモン分離（wmux-daemon.exe + ConPTY ハンドル受け渡し）が前提で大工事。Windows での実現可能性未検証。将来の検討項目として残す。
- [T03 · 決定：エージェント状態ダッシュボード](tickets/T03-decision-agent-dashboard.md) — 採用。Claude Code 専用。main process が PTY 末尾をスキャンして Working/Blocked/Idle を検出、サイドバーのワークスペース行に状態ドットとして表示。
- [T06 · 決定：IPC アーキテクチャパターン](tickets/T06-decision-ipc-architecture.md) — 最小限のみ採用。T04 の agent wait に必要な長期接続 + push のみ。バージョン交渉・バイナリフレーミング・多重化は不採用。
- [T05 · 決定：プラグインマーケットプレイス](tickets/T05-decision-plugin-marketplace.md) — 不採用。個人 fork で orchestrator 以外の拡張ニーズなし。

## Not yet specified

- **Layout portability**（`layout.export` / `layout.apply`）— ワークスペーステンプレートの export/import。herdr にあり、wmux にはない。T02–T06 の決定が一巡したあとに決定チケットを切るか判断する。

## Out of scope

- wmux の既存機能（browser pane、shell integration 等）の改修
- herdr を完全に模倣すること（TUI 化など）
- **Rust 化（一部ネイティブアドオン化を含む）** — ボトルネックは Claude 応答待ちであり、JS ランタイムではない。Electron ベースライン (~200MB) に対してメモリ削減効果も誤差範囲。現用途（個人、エージェント数十並列）では投資対効果が成立しない。
