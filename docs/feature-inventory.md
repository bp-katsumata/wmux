# wmux 機能一覧

**生成日**: 2026-07-11  
**ブランチ**: master  
**バージョン**: upstream v0.20.0 ベース + フォーク固有の追加機能

このドキュメントは wmux コードベースに実装されているすべての機能をカテゴリ別にまとめたものです。このフォーク (`bp-katsumata/wmux`) 固有の機能には **(fork)** タグを付けています。

---

## ウィンドウ管理

- **複数 OS ウィンドウ**: CLI (`wmux new-window`) またはキーボードショートカット (Ctrl+Shift+N) で追加の Electron ウィンドウを作成できる。各ウィンドウは独自のワークスペースセットを持つ。`WindowManager` (`src/main/window-manager.ts`) で管理。
- **CLI によるウィンドウフォーカス**: `wmux focus-window <id>` と `wmux list-windows` でマルチウィンドウ操作を CLI / エージェントに公開。
- **ウィンドウ位置の永続化**: 終了・起動時に `session-persistence.ts` が `bounds` と `maximized` フラグを記録し、同じモニター・サイズで再起動できる。
- **シングルインスタンスロック**: Electron の `requestSingleInstanceLock` で誤った二重起動を防ぐ。2 回目の起動は既存ウィンドウをフォーカスする。名前付きインスタンス (`WMUX_INSTANCE`) はそれぞれ独自のロックを保持するので dev と prod を共存させられる。
- **Windows AppUserModelId**: `com.wmux.app` に設定することでタスクバーピンが正しいアイコンを使用する。
- **MOTW（Mark of the Web）除去**: 起動時に、アプリディレクトリ内の `.exe` / `.dll` / `.node` ファイルから `Zone.Identifier` ADS を削除し、セキュリティ警告とタスクバーピン失敗を解消する。
- **Webview / ナビゲーション強化**: アタッチされた Webview から `nodeIntegration` を除去し、`window.open` を OS ブラウザにルーティング。メインレンダラーが自身のオリジンから離れるナビゲーションをブロック。

---

## ワークスペース管理

- **作成 / 削除 / 選択 / リネーム**: IPC と CLI (`wmux new-workspace`, `wmux close-workspace`, `wmux select-workspace`, `wmux rename-workspace`) で公開されるコア操作。
- **デフォルト 3 ペインレイアウト**: 新ワークスペースはデフォルトで 上 2 ＋ 下 1 のターミナルスプリット (`App.tsx` の `buildDefaultSplitTree` で構築)。
- **ワークスペースカスタムカラー**: コンテキストメニューまたは `WorkspaceInfo.customColor` で各ワークスペースに色を設定できる。アクティブ行はその色を背景に、非アクティブ行は 5% 透明度のティントで表示。
- **ワークスペースのピン留め**: 並び替えを抑制するピン留めが可能。Ctrl+Alt+P またはコンテキストメニューで切り替え。
- **ワークスペースの並び替え**: サイドバーでのドラッグ＆ドロップ、またはコンテキストメニューの上へ / 下へ / 先頭へ操作。`workspace:reorder` IPC チャンネル。
- **別ウィンドウへのワークスペース移動**: `workspace:moveToWindow` IPC チャンネルでワークスペースを別 OS ウィンドウに移動。
- **ワークスペースコンテキストメニュー**: ワークスペース行を右クリックで: ピン留め / 解除、リネーム、カラー設定 / 削除、上へ / 下へ / 先頭へ移動、ワークスペースを閉じる、他を閉じる、既読 / 未読マーク。
- **新ワークスペースの挿入位置設定**: `afterCurrent`（現在の次）、`top`（先頭）、`end`（末尾）から選択 (`WorkspacePrefs.newWorkspacePlacement`)。
- **通知時の自動並び替え**: 通知を受け取ったワークスペースを先頭に浮上させるオプション設定。
- **フォルダーをワークスペースとして開く**: Ctrl+O でネイティブフォルダーピッカーを開き、選択したフォルダーを cwd とする新ワークスペースを作成。
- **SSH ワークスペース** **(fork)**: `wmux ssh [ssh オプション] <user@host> [--title T]` で、指定ホストに接続する OpenSSH プロセスをシェルとした新ワークスペースを開く。wmux 以外のフラグはすべて ssh にそのまま渡される。

---

## ペイン / サーフェス管理

### スプリットツリー

- **水平・垂直ペインスプリット**: `wmux split`（右）と `wmux split --down`（下）。Ctrl+D / Ctrl+Shift+D でも操作可能。スプリットは `split-utils.ts` が管理する不変のバイナリツリー (`SplitNode`) を生成する。
- **ブラウザペインスプリット**: `wmux split --type browser`（または Ctrl+Alt+D）で新ペインにブラウザサーフェスを開く。
- **ペインフォーカス（方向ナビゲーション）**: Ctrl+Alt+Arrow キーで、`useKeyboardShortcuts.ts` の分数矩形を使って最も近い方向のペインに移動。
- **キーボードによるペインリサイズ**: Ctrl+Shift+Arrow でフォーカス中のペインに隣接するスプリット分割比を ±5% 調整。
- **ドラッグ可能なスプリット区切り**: `SplitDivider` のマウスドラッグで `SplitNode.ratio` を更新。
- **ペインズーム** (`toggleZoom`): Ctrl+Shift+Enter でフォーカス中のペインを最大化。再度押すと元に戻る。`App.tsx` の `zoomedPaneId` で実装。
- **ペイン / サーフェスのクローズ**: Ctrl+W でアクティブサーフェスを閉じる。そのペインの最後のサーフェスだった場合はペイン自体も削除。最後の 1 ペインは削除されないよう保護。
- **レイアウトグリッド** **(fork)**: `wmux layout grid --count N [--type T] [--anchor-surface|--anchor-pane]` でアンカー周囲に N ペインをグリッド配置。アンカーが指定されない場合は現在シェルのサーフェスを使用。

### サーフェス（ペイン内のタブ）

