# Tasks

## High Priority

- [x] **`/release` スキルの縮小または削除**
  - step 6〜12（zip・rcedit・GitHub release・タグ付け）はこのフォークでは不要
  - `deploy:dev` / `deploy:prod` が step 1〜5 を自動化済みのため実質未使用
  - 対応案: スキルを削除するか、step 1〜5 のみの参考資料として縮小する


## Medium Priority

- [x] **CLAUDE.md ヘッダーから upstream の情報を削除**
  - 対応済み（前回の CLAUDE.md オーバーホール時に削除済み）

- [x] **Known Build Gotcha の OneDrive 記述を確認・更新**
  - OneDrive は本家固有の問題。このフォークには該当しないためセクション削除

## Low Priority

- [x] **未追跡ファイルの扱いを決定**
  - `skills-lock.json` と `.agents/` を削除（Claude Code のスキル読み込みに未使用）

- [x] **Verification Criteria の code-reviewer 適用範囲を限定**
  - `git diff` が非空のタスク（ソースコード・設定ファイル編集）にのみ適用するよう修正
