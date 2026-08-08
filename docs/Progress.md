# Progress

進行中・未着手タスクのみを管理する（完了したら本ファイルから削除し、必要なら `CHANGELOG.md` / `history/` へ移す）。


- 状態: ⬜未着手 / 🚧進行中 / 🟡要判断
- 影響度・重要度・難易度・工数: 大 / 中 / 小
- バックログは「優先」列の昇順（1 が最優先）。

## バックログ

| 優先 | # | 概要 | 状態 | 影響度 | 重要度 | 難易度 | 工数 |
|---|---|---|---|---|---|---|---|
| 2 | 6 | `applicationId` をテンプレートの `com.example.flutterbase` から実 ID へ変更する（`com.example.*` は Play Console が拒否） | 🟡要判断 | 大 | 大 | 小 | 小 |
| 3 | 1 | App Link のホストを実ドメインに差し替え、`assetlinks.json` を配信する | 🟡要判断 | 大 | 中 | 小 | 小 |
| 4 | 15 | 未使用の `AuthRepository.refresh` を削除する（セッション未永続の危険な重複実装） | ⬜未着手 | 中 | 中 | 小 | 小 |
| 5 | 16 | テンプレート由来のブックマーク機能を削除する | ⬜未着手 | 中 | 中 | 小 | 中 |
| 6 | 17 | バックアップ完了・失敗の通知を実装する（ヘッダーの通知ボタンは現在 no-op） | ⬜未着手 | 中 | 中 | 中 | 中 |
| 7 | 18 | CLAUDE.md のプロジェクト情報プレースホルダーを記入し、README を PhotoNest の説明にする | ⬜未着手 | 小 | 中 | 小 | 小 |
| 8 | 14 | アルバムメタデータのオフラインスナップショット（一覧・詳細をローカル保存し、オフライン起動でもキャッシュ済みサムネイルで一覧・グリッドを描画する） | ⬜未着手 | 中 | 中 | 中 | 中 |
| 9 | 19 | `mediaTotal` 欠落時のページング打ち切りフォールバックを見直す | ⬜未着手 | 小 | 小 | 小 | 小 |


## 詳細

### 15. 未使用の `AuthRepository.refresh` を削除する

2026-08-08 のシステムレビューで検出。`lib/domain/repositories/auth_repository.dart` の
`refresh` とその実装 `ApiAuthRepository.refresh` は `lib/` から一度も呼ばれず
（呼び出しはテストのみ）、実際のリフレッシュは `PhotoNestApiClient._refreshSession`
が担っている。未使用側は**ローテーション後のセッションを永続化せずに返す**ため、
誤って使われるとリフレッシュトークンを失う（クライアント側のコメントが警告している
まさにの失敗モード）。同一プロトコルの実装が 2 つあると乖離するので未使用側を消す。

### 16. テンプレート由来のブックマーク機能を削除する

ブックマーク一式（`pages/bookmarks/`・詳細・フォームダイアログ・sqflite リポジトリ・
ユースケース 5 本・ドロワー項目・`/bookmarks` ディープリンク・l10n キー）は
flutterbase テンプレートのサンプルで、PhotoNest の機能ではない
（`bookmarksUrlHint` が `https://docs.flutter.dev` のまま）。
`integration_test/app_test.dart` がこれを対象にしているため、削除時は
統合テストを実機能（アルバム閲覧等）へ書き換える。

### 17. バックアップ完了・失敗の通知

`main_page.dart` ヘッダーの通知ボタンは `onPressed: () {}` の no-op
（ADR-0005 で「将来のために予約」と明文化済み）。一方でバックグラウンド
アップロードは完了・失敗とも一切通知されず、ADR-0005 自身が第一の用途に
挙げているケースが未実装。バックアップ結果の通知（および通知一覧）を実装する。

### 18. CLAUDE.md / README の記入

`CLAUDE.md` の名称・種別・スタックが `<PROJECT_NAME>` 等のプレースホルダーのままで、
README も汎用テンプレート「flutterbase」の説明のまま。PhotoNest クライアントとしての
プロジェクト情報を記入する。

### 19. `mediaTotal` 欠落時のページング打ち切り

`lib/domain/entities/album.dart` が `mediaTotal` 欠落時に `media.length` へ
フォールバックする。サーバーが `mediaTotal` を返さず、かつ 1 ページ目が
ちょうど満杯（100 件）だった場合、`hasMore` が false になり 2 ページ目以降が
静かに読み込まれない。ページ件数がページサイズと一致した場合は続きがあると
みなす等、打ち切りが起きない側へ倒す。

### 14. アルバムメタデータのオフラインスナップショット

#10 でサムネイルの実体は SQLite に永続化されたが、どのメディアが
どのアルバムにあるかというメタデータはネットワーク経由でしか得られない。
そのためオフラインでのコールドスタートではアルバム詳細の取得自体が失敗し、
キャッシュ済みサムネイルにたどり着けない（PR #6 のレビュー指摘）。
アルバム一覧・詳細の応答をローカルに保存し、取得失敗時のフォールバック
として使えるようにする。

### 6. `applicationId` の変更

`android/app/build.gradle` が `com.example.flutterbase` のままで、Kotlin パッケージも
テンプレートのまま。`scripts/rename_app.sh` が用意されているので実 ID で実行する。

**要判断**: 実 ID はプロダクトオーナーが所有ドメインから決める必要があり、
コード側では決められない（一度 Play Console に上げた ID は変更不可）。
決まり次第 `./scripts/rename_app.sh <実ID>` を実行するだけで完了する。
候補の考え方: 所有ドメインの逆順 + アプリ名（例: 所有ドメインが
`example.com` なら `com.example.photonest`）。

### 1. App Link のホストを実ドメインに差し替える

テンプレートの既定値は `flutterbase.example.com` で、実在しません。
そのままでは `autoVerify` が失敗し、リンクはブラウザで開きます
（アプリの起動やアプリ内遷移は壊れません）。

fork 後に必要な作業は 3 つで、いずれも `docs/DEEP_LINKS.md` に手順があります。

1. `lib/shared/app_config.dart` の `appLinkHost` を実ドメインにする。
2. `android/app/src/main/AndroidManifest.xml` の `android:host` を合わせる。
3. `docs/deep_links/assetlinks.json` に署名フィンガープリントを入れ、
   `https://<host>/.well-known/assetlinks.json` として配信する。

テンプレート側で決められるのはここまでなので、作業自体は fork 側に残します。

**要判断**: 実際に配信に使うドメイン（PhotoNest サーバーを公開しているホスト等）と、
`assetlinks.json` に入れる署名フィンガープリント（release 鍵）が決まらないと
着手できない。ドメインが決まれば上記 1〜3 は `docs/DEEP_LINKS.md` の手順どおりで
工数小。#6 の `applicationId` 決定と同時に決めるのが望ましい
（`assetlinks.json` は `package_name` に実 ID を含むため）。