- **ターミナルサーフェス**: xterm.js バックエンドの PTY サーフェス。
- **ブラウザサーフェス**: アプリ内ブラウジング用 `<webview>` サーフェス。`surface.type = 'browser'`。
- **Markdown サーフェス**: レンダリングされた Markdown ビューア。`surface.type = 'markdown'`。Ctrl+Shift+M または `wmux markdown <file>` で作成。
- **Diff サーフェス**: Git diff / スナップショット diff ビューア。`surface.type = 'diff'`。Ctrl+Shift+G または Claude Code がファイルを編集したときに自動表示。
- **サーフェスタブバー**: 各ペインにはすべてのサーフェスを表示するタブバーがある。タブにはサーフェス種別、カスタムタイトル（Ctrl+F2 で編集可）、シェル状態インジケーターが表示される。
- **サーフェス追加（新しいタブ）**: Ctrl+T でフォーカス中のペインに新しいターミナルタブを開く。クイック起動ドロップダウンでタブ種別を選択可能。
- **次 / 前のタブ**: Ctrl+Shift+] / Ctrl+Shift+[。Ctrl+Alt+1〜9 でインデックス直接ジャンプも可能。
- **サーフェスのクローズ**: Ctrl+W。最後のサーフェスを閉じるとペインも削除。
- **閉じたサーフェスの再表示**: Ctrl+Shift+T でフォーカス中のペインの最近閉じたサーフェスを復元。
- **サーフェスごとのカラースキームオーバーライド**: 各ターミナルタブに独自のカラースキームを設定可能 (`SurfaceRef.colorScheme`)。`wmux set-color-scheme [surfaceId] <scheme>` または `wmux new-surface --color-scheme NAME` で設定。
- **サーフェスのドラッグ＆ドロップ**: タブをペイン間でドラッグして移動、または空エリアにドロップしてスプリットできる。ドロップ前にライブプレビューオーバーレイ (`SplitPreviewOverlay`) でレイアウトを確認。Escape でキャンセル。
- **サーフェスのリネーム**: Ctrl+F2 でアクティブタブのインラインリネームモードに入る。
- **クイック起動プロファイル**: タブバーの `+` カレットを展開するとユーザー定義プロファイルのドロップダウンが表示される（設定でグローバルに、または `.wmux.json` でプロジェクト単位に定義）。各プロファイルではタブ種別、シェル、cwd、スタートアップコマンド、初期 URL を設定可能。
- **Keep-alive タブ**: ペイン内のすべてのサーフェスは同時にマウントされており、タブ切り替えは CSS の `visibility` のみ変更するため、PTY は再接続なしで維持される。

---

## ターミナル

### PTY

- **node-pty 統合**: ConPTY の再描画バグを回避するため、`useConpty: true` + バンドルされた `conpty.dll` (`useConptyDll: true`) を使用して `pty.spawn` を実行。
- **シェル検出とフォールバック**: Windows では `pwsh.exe` → `powershell.exe` → `cmd.exe`、Unix では `$SHELL` → `/bin/sh` の順に試みる。指定されたシェルが見つからない場合は警告を出してフォールバック。
- **シェルスペックの解析**: `"ssh user@host"` や `'"C:\path\shell.exe" --flag'` のようなシェルスペックを実行ファイルと引数に分割してスポーン。
- **WSL シェルサポート** **(fork)**: `wsl.exe` がシェル種別として検出される。`WSLENV` 経由で WMUX_* 環境変数を WSL ディストロに伝播させ、WSL 内からも `wmux` CLI、通知、サイドバーが機能する。`ZDOTDIR` シムが統合スクリプトを自動ソースする。POSIX の cwd（例: `/home/user`）は Win32 の cwd の代わりに `--cd` で渡される。
- **DA1（Device Attributes）応答**: oh-my-posh / PSReadLine からの `\x1b[c` クエリをメインプロセスでインターセプトしてプロセス内で即座に返答。レンダラーのラウンドトリップで発生していたプロンプト遅延やエスケープ文字混入を解消。
- **分割貼り付け**: ConPTY の入力パイプドロップを防ぐため、大きな書き込みを 1 KB チャンクに分割して `setImmediate` を挟みながら送信。短いキーストロークはキューをバイパスしてゼロレイテンシーで処理。
- **冪等 PTY 作成**: `create()` は `surfaceId` ごとに冪等。2 回目の呼び出し（React StrictMode のダブルマウント等）では新規スポーンせず既存 PTY を再利用。
- **クローズ時のプロセスツリー終了**: Windows では `taskkill /PID /T /F` でプロセスツリー全体を走査してから `pty.kill()` を呼び出し、Claude Code の `-s` バックエンドが孤立しないようにする。
- **PTY ID = サーフェス ID**: `surfaceId` を PTY のキーとして渡すことでサーフェスと PTY のマッピングを決定論的にし、セッションの再アタッチを確実にする。
- **シェル初期化へのスタートアップコマンド埋め込み** **(fork)**: クイック起動の `startupCommands` を `WMUX_STARTUP_COMMANDS` 経由で PowerShell 統合スクリプトに渡し、最初のプロンプトより前に実行する。DA1 クエリとの競合により発生していた `62;4;9;22ccls` スタイルの行の乱れを解消。
- **True-color アドバタイズ**: すべてのスポーンシェルの環境に `COLORTERM=truecolor` を設定し、Claude Code やツールが 24 ビットカラーで diff をレンダリングできるようにする。

### ターミナル UI

- **xterm.js レンダラー**: `xterm-256color` terminfo を使ったキャンバスベースのレンダラー。スクロールバックは設定可能（デフォルト 5000 行）。
- **検索バー**: Ctrl+F で xterm の `SearchAddon` を使ったインペイン検索バーを表示。F3 / Shift+F3 で次 / 前のマッチへ。Escape で閉じる。
- **コピーモード**: Ctrl+Alt+[ でコピーモードに入る。矢印キーでカーソル移動、Shift+矢印でテキスト選択、Enter でクリップボードにコピー、Escape で終了。
- **コピー / ペースト**: Ctrl+Shift+C で選択テキストをコピー、Ctrl+Shift+V で Electron クリップボード API 経由でペースト（Windows の非 UTF-8 形式での文字化けを回避）。
- **フォントサイズ調整**: Ctrl+= （拡大）、Ctrl+- （縮小）、Ctrl+0（13px にリセット）。
- **通知リングアニメーション**: フォーカス外のペインが新しい通知を受け取った際、ペインのボーダーに視覚的なリングアニメーションが再生される。
- **フラッシュエフェクト**: `wmux trigger-flash` または Ctrl+Alt+F でフォーカス中のペインに視覚的なフラッシュを発生させる（エージェントが注意を引く用途）。
- **ブロードキャスト入力モード** **(fork)**: Ctrl+Alt+B で「ブロードキャスト入力」を切り替え。すべてのキーストロークと Enter がアクティブワークスペースのすべてのターミナルペインに一斉送信される。有効中はバナーが表示される。再起動後は維持されない。
- **ショートカットチートシートオーバーレイ** **(fork)**: F1 で設定されているすべてのキーボードショートカットを一覧するフルスクリーンオーバーレイを切り替え。

---

## ブラウザ / CDP

- **組み込みブラウザパネル**: ワークスペースごとに `<webview>` を持つリサイズ可能な右サイドパネル。ワークスペース切り替え時に URL 状態を保持。パネル幅もワークスペースごとに永続化。
- **起動時の自動表示**: 設定 (`BrowserPrefs.openOnStartup`) で無効にしない限り、起動時にブラウザパネルが自動表示される。
- **アドレスバー**: Google、DuckDuckGo、Bing、Brave の検索エンジンフォールバック付き URL 入力。ブラウザ設定で構成可能。
- **デベロッパーツール切り替え**: Ctrl+Shift+J または Ctrl+F12 で組み込みブラウザの Chrome DevTools を表示。
- **CDP ブリッジ** (`src/main/cdp-bridge.ts`): ブラウザの webContents に Chromium DevTools Protocol をアタッチ。CLI / エージェントからブラウザを自動操作するために使用。
- **CDP プロキシ** (`src/main/cdp-proxy.ts`): `localhost:9222` に CDP JSON/WS エンドポイントを公開し、外部ツール（`chrome-devtools-mcp` 等）が wmux の組み込みブラウザに接続できるようにする。
- **呼び出し元ごとのブラウザ分離** **(fork)**: 各エージェント / サーフェスが `webContents.id` をキーとする独自の `CDPTarget` を持つ。`caller` サーフェス ID が `browser.*` パイプ呼び出しに自動アタッチされるため、並行エージェントがブラウザセッションを干渉しない。
- **CLI ブラウザコマンド**: `wmux browser open <url>`, `snapshot`, `click @eN`, `type @eN <text>`, `fill @eN <value>`, `get-text`, `screenshot [--full]`, `eval <js>`, `wait`, `back`, `forward`, `reload`。
- **アクセシビリティスナップショット**: `wmux browser snapshot` はラベル付きアクセシビリティツリー（`@e1`, `@e2`, …）を返す。フルスクリーンショットの解析なしでエージェントが操作可能。
- **chrome-devtools-mcp 自動設定** **(fork)**: 起動時に Claude Code の `chrome-devtools-mcp` プラグイン（独自の Chrome を起動する）を無効化し、`localhost:9222` を指すカスタム MCP サーバーを注入することで、Claude Code のブラウザツールが wmux の組み込みブラウザを使うようにする。
- **検出された開発ポートへの自動ナビゲーション**: ポートスキャナーが新しい開発サーバーポート（3000, 8080 等）を検出すると、ブラウザパネルが自動的にそのポートにナビゲートする。

---

## エージェント管理

- **エージェントスポーン**: `wmux agent spawn --cmd <cmd> [--label L] [--cwd D] [--pane P] [--workspace W]` で指定ペイン内の新 PTY サーフェスにサブプロセスをスポーン。`cmd` または `prompt` フィールド名を受け付ける。`AgentManager` (`src/main/agent-manager.ts`) で管理。
- **バッチエージェントスポーン**: `wmux agent spawn-batch --json '[…]' [--strategy distribute|stack]`。`distribute` は負荷に応じてラウンドロビン、`stack` は最も負荷の低いペインに集約。
- **エージェントステータス / 一覧 / 終了**: `wmux agent status <id>`、`wmux agent list [--workspace W]`、`wmux agent kill <id>`。
- **エージェント PTY 転送**: エージェントの PTY データがレンダラーウィンドウに転送されてターミナルサーフェスにライブ出力が表示される。
- **パイプ経由のエージェント活動追跡**: `wmux agent-activity --surface <id> [--tool T] [--skill S] [--done|--active]` で外部ツール（OpenCode プラグイン等）がサイドバーの活動状態を更新できる。

---

## シェルインテグレーション

- **PowerShell インテグレーション** (`resources/shell-integration/wmux-powershell-integration.ps1`): PTY 作成時に自動ソース。報告内容: `report_pwd`、`report_git_branch`（+ dirty フラグ）、`report_shell_state`（idle / running / interrupted）、PR ポーリング（`gh pr view` を 45 秒ごと）。UTF-8 I/O を設定。`wmux` シェル関数を定義。`WMUX_STARTUP_COMMANDS` によるスタートアップコマンドをサポート。
- **Bash インテグレーション** (`resources/shell-integration/wmux-bash-integration.sh`): cwd、git ブランチ、シェル状態を報告。OSC 9 タイトルシーケンスを設定。
- **CMD インテグレーション** (`resources/shell-integration/wmux-cmd-integration.cmd`): 基本的な OSC 9 エスケープシーケンス。
- **WSL / zsh 向け ZDOTDIR シム** **(fork)**: `resources/shell-integration/zdotdir/` に `.zshrc` があり、先に `$HOME/.zshenv` / `.zshrc` をソースしてから wmux bash インテグレーションを注入する。ユーザーのドットファイルを変更せずにインテグレーションを注入できる。
- **環境変数の注入**: wmux がスポーンするすべてのシェルに以下を設定: `WMUX=1`、`WMUX_SURFACE_ID`、`WMUX_PIPE`、`WMUX_PIPE_TOKEN`、`WMUX_CLI`、`COLORTERM=truecolor`。`cli-bin` シムディレクトリを `PATH` の先頭に追加し、すべての子プロセス（Claude Code の Bash ツールを含む）から `wmux` コマンドを解決できるようにする。
- **シェル状態通知**: フォアグラウンドコマンドが 5 秒以上かかって完了（または中断）した場合に通知を発火: "Finished in <ワークスペース> (Xs)" または "Interrupted in <ワークスペース> (Xs)"。
- **PR ステータスポーリング**: シェルインテグレーションが `gh pr view` で現在のブランチの PR 番号 / 状態 / タイトルを報告。メインプロセス (`PrPoller`) が 45 秒ごとにポーリング。
- **Git ブランチ / dirty 監視**: `GitPoller` が `.git/HEAD` を監視してブランチ変更を検出し、`git status --porcelain` で dirty 状態をポーリング。
- **ポートスキャン**: `PortScanner` が `netstat -ano` の出力を解析して 1024 超のリスニングポートを検出。結果はすべてのワークスペースに送信され、開発ポートはブラウザパネルの自動ナビゲーションに使用される。

---

## 通知

- **アプリ内通知ベル**: タイトルバーのベルアイコンに未読数を表示。クリックするとワークスペース / サーフェス / タイムスタンプ付きの通知パネルを開く。
- **ワークスペース行の未読バッジ**: サイドバーのワークスペース行にワークスペースごとの未読通知数バッジを表示。
- **通知へのジャンプ**: 通知パネルで通知をクリックすると発生元のワークスペース + ペイン + タブに切り替わる。
- **OS トースト通知**: `window.wmux.notification.fire` が Electron 経由でネイティブ Windows トーストを送信。
- **タスクバーフラッシュ**: 通知発火時に任意でタスクバーをフラッシュ。
- **ペインリングアニメーション**: フォーカス外のペインへの通知発火時に、ペインのボーダーにリングアニメーションが再生される。
- **ペインフラッシュアニメーション**: 通知時の CSS フラッシュアニメーション（任意）。
- **通知サウンド**: `notification.wav`（またはチャイム、ピン、マリンバ、ポップ、なし）を再生。
- **Claude Code エージェント通知** **(fork)**: `Notification` Claude Code フックでエージェントが入力 / 許可を必要とするときに wmux 通知を発火。`Stop` フックでエージェントのターン終了時に通知。それぞれ設定で独立してオフにできる。
- **ワークスペース既読マーク**: Ctrl+Alt+R でアクティブワークスペースのすべてのサーフェスを既読にする。
- **最初の未読へのジャンプ**: Ctrl+Shift+U で最初の未読通知があるワークスペース / ペイン / タブに切り替わる。
- **CLI 通知**: `wmux notify <text>` で任意のターミナルから通知を発火（ペイン外からでも動作し、アクティブワークスペースにフォールバック）。

---

## キーボードショートカット

すべてのショートカットはユーザーが設定可能（設定 → ショートカット）。変更内容は `~/.wmux/config.toml` の `[shortcuts]` に書き込まれる。`KeyboardSettings.tsx` のショートカットレコーダーがリアルタイムでキーバインドをキャプチャ。変更はグローバルリセットなしで個別のデフォルトを上書きする。

デフォルトバインド（主要なもの）:

| アクション | デフォルト | 備考 |
|-----------|-----------|------|
| 新規ワークスペース | Ctrl+N | |
| 新規ウィンドウ | Ctrl+Shift+N | |
| ワークスペースを閉じる | Ctrl+Shift+W | |
| サイドバー切り替え | Ctrl+B | |
| 次 / 前のワークスペース | Ctrl+PageDown/Up | |
| ワークスペース 1〜9 | Ctrl+1〜9 | 固定、変更不可 |
| サーフェス 1〜9 | Ctrl+Alt+1〜9 | 固定、変更不可 |
| 右 / 下にスプリット | Ctrl+D / Ctrl+Shift+D | |
| ブラウザを右 / 下にスプリット | Ctrl+Alt+D / Ctrl+Alt+Shift+D | |
| ズーム切り替え | Ctrl+Shift+Enter | |
| ペインフォーカス（方向） | Ctrl+Alt+Arrow | |
| ペインリサイズ | Ctrl+Shift+Arrow | ±5% |
| 新しいタブ | Ctrl+T | |
| 閉じたタブを再表示 | Ctrl+Shift+T | |
| 次 / 前のタブ | Ctrl+Shift+] / [ | |
| タブ / ペインを閉じる | Ctrl+W | |
| 検索 | Ctrl+F | |
| 次 / 前の検索結果 | F3 / Shift+F3 | |
| コピーモード | Ctrl+Alt+[ | |
| コピー | Ctrl+Shift+C | |
| ペースト | Ctrl+Shift+V | |
| フォントサイズ +/−/リセット | Ctrl+= / Ctrl+- / Ctrl+0 | |
| ブラウザを開く | Ctrl+Shift+I | |
| ブラウザ DevTools | Ctrl+F12 | |
| 設定を開く | Ctrl+, | |
| コマンドパレット | Ctrl+Shift+P | |
| Markdown パネルを開く | Ctrl+Shift+M | |
| Diff パネルを開く | Ctrl+Shift+G | |
| 通知を表示 | Ctrl+Alt+N | |
| 最初の未読へジャンプ | Ctrl+Shift+U | |
| ブロードキャスト入力 | Ctrl+Alt+B | |
| ワークスペースをピン留め | Ctrl+Alt+P | |
| ワークスペースを既読に | Ctrl+Alt+R | |
| ショートカットチートシート | F1 | |

**2 層のショートカットインターセプト**: `useTerminal.ts` がバインドされているショートカットの `attachCustomKeyEventHandler` から `false` を返す（ストアをリファレンス経由で読み取り、ターミナルエフェクトを再生成しない）。`useKeyboardShortcuts.ts` がアクションを処理。コピー / ペーストと検索 / コピーモードは専用のパスを持つ。

---

## サイドバー

- **ワークスペース一覧**: ワークスペース行の縦リスト。各行にタイトル、状態ドット、ステータステキスト、PR 情報、git ブランチ / cwd コンテキスト行を表示。
- **状態ドット**: Claude がツールを積極的に使用中はパルスアニメーション付きドット。idle / running / interrupted のシェル状態は静的な色で表示。
- **ステータステキストの優先順位**: (1) Claude ツールラベル（オブザーバーまたはフック由来）、(2) Claude 停止後もシェルが実行中なら "Idle"、(3) シェル状態テキスト、(4) 通知テキスト、(5) "Idle"。
- **Claude ツールラベル**: 生のツール名（Bash, Read, Edit, Write, Grep, Glob, Agent, WebSearch, WebFetch, Skill, MCP）を人間が読みやすい文字列（"コマンドを実行中…"、"編集中…" 等）に変換。
- **エージェント活動表示**: `ClaudeActivity.agents` のサブエージェント一覧をワークスペース行にインライン表示。エージェントごとのツール数とトークン数を表示。
- **アクティブスキル表示**: 現在ロードされている Claude Code スキル名を行に表示。
- **PR ステータス**: PR 番号、open / merged / closed アイコン、タイトルをワークスペースごとに表示（`PrPoller` がポーリング）。
- **git コンテキスト行**: 利用可能な場合は `branch[*] · ~/path` をステータスの下に表示。
- **未読バッジ**: ワークスペース行に未読通知の数値バッジを表示。
- **リサイズ可能なサイドバー**: 右端をドラッグしてリサイズ。80px 未満にドラッグすると自動折りたたみ。
- **折りたたみ可能なサイドバー**: Ctrl+B または折りたたみボタンをクリック。左の細いストリップをクリックまたはドラッグで再展開。
- **サイドバー不透明度設定**: `SidebarPrefs.backgroundOpacity`（0〜100%）。
- **アクティブタブインジケータースタイル**: 左レールストライプまたはソリッド塗りつぶしを選択。
- **詳細すべて非表示モード**: `SidebarPrefs.hideAllDetails` でワークスペース名以外のすべての詳細を折りたたむ。
- **オーケストレーションパネル** **(fork)**: `OrchestrationPanel.tsx` がワークスペース一覧の上に進行中の wmux-orchestrator 実行をレンダリング。実行 ID、全体ステータス、ウェーブごとのステータス、エージェントごとのステータス（pending / running / exited / failed）と終了コードを表示。
- **セッション保存 / 読み込みボタン**: フッターボタンでサイドバーから離れることなくインラインテキスト入力（保存）または `SessionMenu`（読み込み）を表示。

---

## セッション管理

- **ローリング自動保存**: メインプロセスが 30 秒ごと（および終了時）に `session:request` IPC を送信。レンダラーが現在のワークスペースレイアウト、cwd、シェル、スプリットツリー、ブラウザ URL、サイドバー幅を `%APPDATA%\wmux\sessions\session.json` に永続化。アトミックな一時ファイルリネームを使用。
- **起動時の自動復元**: 起動時にレンダラーが自動保存セッションの読み込みを試み、失敗した場合は最新の名前付きセッション、それも失敗した場合はデフォルトの新規状態にフォールバック。
- **ウィンドウ位置の永続化**: bounds と最大化フラグはメインプロセスから自動保存にシリアライズされる（レンダラーはウィンドウ bounds を直接読めないため）。
- **名前付きセッション（保存 / 読み込み / 削除 / 一覧）**: `%APPDATA%\wmux\sessions\saved\<name>.json` に保存。アプリ更新後も保持される（ローリング自動保存のみバージョン変更時に削除）。名前付きセッションにはターミナル設定（フォント、テーマ、カラースキーム）も含まれる。
- **バージョン変更時の処理**: アップグレード後の初回起動時にローリング自動保存を削除してクリーンスタート。名前付きセッションと最終セッションポインターは維持。
- **最終セッションポインター**: `last-session.txt` が最後に保存した名前付きセッションを記録し、コールドスタート時にユーザー入力なしで復元できるようにする。
- **CWD 復元** **(fork)**: ワークスペースの `cwd` が自動保存に含まれるため、新しいターミナルが最後の作業ディレクトリで開く。

---

## 設定 / 構成

### アプリ内設定 UI

Ctrl+, で開くマルチタブ設定ウィンドウ:

- **一般**: UI 言語セレクター（English / Français / 中文）、アプリテーマ（ダーク / ライト / システムに合わせる）。
- **サイドバー**: git ブランチ、作業ディレクトリ、PR、ポート、通知テキストの表示切り替え、詳細すべて非表示モード、アクティブタブインジケータースタイル、背景不透明度。
- **ワークスペース**: 新ワークスペースの挿入位置、通知時の自動並び替え、デフォルトシェル、ファイル編集時の diff タブ自動表示、ウェルカム画面の切り替え。
- **ターミナル**: フォントファミリー、フォントサイズ、テーマ（バンドルテーマ + ユーザー定義）、カーソルスタイル（ブロック / アンダーライン / バー）、カーソル点滅、スクロールバック行数、ユーザー定義カラースキームエディター。
- **通知**: トースト、タスクバーフラッシュ、ペインリング、ペインフラッシュアニメーション、サウンド、エージェント入力通知、エージェント停止通知。
- **ブラウザ**: デフォルト検索エンジン（Google / DuckDuckGo / Bing / Brave）、DevTools アイコンスタイル、起動時に開く。
- **プロファイル**: クイック起動プロファイルエディター（名前、アイコン、タブ種別、シェル、cwd、スタートアップコマンド、初期 URL）。
- **ショートカット**: リマップ可能なショートカット一覧と `ShortcutRecorder` によるライブ再バインド。`config.toml` から読み込まれたバインドにはバッジを表示。リセットボタン。
- **ヘルプ**: バージョン情報、バージョン番号、イシューリンク、ウェブサイトリンク。

### ファイルベースの設定 (`~/.wmux/config.toml`)

TOML 形式。外部エディターからの変更を監視（150ms デバウンス）。サポート内容:

- `[terminal]`: `font-family`、`font-size`、`cursor-style`、`cursor-blink`、`scrollback-lines`
- `[terminal.colors]`: `default` テーマ名、`[terminal.colors.schemes.<name>]` ユーザーカラースキーム
- `[appearance]`: `ui-theme = "light" | "dark" | "system"`
- `[shortcuts]`: アクションごとのショートカット文字列（`Ctrl+D` 等）

起動時に適用（ファイルが永続化設定より優先）。`wmux reload-config` でランタイム中に再適用。設定の変更は `[shortcuts]` に書き戻される。

### 設定の永続化

設定はプリロードの同期 IPC `settings.getAllSync()` / `settings.set()` ブリッジ経由で `%APPDATA%\wmux\settings.json` に保存される。これによりアプリ更新後も設定が維持される（`localStorage` はアプリパスにスコープされるため、バージョンアップごとにリセットされていた）。

---

## テーマ

- **バンドルテーマ**: `resources/themes/` に 30 以上の Ghostty 形式 `.theme` ファイル: Ayu Dark/Light/Mirage、Catppuccin Mocha、Cobalt 2、Dev Green、Dracula、Everforest Dark、GitHub Dark/Light、Gruvbox Dark、Horizon、Kanagawa、Material Dark、Monokai Pro、Night Owl、Nightfly、Nord、Oceanic Next、One Dark、Palenight、Prod Red、Rose Pine、Solarized Dark/Light、Staging Amber、SynthWave 84、Tokyo Night、Zenburn。
- **デフォルトビルトインテーマ**: Monokai（`theme-loader.ts` にハードコードされたフォールバック）。
- **Ghostty テーマ形式パーサー**: `parseThemeFileContent` が複数エントリーの `palette = N=color` 行を含む `key = value` ペアを読み込む。
- **Windows Terminal テーマインポート**: `CONFIG_IMPORT_WT` IPC チャンネルで Windows Terminal の `settings.json` からカラースキームをインポート。
- **Ghostty テーマインポート**: `CONFIG_IMPORT_GHOSTTY` IPC チャンネルで Ghostty の設定からテーマをインポート。
- **ユーザー定義カラースキーム**: `config.toml` の `[terminal.colors.schemes.<name>]` または設定 UI で定義。部分的なオーバーライドが可能（指定したフィールドのみベーステーマを置換）。
- **サーフェスごとのカラースキームオーバーライド**: 各ターミナルタブがワークスペースのデフォルトとは独立した独自のカラースキームを持てる。
- **アプリ UI テーマ** **(fork)**: サイドバー、タブバー、タイトルバー、ペインクローム（ターミナルカラーは除く）へのダーク / ライト / システムに合わせるモードの適用。"system" 設定時は `nativeTheme` をリアルタイムに追従。

---

## Diff ビューア

- **Diff サーフェス**: `DiffPane` コンポーネント (`src/renderer/components/Diff/DiffPane.tsx`) が git diff またはスナップショット diff をペインタブにインラインレンダリング。
- **エージェントのファイル編集時に自動表示** **(fork)**: Claude Code が `Edit` または `Write` フックイベントを発火すると、wmux が最下部ペインに diff タブを自動作成（既に存在する場合は作成しない）。設定でオフにできる。
- **Git diff バックエンド**: `diff-provider.ts` が `git diff HEAD`、`git diff`、`git diff --cached` を順に実行。追跡外ファイルには合成 `+<line>` diff を生成。
- **スナップショット diff フォールバック**: git 以外のディレクトリでは、`diff-provider.ts` が初回呼び出し時にサポート対象ファイルタイプのインメモリスナップショットを取り、2 回目以降の呼び出しで unified diff を計算。
- **CLI トリガー**: `wmux diff [--file <path>]` が `DIFF_UPDATE` IPC を送信して diff ビューアを更新。
- **段階的リフレッシュ**: `Edit` / `Write` フックイベント後、diff の更新は 500ms と 2000ms の 2 段階で発火し、遅い書き込みに対応。

---

## Markdown ビューア

- **Markdown サーフェス**: `MarkdownPane` がペインタブ内でフル機能のレンダラーを使用して Markdown コンテンツをレンダリング。
- **CLI からの表示**: `wmux markdown <file>` で新しい Markdown サーフェスを作成してファイルを読み込む。`wmux markdown set <id> --content <text>` でプログラム的にコンテンツを設定、`wmux markdown set <id> --file <path>` でファイルから読み込み。
- **ファイル種別ガード**: `markdown.load_file` は `.md`、`.markdown`、`.mdx`、`.txt`、`.text`、`.rst` のみ（5 MB 以下）を受け付ける。
- **コンテンツの永続化**: `SurfaceRef.markdownContent` がスプリットツリーにシリアライズされるため、ペイン再構成でコンポーネントが再マウントされても Markdown コンテンツが維持される。
- **ファイルピッカー**: Ctrl+Shift+M でネイティブフォルダー / ファイルピッカーを表示 (`MARKDOWN_OPEN_FILE` IPC)。

---

## オーケストレーションプラグイン (wmux-orchestrator)

- **起動時の自動インストール**: `ensureOrchestratorPlugin()` が `resources/wmux-orchestrator/` を `~/.claude/plugins/cache/wmux-orchestrator/<version>/` にコピーし、`installed_plugins.json` に登録して `settings.json` で有効化。バージョンチェックにより再インストールをスキップ。
- **Claude Code プラグインフック**: `hooks.json` が登録するフック: `PostToolUse`（Bash/Read/Write/Edit/Grep/Glob/Agent）、`SubagentStop`、`Stop`、`SessionStart`。
- **オーケストレーション状態ファイル**: プラグインが `{TMPDIR}/wmux-orch-*/state.json` に実行状態を書き込む。型付き構造: `OrchestrationState` → `OrchestrationWave[]` → `OrchestrationAgent[]`。
- **オーケストレーションウォッチャー** **(fork)**: `orchestration-watcher.ts` が 1 秒ごとに `os.tmpdir()` の `wmux-orch-*` ディレクトリをポーリング。最も注目すべき実行（実行中 > 最近完了）を `ORCHESTRATION_UPDATE` IPC でブロードキャスト。完了した実行は 30 秒後に消える。
- **オーケストレーションサイドバーパネル** **(fork)**: `OrchestrationPanel.tsx` がサイドバーのワークスペース一覧の上にレンダリング。表示内容: タスク名、全体ステータス、ウェーブインデックス / ステータス、エージェントごとのラベル / ステータス / 終了コード / ツール数。
- **wmux 検出スクリプト**: `scripts/detect-wmux.sh` が名前付きパイプに ping し、失敗した場合はパイプパスを直接確認。PATH にない場合でも `wmux-resolve.sh` で CLI を探す。
- **エージェント停止スクリプト**: `scripts/on-agent-stop.sh` がサブエージェント停止時に発火してウェーブ状態を遷移させる。
- **セッション開始スクリプト**: `scripts/on-session-start.sh` が Claude Code セッション開始時に実行され、サーフェス / ワークスペースをオーケストレーション状態に登録する。

---

## Claude Code インテグレーション

- **CLAUDE.md 注入**: `ensureClaudeContext()` が wmux リファレンスブロックを `~/.claude/CLAUDE.md` に書き込む（`<!-- wmux:start -->` / `<!-- wmux:end -->` マーカーで区切り）。冪等: ブロックが古い場合は更新し、マーカー外のコンテンツには一切触れない。
- **フック自動登録** **(fork)**: `ensureClaudeHooks()` が `~/.claude/settings.json` を変更して Bash/Read/Write/Edit/Grep/Glob/Agent/WebSearch/WebFetch/Skill の `PostToolUse` フックと `Notification`、`Stop` フックを追加。各フック配列の wmux 以外のエントリーはすべて保持。
- **PTY 出力オブザーバー** **(fork)**: `claude-observer.ts` が Claude Code のターミナル出力ストリームを解析: エージェントバッチの開始 / 詳細 / 完了、スキルの読み込み、ツール使用（Bash, Read, Write, Edit, Grep, Glob, Agent, WebSearch, WebFetch, MCP）、レスポンス完了マーカー（`✻ Baked for` / `✻ Cost:`）。構造化された `ClaudeActivity` をレンダラーにブロードキャストしてサイドバーに表示。
- **フックイベントルーティング**: `hook.event` V2 パイプメソッドが `HOOK_EVENT` IPC をすべてのウィンドウにブロードキャスト。Edit/Write フックは段階的な `DIFF_UPDATE` イベントも追加で送信。
- **サイドバーツール活動表示**: `WorkspaceRow` でフックイベントと PTY オブザーバーのデータを 5 秒 TTL でマージして、現在のツール、スキル、エージェントレベルの活動を表示。

---

## OpenCode インテグレーション (fork)

- **AGENTS.md 注入**: `ensureOpencodeContext()` が wmux リファレンスブロックを `~/.config/opencode/AGENTS.md` に書き込む（CLAUDE.md 注入と同じマーカー規則を使用）。
- **OpenCode プラグイン自動インストール**: `ensureOpencodePlugin()` が `resources/opencode-plugin/wmux.js` を `~/.config/opencode/plugin/wmux.js` にコピー。埋め込まれた `wmux-plugin-version:` マーカーでバージョンチェック。
- **パイプ経由のエージェント活動**: OpenCode プラグインが `wmux agent-activity` を呼び出してツール / スキル / 完了状態をサイドバーのオブザーバーシステムに送信できる。

---

## 名前付きパイプサーバー

- **V1 プロトコル**: ラインベースのテキストプロトコル。コマンド: `ping`（認証なし）、`report_pwd`、`report_git_branch`、`clear_git_branch`、`report_pr`、`clear_pr`、`report_shell_state`、`notify`、`ports_kick`。すべての V1 変更操作は `auth <token> ` プレフィックスが必要。
- **V2 プロトコル**: 同じパイプ上の JSON-RPC 2.0。`system.identify` と `system.capabilities` 以外のすべてのメソッドに `token` フィールドが必要。メソッドはメインプロセスのハンドラーまたはブリッジ経由でレンダラーにルーティング。
- **トークン認証** **(fork)**: 起動時に 32 バイトのランダムトークンを生成し、`%APPDATA%\wmux\pipe-token`（モード 0600）に永続化。すべてのスポーンシェルに `WMUX_PIPE_TOKEN` として注入し、`crypto.timingSafeEqual` で比較。認証なしの V1 変更操作と V2 の特権呼び出しは `unauthorized` を返す。
- **リモートトランスポート** **(fork)**: `--remote host[:port]` / `WMUX_REMOTE` と `--token T` / `WMUX_REMOTE_TOKEN` CLI フラグがトランスポートをローカルの名前付きパイプから TCP 接続に切り替え、リモートマシンのエージェントが SSH トンネル経由で wmux を操作できるようにする。
- **bridge コマンド** **(fork)**: `wmux bridge [--port P] [--host H]` がリモートマシン上で TCP-to-pipe リレーを起動（デフォルト `127.0.0.1:9787`）。純粋なバイトリレーとして動作し、パイプトークンはエンドツーエンドで検証される。
- **token コマンド** **(fork)**: `wmux token` がローカルインスタンスのパイプ認証トークンを出力し、制御マシンの `--token` で使用できるようにする。
- **インスタンス分離**: `WMUX_INSTANCE=<name>` がパイプパスと `%APPDATA%` ディレクトリの両方にサフィックスを付け、dev と prod インスタンスをパイプ衝突なしで同時実行できるようにする。

---

## 自動更新

- **electron-updater 統合**: パッケージ版ビルドのみ、`autoUpdater.checkForUpdates()` で GitHub Releases を 6 時間ごとにポーリング。
- **クアランティン期間**: GitHub サーバーサイドの `published_at` から計測して 3 日間（`WMUX_MIN_RELEASE_AGE_DAYS` で設定可能）は新リリースをダウンロードしない。検証可能な日付がないリリースはそのサイクルをスキップ。
- **サイレントインストールなし**: `autoDownload` と `autoInstallOnAppQuit` の両方を無効化。インストールにはユーザーのダイアログ確認が必要。
- **更新バッジ** **(fork)**: 更新がダウンロードされるとタイトルバーにバッジ (`UpdateBadge.tsx`) を表示。クリックで OS ブラウザの GitHub リリースページを開く。
- **通知のみモードのフォールバック** **(fork)**: `update-checker.ts` が `latest.yml` を持たないリリース（zip のみのリリース等）に対して GitHub API を独自にポーリング。見つかった更新は electron-updater を使わずにバッジとして表示。
- **キルスイッチ**: `WMUX_DISABLE_UPDATER=1` でエアギャップ / 企業環境向けにすべての更新ロジックを無効化。
- **CI での Authenticode 署名**: `release.yml` が SignPath 経由で `wmux.exe` に署名（シークレットが設定されている場合）。

---

## コマンドパレット

- **コマンドパレットオーバーレイ**: Ctrl+Shift+P でファジー検索オーバーレイ (`CommandPalette.tsx`) を表示。カテゴリ: アクション、コマンド、ワークスペース、テーマ。Escape またはアクション選択で閉じる。
- **パレットからのテーマ切り替え**: テーマをパレットに一覧表示して素早く適用できる。
- **パレットからの Markdown 表示**: "Open Markdown File…" アクションでファイルピッカーを起動。

---

## チュートリアル / オンボーディング

- **ウェルカムチュートリアル**: `Tutorial.tsx` が初回起動時にマルチステップのチュートリアルオーバーレイを表示。`localStorage['wmux-tutorial-seen']` または設定の "Show welcome screen" 無効化で非表示。
- **ヘルプボタン**: タイトルバーのヘルプボタンでいつでもチュートリアルを再表示。

---

## 多言語対応

- **3 つの UI 言語**: English、Français、中文 (`src/renderer/i18n/core.ts`)。初回起動時に OS / ブラウザのロケールから自動検出。設定 → 一般で変更可能。
- **対応箇所**: 設定タブ、一般 / 外観パネル、コマンドパレット、タイトルバー、ワークスペースコンテキストメニュー。未翻訳のキーは英語にフォールバックし、それも失敗したらキー名をそのまま表示。

---

## セキュリティ

- **パイプ認証**: すべての V1/V2 変更操作にインスタンスごとのトークンが必要（名前付きパイプサーバーを参照）。
- **Webview 強化**: すべての `<webview>` から `nodeIntegration` と `preload` を除去。`window.open` を OS ブラウザにリダイレクト。メインレンダラーのナビゲーションを localhost / file オリジンにロック。
- **トークンファイルのパーミッション**: モード 0600 で書き込み。Windows でのベストエフォートな Unix スタイル保護のために `chmodSync` を適用。
- **Markdown ファイル種別許可リスト**: `markdown.load_file` はテキスト / Markdown 拡張子かつ 5 MB 以下のみを受け付ける。
- **`taskkill` パスのピン留め**: `%SystemRoot%\System32\taskkill.exe` の絶対パスを使用して PATH ハイジャックを回避。
- **GitHub リリース URL 許可リスト**: `UPDATE_OPEN_RELEASE` IPC ハンドラーは `^https://github\.com/` にマッチする URL のみに対して `shell.openExternal` を呼び出す。
- **V2 パブリックメソッド許可リスト**: トークンなしで呼び出せるのは `system.identify` と `system.capabilities` のみ。それ以外はすべてブロック。

---

## ソース

このドキュメント作成にあたり参照したファイル:

- `/home/yuuki_katsumata/github/wmux/CLAUDE.md`
- `/home/yuuki_katsumata/github/wmux/src/cli/wmux.ts`
- `/home/yuuki_katsumata/github/wmux/src/shared/types.ts`
- `/home/yuuki_katsumata/github/wmux/src/shared/instance.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/index.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/pipe-server.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/pty-manager.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/ipc-handlers.ts`（一覧に記載、直接読み取りなし — main から推測）
- `/home/yuuki_katsumata/github/wmux/src/main/agent-manager.ts`（一覧に記載、直接読み取りなし — main から推測）
- `/home/yuuki_katsumata/github/wmux/src/main/cdp-bridge.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/cdp-proxy.ts`（一覧に記載、直接読み取りなし）
- `/home/yuuki_katsumata/github/wmux/src/main/claude-context.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/claude-observer.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/config-loader.ts`（一覧に記載、直接読み取りなし）
- `/home/yuuki_katsumata/github/wmux/src/main/diff-provider.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/git-poller.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/opencode-context.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/orchestration-watcher.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/port-scanner.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/pr-poller.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/session-persistence.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/theme-loader.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/updater.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/user-config.ts`
- `/home/yuuki_katsumata/github/wmux/src/main/window-manager.ts`（一覧に記載、直接読み取りなし）
- `/home/yuuki_katsumata/github/wmux/src/renderer/App.tsx`
- `/home/yuuki_katsumata/github/wmux/src/renderer/store/settings-slice.ts`
- `/home/yuuki_katsumata/github/wmux/src/renderer/hooks/useKeyboardShortcuts.ts`
- `/home/yuuki_katsumata/github/wmux/src/renderer/components/Sidebar/Sidebar.tsx`
- `/home/yuuki_katsumata/github/wmux/src/renderer/components/Sidebar/WorkspaceRow.tsx`
- `/home/yuuki_katsumata/github/wmux/src/renderer/components/SplitPane/PaneWrapper.tsx`
- `/home/yuuki_katsumata/github/wmux/src/renderer/components/Terminal/CopyMode.tsx`
- `/home/yuuki_katsumata/github/wmux/src/renderer/i18n/core.ts`
- `/home/yuuki_katsumata/github/wmux/src/shell-integration/wmux-powershell-integration.ps1`
- `/home/yuuki_katsumata/github/wmux/resources/wmux-orchestrator/scripts/detect-wmux.sh`
- `/home/yuuki_katsumata/github/wmux/resources/wmux-orchestrator/hooks/hooks.json`
