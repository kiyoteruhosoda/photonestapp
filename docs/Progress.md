# Progress

進行中・未着手タスクのみを管理する（完了したら本ファイルから削除し、必要なら `CHANGELOG.md` / `history/` へ移す）。


- 状態: ⬜未着手 / 🚧進行中 / 🟡要判断
- 影響度・重要度・難易度・工数: 大 / 中 / 小
- バックログは「優先」列の昇順（1 が最優先）。

## バックログ

| 優先 | # | 概要 | 状態 | 影響度 | 重要度 | 難易度 | 工数 |
|---|---|---|---|---|---|---|---|
| 1 | 5 | `minSdk = 36` を引き下げる（Android 16 未満にインストール不可＝実質配布不能） | ⬜未着手 | 大 | 大 | 小 | 小 |
| 2 | 6 | `applicationId` をテンプレートの `com.example.flutterbase` から実 ID へ変更する（`com.example.*` は Play Console が拒否） | ⬜未着手 | 大 | 大 | 小 | 小 |
| 3 | 1 | App Link のホストを実ドメインに差し替え、`assetlinks.json` を配信する | ⬜未着手 | 大 | 中 | 小 | 小 |
| 4 | 7 | `azure-pipelines.yml` を整理する（`ios/` が無いのに iOS ビルドを実行し必ず失敗、App Center 配布は廃止済み、AAB が無署名になる経路あり） | 🟡要判断 | 中 | 中 | 小 | 小 |
| 5 | 8 | サーバー由来の英語エラー文言を翻訳キー化する（`LoginFailure` 方式の分類をアルバム／アップロードへ横展開） | ⬜未着手 | 中 | 大 | 中 | 中 |
| 6 | 9 | 動画対応（端末動画の列挙・アップロード・再生。現状 `RequestType.image` 固定で完全非対応） | ⬜未着手 | 大 | 大 | 大 | 大 |
| 7 | 10 | オフラインキャッシュ（サムネイル永続化）とアルバム詳細のページング（現状メモリキャッシュのみ・全件一括取得） | ⬜未着手 | 大 | 中 | 大 | 大 |
| 8 | 11 | アップロードの進捗表示・キャンセル・失敗一覧 UI | ⬜未着手 | 中 | 中 | 中 | 中 |
| 9 | 12 | `integration_test` の陳腐化を修正し CI で実行する（認証ガード導入後に前提が破綻、現在どの CI も実行していない） | ⬜未着手 | 中 | 中 | 小 | 小 |
| 10 | 13 | ダミーの通知ボタン（タップしても何も起きない）を削除するか実装する | 🟡要判断 | 小 | 中 | 小 | 小 |
| 11 | 4 | アプリを閉じている間の自動アップロード（WorkManager 等のバックグラウンド実行） | ⬜未着手 | 中 | 中 | 大 | 大 |


## 詳細

### 5. `minSdk = 36` の引き下げ

`android/app/build.gradle` の `minSdk = 36`（Android 16）は現実の端末シェアの
ほぼ全域を切り捨てる。旧端末のカメラロール移行が主要ユースケースの写真アプリと
矛盾するため、21〜24 相当へ引き下げる。`pubspec.yaml` の `min_sdk_android: 36` も
合わせて更新する。

### 6. `applicationId` の変更

`android/app/build.gradle` が `com.example.flutterbase` のままで、Kotlin パッケージも
テンプレートのまま。`scripts/rename_app.sh` が用意されているので実 ID で実行する。

### 7. `azure-pipelines.yml` の整理

- Stage `Build_iOS` は `ios/` ディレクトリが存在しないため必ず失敗し、
  `Deploy` は両ビルド成功が条件のため永久に到達しない。
- 配布先の Microsoft App Center は 2025-03 に廃止済み。
- keystore が無い場合でも `flutter build appbundle --release` が走り、debug 鍵署名の
  release AAB が生成される経路がある。
- `scripts/ci.sh`（アーキテクチャチェック・カバレッジ閾値）を呼ばず GitHub Actions の
  品質ゲートと乖離している。

GitHub Actions（`quality.yml` / `build.yml`）へ一本化して削除するのが有力。

### 8. サーバー由来エラーの翻訳キー化

`albums_tab.dart` / `album_detail_page.dart` / `upload_tab.dart` が
`error is AppError ? error.message : ...` で英語の開発者向け文言をそのまま表示する。
ログインだけは `LoginFailure` enum で分類し翻訳キーへ写像しているので、
同じ設計を横展開する。

### 9. 動画対応

- `photo_manager_photo_library_gateway.dart` が `RequestType.image` で動画を列挙対象外に
  している。
- アップロードの拡張子／Content-Type マップが静止画のみで、動画は
  `unsupported_format` になる。`READ_MEDIA_VIDEO` 権限も未宣言。
- 再生手段が無く、サーバー上の動画は静止画サムネイルの拡大表示になる。

### 10. オフラインキャッシュとページング

サムネイルはメモリキャッシュのみでアプリ再起動のたびに全件再取得。SQLite には
ブックマークとアップロード履歴しかない。アルバム一覧は `pageSize: 200` の 1 ページ
固定、詳細は `album['media']` を全件一括デコードしており、大規模アルバムで
時間・メモリともに破綻する。

### 12. `integration_test` の修正

`integration_test/app_test.dart` は「起動直後に `NavigationBar` がある」前提だが、
認証ガード導入後の初回起動は `/login` へリダイレクトされるため成立しない。
`scripts/ci.sh` も Azure も `flutter test integration_test` を実行していないため
破綻に誰も気づかない。実態に合わせて修正し、CI に組み込む。

### 4. バックグラウンド自動アップロード

現在の自動アップロードはアプリ起動中（photo_manager の変更通知）と
フォアグラウンド復帰時に動く。アプリを完全に閉じている間も撮影を検知して
アップロードするには WorkManager 等のバックグラウンド実行が必要で、
電池・権限まわりの設計を含めて別タスクとする。

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
