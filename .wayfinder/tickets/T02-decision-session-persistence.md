---
label: wayfinder:grilling
status: closed
assigned: agent
blocked-by: []
---

# T02 · 決定：セッション永続化（detach/reattach）

## Question

herdr の detach/reattach セッション永続化の設計を見て、wmux に取り入れるかを決める。

wmux を閉じても PTY が生き続け、再起動後に再接続できる仕組みを導入するか？
その判断の根拠となる herdr の実装アプローチを提示しながら一緒に検討する。

---

## Resolution

**今は採用しない。将来の検討項目として残す。**

痛みはある（誤って閉じた / アップデート時に Claude の文脈と PTY プロセスが両方消える）。しかし：

- フル detach/reattach には **PTY デーモン分離**が前提（tmux と同じクライアント・サーバー構造）
- `wmux-daemon.exe` の常駐設計、ConPTY ハンドルのプロセス間受け渡し（`DuplicateHandle`）、自動起動・クラッシュ復旧まで必要
- Windows ConPTY での実現可能性が未検証であり、大工事に見合うかが不明
- Claude Code セッション復元だけでは「PTY なしでは目的達成できない」として不十分と判断

将来やるとしたら: `wmux-daemon.exe`（node-pty を内包した常駐プロセス）と GUI を名前付きパイプで分離する設計から始める。
