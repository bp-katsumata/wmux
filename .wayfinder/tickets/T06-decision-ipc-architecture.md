---
label: wayfinder:grilling
status: closed
assigned: agent
blocked-by: []
---

# T06 · 決定：IPC アーキテクチャパターン

## Question

herdr のソケット API 設計思想（agent が multiplexer と対話するプロトコル設計）を見て、wmux の名前付きパイプ IPC に取り入れるべき設計パターンがあるかを決める。

メッセージ型、エラー処理、双方向通信の設計などを提示しながら一緒に検討する。

---

## Resolution

**最小限のみ採用。**

T04（`wmux agent wait`）の実装に必要な変更のみ行う：

- **採用**: 長期接続 + サーバー push（result file 出現を監視し CLI に通知）
- **不採用**: プロトコルバージョン交渉、バイナリフレーミング、リクエスト多重化

既存の V2 プロトコル（行区切り JSON）はそのまま維持。`agent.wait` 専用の長期接続モードを追加するだけ。バージョニング等は現時点で解決すべき問題がないため見送り。
