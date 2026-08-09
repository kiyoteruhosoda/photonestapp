# Progress

進行中・未着手タスクのみを管理する（完了したら本ファイルから削除し、必要なら `CHANGELOG.md` / `history/` へ移す）。


- 状態: ⬜未着手 / 🚧進行中 / 🟡要判断
- 影響度・重要度・難易度・工数: 大 / 中 / 小
- バックログは「優先」列の昇順（1 が最優先）。

## バックログ

2026-08-09 の再レビュー（サーバー側 API との突き合わせ・使い勝手・死にコード）
で挙がった項目。

| 優先 | # | 概要 | 状態 | 影響度 | 重要度 | 難易度 | 工数 |
|---|---|---|---|---|---|---|---|
| 1 | A1 | 写真タブに検索・絞り込みが無い（翻訳文言だけ先にある） | ⬜未着手 | 大 | 大 | 中 | 中 |
| 2 | A2 | サムネイルを 1 枚ずつ取っていて CDN・署名 URL に乗らない | ⬜未着手 | 中 | 大 | 中 | 中 |
| 3 | A3 | お気に入り・削除／ゴミ箱・タグがアプリから触れない | ⬜未着手 | 中 | 中 | 中 | 大 |
| 4 | A4 | 未使用の l10n キーが 197 個中 21 個ある | ⬜未着手 | 小 | 中 | 小 | 小 |

## 詳細

1. **A1 — 検索。** サーバーの `GET /api/media` は `q`（ファイル名・カメラ・
   タグ名の部分一致）・`tags`・`type`・`after` / `before`・`favorite` を受けるが、
   アプリはどれも送らず、写真タブは時系列の全件だけを出す。枚数が増えるほど
   「あの写真」に辿り着けなくなる。文言は
   `lib/presentation/l10n/` に `navSearch` / `searchFieldLabel` /
   `searchFieldHint` / `searchEmptyMessage` が en・ja 両方すでに入っており、
   画面だけが作られていない（A4 と同じ根）。タブは写真・アルバム・
   アップロード・設定の 4 つで、検索タブは無い。
2. **A2 — サムネイル取得。** `ApiMediaThumbnailRepository` は
   `GET /api/media/{id}/thumbnail` を 1 枚ずつ叩く。SPA は
   `POST /api/media/thumb-urls`（1 回 500 件）で署名 URL をまとめて受け取り、
   nginx の `X-Accel-Redirect`／CDN から直接引く。アプリは全部の
   タイルがアプリサーバーを通るので、グリッド 1 画面ぶんで認証付き
   ラウンドトリップが数十回走り、CDN の恩恵も受けられない。ローカルの
   サムネイルキャッシュ（`sqflite_media_thumbnail_cache_repository`）は
   あるので、効くのは初回スクロールと再取得時。
3. **A3 — 参照以外の操作。** アプリが呼ぶエンドポイントは 12 本
   （login / logout・media 一覧・thumbnail・original-url・playback-url・
   albums 一覧・albums 詳細・分割アップロード 4 本）だけ。サーバーにある
   お気に入り（`POST /media/{id}/favorite`）・削除と復元
   （`DELETE /media/{id}`・`/restore`・`deleted_only`）・タグ（`/tags`）・
   アルバムの作成と編集・プロフィール／パスワード変更・TOTP・パスキーは
   どれもアプリから触れない。「撮る・上げる・見る」までは完結しているが、
   整理は SPA を開かないとできない。全部を一度に入れる必要は無いので、
   お気に入りと削除／ゴミ箱から順に入れる。
4. **A4 — 未使用の l10n キー。** `app_localizations.dart` の 197 キーのうち
   21 個がどこからも参照されていない。内訳は FlutterBase 雛形の名残
   （`homeWelcomeTitle` / `homeCardBody` / `homeComponentsTitle` /
   `homePrimaryButton` / `homeSecondaryButton` / `homeTextFieldLabel` /
   `homeTextFieldHint` / `homeListCardTitle` / `homeListCardSubtitle` /
   `homeListCardItem2`）、作られなかった検索機能（`navSearch` /
   `searchFieldLabel` / `searchFieldHint` / `searchEmptyMessage`、A1 参照）、
   その他（`uploadTitle` / `uploadSelected` / `aboutDebugAlreadyOn` /
   `licensesTitle` / `licensesDetails` / `commonLoading` / `commonEmpty`）。
   en・ja 両方にある。雛形の名残は消し、検索のぶんは A1 で使うか一緒に消す。

## メモ（実装済みタスクの運用上の注意）

- **release 署名のフィンガープリントが未記入。** `docs/deep_links/assetlinks.json`
  は `package_name` と debug 署名の指紋まで入っているが、release 分は
  `REPLACE:WITH:YOUR:RELEASE:KEYSTORE:SHA256:FINGERPRINT` のまま。鍵を持つ人が
  `docs/DEEP_LINKS.md` の手順で埋め、サーバーの管理画面
  （Domains & URLs > Android アプリリンク）へ貼るまで、release ビルドの
  App Link は検証されずブラウザで開く。Play App Signing を使う場合は
  アップロード鍵ではなく Play Console の「アプリの署名鍵の証明書」の指紋を使う。
- `minSdk` は 31。App Links の intent filter が `android:pathAdvancedPattern`
  （API 31 以上）でパスを厳密に絞っているため、下げるならパス指定の書き換えが
  先。API 30 以下の端末はこの属性を無視し、filter がホスト全体へ静かに広がる。
- ローカル DB のファイル名は `flutterbase.db` のまま（`AppDatabase.fileName`）。
  端末内部の名前で画面にも API にも出ないため、改名しても得が無く、既存
  インストールのローカルデータを捨てるだけになる。
