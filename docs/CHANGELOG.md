# Changelog

完了した重要な変更の短い要約を、新しいものから並べます。
詳しい経緯が必要なものは `docs/history/`、設計判断は `docs/adr/` にあります。

## 2026-08-08 — アルバムメタデータのオフラインスナップショット

- 旧 Progress #14。#10 でサムネイルの実体は SQLite に永続化されたが、
  アルバム構成のメタデータはネットワーク経由でしか得られず、オフラインの
  コールドスタートではキャッシュ済みサムネイルにたどり着けなかった
  （PR #6 のレビュー指摘）。アルバム一覧・詳細ページの応答を
  `album_snapshots` テーブル（schema v7、サーバー+アカウント単位で分離）に
  スナップショット保存し、取得が `InfrastructureError`（ネットワーク不達
  含む）で失敗したときのフォールバックとして読み出すようにした。
  `AlbumSnapshotRepository`（Domain）+ `SqfliteAlbumSnapshotRepository`
  （Infrastructure）を追加し、`ListAlbumsUseCase` / `GetAlbumUseCase` が
  サーバー優先・成功時に上書き保存・失敗時にフォールバックを編成する。
  `AuthenticationError` はフォールバックせずそのまま表面化させる
  （スナップショットでサインイン済みを装わない）。サーバーが null を返した
  アルバム（削除済み）はスナップショットも破棄する。スナップショット
  ストア自体の故障はログに残してサーバー直読みへ縮退する。

## 2026-08-08 — バックアップ結果の通知（通知一覧）

- 旧 Progress #17。自動アップロードの各パスが結果（成功件数・失敗件数）を
  `backup_notifications` テーブル（schema v6）に記録し、ヘッダーの通知ボタン
  （ADR-0005 で予約済みだった no-op）から通知一覧 `/notifications` を開ける
  ようにした。未読件数はベルにバッジ表示され（同一プロセス内の書き込みは
  変更ストリーム経由で即時反映）、一覧を開くと**読み込んだ分だけ**既読になる
  （表示中に届いた結果は未読のまま残る）。
  記録は `SyncNewPhotosUseCase` 内で行うため、フォアグラウンド・
  バックグラウンド（WorkManager）どちらのパスも同じ痕跡を残す。
  通知の保存失敗はログに残して握りつぶす（アップロード自体は成功しており、
  通知行のためにパスを失敗させない）。

## 2026-08-08 — テンプレート残渣の整理とページング修正

- 旧 Progress #16。flutterbase テンプレート由来のブックマーク機能一式
  （画面・フォーム・sqflite リポジトリ・ユースケース 5 本・ドロワー項目・
  `/bookmarks` ディープリンク・l10n キー）を削除した。schema v5 で
  `bookmarks` テーブルをアップグレード時に DROP する。ディープリンクの
  例・ドキュメントはアルバムルート（`/albums/:id`）に置き換え、統合テストは
  アルバムタブとドロワー遷移を対象に書き換えた。外部リンク起動の
  `ExternalLinkLauncher` ポートと `url_launcher` 実装は汎用境界として残す。
- 旧 Progress #15。未使用の `AuthRepository.refresh` と
  `ApiAuthRepository.refresh` を削除した。実際のリフレッシュは
  `PhotoNestApiClient._refreshSession`（ローテーションされたトークン対を
  永続化する側）が唯一の実装になった。
- 旧 Progress #19。サーバーが `mediaTotal` を返さない場合の
  ページング打ち切りを修正した。`AlbumDetail.mediaTotal` は欠落時に
  ページ長へフォールバックせず null（不明）となり、不明な間は「続きあり」
  として扱って短いページの到着でページングを終える。
- 旧 Progress #18。`CLAUDE.md` のプロジェクト情報プレースホルダーを記入し、
  README をテンプレート「flutterbase」の説明から PhotoNest クライアント
  （PhotoNest サーバーの写真閲覧・バックアップ用 Flutter アプリ）の説明に
  書き換えた。

## 2026-08-08 — 動画対応（列挙・アップロード・再生）

- 旧 Progress #9。`PhotoManagerPhotoLibraryGateway` を `RequestType.common` に
  変更し、端末の動画も列挙対象にした（`LocalPhoto.isVideo` を追加、
  `READ_MEDIA_VIDEO` 権限を宣言）。アップロードの Content-Type マップに
  動画拡張子（mp4/mov/mkv/webm ほか）を追加。
- アップロードはプラットフォームがファイルパスを公開できる場合
  `MultipartFile.fromPath` でディスクからストリーミングし、長時間の動画でも
  ファイル全体をヒープに載せない（パスが無いアセットのみ従来のバイト列
  読み込みにフォールバック）。
- サーバー動画の再生を追加。`MediaPlaybackRepository`（`POST
  /api/media/{id}/playback-url` の署名付き URL をエンドポイントへ解決）と
  `video_player` ベースの `VideoPlaybackView` で、アルバム詳細から
  フルスクリーン再生できる。トランスコード中（409 `not_ready`）は
  「準備中」の翻訳済み文言を表示する。
- アルバム詳細のメディアに再生バッジを表示（サーバーが `isVideo` を返す。
  photonest 側の同日変更とセット）。

## 2026-08-08 — サムネイルのオフラインキャッシュとページング

- 旧 Progress #10。サーバーサムネイルを SQLite（schema v3 の
  `media_thumbnails` テーブル）へ永続化した。`GetMediaThumbnailUseCase` が
  キャッシュ優先で読み、ヒットすればネットワーク無しで描画される
  （オフライン・再起動後も表示可能）。サーバー + アカウント単位でスコープし、
  LRU で 128 MiB を上限に自動削除する（ADR 0007）。
- アルバム一覧はサーバーのページングを最後まで辿り、200 件超でも全件表示。
- アルバム詳細はメディアを 100 件ずつページ読み（`albumDetailProvider` が
  `AsyncNotifier` family になり、グリッド末尾で次ページを自動取得。失敗時は
  末尾タイルから再試行）。サーバー側 `GET /api/albums/{id}` の
  `page`/`pageSize` 対応とセット。

## 2026-08-08 — アプリを閉じている間の自動アップロード（WorkManager）

- 旧 Progress #4。`workmanager` の 15 分周期タスクで、アプリ終了中も
  新しい写真・動画を自動アップロードする（ADR 0006）。制約は
  「ネットワーク接続あり」「バッテリー残量低下時は実行しない」。
- Application に `BackgroundSyncScheduler` ポートを新設し、自動アップロードの
  ON/OFF と同期してスケジュールを登録・解除する。起動時にも設定が ON なら
  登録し直す（アプリ更新でスケジュールが消えた場合の自己修復）。
- フォアグラウンドとバックグラウンドの同期パスは共有 SQLite の同期リース
  （schema v4 の `sync_leases`）で相互排他し、別アイソレート同時実行による
  同一写真の二重アップロードを防ぐ（ADR 0006）。
- バックグラウンド側のエントリポイントは `lib/app/background/`（合成ルート）。
  既存の `SyncNewPhotosUseCase` をそのまま実行するため、アップロード履歴に
  よる冪等性・前提条件の再検査はフォアグラウンドと同一。

## 2026-08-07 — `integration_test` を認証ガード後の実態に合わせて修正し CI へ組み込み

- 旧 Progress #12。「起動直後に `NavigationBar` がある」前提だった
  `integration_test/app_test.dart` を、未ログイン起動はログイン画面・
  セッション保存済み起動はメイン画面、という認証ガード後の挙動に合わせて
  書き直した（セッションは実キーストアの `SessionRepository` へ直接保存して
  用意する。サーバーには接続しない）。
- `quality.yml` に `integration-tests` ジョブを追加し、Android エミュレータ
  （API 34, KVM）で `flutter test integration_test` を実行する。端末が要るため
  `scripts/ci.sh` には含めない（`docs/OPERATIONS.md` 参照）。

## 2026-08-07 — アップロードの進捗表示・キャンセル・失敗一覧 UI

- 旧 Progress #11。`UploadPhotosUseCase` に進捗コールバックと協調キャンセル
  （`UploadCancellation`、写真単位で中断）を追加し、`uploadRunProvider` が
  実行中バッチの進捗・結果を画面へ流す。
- アップロードタブは実行中に進捗バー（n/m）とキャンセルボタンを表示し、
  完了後に失敗があれば要約行から写真ごとの失敗一覧ダイアログを開ける。

## 2026-08-07 — サーバー由来エラー文言の翻訳キー化

- 旧 Progress #8。アルバム一覧・アルバム詳細・アップロード候補の読込エラーと
  写真ごとのアップロード失敗理由が、開発者向け英語の `AppError.message` を
  そのまま表示していたのをやめ、`LoginFailure` と同じ「失敗の種類で分類して
  翻訳キーへ写像する」方式に統一（`presentation/l10n/error_descriptions.dart`、
  `PhotoUploadFailureReason`）。

## 2026-08-07 — `azure-pipelines.yml` を削除し GitHub Actions へ一本化

- 旧 Progress #7。Azure パイプラインは `ios/` 不在で `Build_iOS` が必ず失敗、
  配布先の App Center も 2025-03 に廃止済み、release 鍵の配線も未接続で
  実質全損だったため削除。CI は GitHub Actions
  （`quality.yml` / `build.yml`）のみとする。

## 2026-08-07 — 通知ボタンは通知機能の予約済み入り口として残す（ADR-0005）

- 旧 Progress #13（ダミーの通知ボタンを削除するか実装するか）を「予約済みの
  入り口として残す」で決着。判断の経緯は
  `docs/adr/0005-notification-button-reserved.md`。コード変更なし。

## 2026-08-07 — `minSdk` を 36 から 24 へ引き下げ

- `minSdk = 36`（Android 16）は現実の端末シェアのほぼ全域を切り捨てており、
  旧端末のカメラロール移行という主要ユースケースと矛盾していたため、
  Android 7.0（API 24）まで引き下げた。`pubspec.yaml` の
  `min_sdk_android` も 24 に更新。
- API 33 未満には `READ_MEDIA_*` 権限が無いため、`AndroidManifest.xml` に
  `READ_EXTERNAL_STORAGE`（`maxSdkVersion="32"`）を追加。
- API 26 未満は adaptive icon（`mipmap-anydpi-v26`）を使えないため、
  `assets/icon/app_icon.png` からレガシー密度別の
  `mipmap-*/ic_launcher.png`（mdpi〜xxxhdpi）を生成してコミット
  （`dart run flutter_launcher_icons` の再実行でも同等物が生成される）。

## 2026-08-07 — 状態管理を Riverpod に一本化

判断の経緯は `docs/adr/0004-riverpod-unification.md`。

- `ChangeNotifier` ViewModel 6 本（Theme / Language / DebugSettings /
  About / Debug / Session）を Riverpod の `Notifier` / `FutureProvider` に
  置き換え、`AppScope`（`InheritedWidget`）を削除。
- 認証ガードは `redirect` 内で `ProviderScope.containerOf` からセッションを
  読み、セッション変化は合成ルートの `RouterRefreshBridge` が
  `refreshListenable` に伝える。
- サーバー由来のキャッシュ（アルバム・サムネイル・アップロード候補）は
  `sessionIdentityProvider` を watch して自動破棄する形になり、
  `SessionCacheReset` ウィジェットを削除。
- Riverpod 3 の既定の自動リトライを無効化（明示的な「再試行」UI と競合し、
  失敗時に裏でサーバーを叩き直してしまうため）。

## 2026-08-07 — 認証トークンの保存先を Keystore へ移行

- `SessionRepository` の実装を SharedPreferences（平文）から
  `flutter_secure_storage`（Android Keystore）へ差し替え。secure storage の
  API は非同期のため、起動時に一度読み込んでメモリに保持し、save / clear が
  キャッシュとキーストアを同時に更新する（`load()` の同期契約は不変）。
- 旧ビルドが SharedPreferences に残した平文トークンは起動時に Keystore へ
  移行し、平文側は無条件に削除する。

## 2026-08-07 — PhotoNest クライアント機能（ログイン・アルバム・アップロード）

テンプレート（flutterbase）を PhotoNest のモバイルクライアントとして実装。
バックエンドは photonest リポジトリの FastAPI（`/api`）。API 仕様は
サーバーの `/api/docs`（OpenAPI）を出所とする。

### 追加

- **ログイン**: サーバー URL + メールアドレス + パスワードでログイン
  （`POST /api/auth/login`、scope は `gui:view`）。アクセストークン失効時は
  `POST /api/auth/refresh` で自動更新し、ローテーションされたリフレッシュ
  トークンを即座に永続化。ルーターに認証ガードを追加し、未ログイン時は
  `/login` へ、ログイン済みでの `/login` は `/` へリダイレクト。
- **アルバム閲覧**: アルバム一覧（`GET /api/albums`）と詳細
  （`GET /api/albums/{id}`、`/albums/:id` ルート）。サムネイルは
  `GET /api/media/{id}/thumbnail`（Bearer 認証）をバイト列で取得して表示。
- **写真アップロード**: 端末の最近の写真から選択して
  `POST /api/upload/prepare` → `POST /api/upload/commit`（`X-Upload-Session`
  ヘッダー）で送信。アップロード済みの写真は SQLite の履歴
  （`uploaded_photos` テーブル、スキーマ v2）で管理し二重送信を防ぐ。
- **自動アップロード**: photo_manager の変更通知とフォアグラウンド復帰を
  トリガーに、有効化時点以降に撮影された未送信の写真を自動送信
  （`AutoUploadCoordinator`）。有効化時に基準時刻を一度だけ記録するため、
  既存のカメラロール全体を巻き込まない。カメラ（撮影）機能は持たない。
- 依存: `http` / `http_parser` / `photo_manager`。Android に
  `READ_MEDIA_IMAGES` / `READ_MEDIA_VISUAL_USER_SELECTED` 権限を追加。

### 変更

- アプリ identity を PhotoNest に変更（`AppConfig` / Android label / l10n）。
- MainPage のタブを ホーム/検索/設定 から アルバム/アップロード/設定 に変更し、
  テンプレートのデモコンテンツ（Home/Search タブ）を削除。設定タブに
  アカウント表示とログアウトを追加。
- アップロード後の写真がサーバーのライブラリに現れるのは、サーバー側の
  取り込みジョブ（local import）実行後。クライアントは受領（コミット成功）
  までを保証する。

## 2026-08-05 — 自己更新後の再実行が終了コード 126 で落ちる問題の修正

- `scripts/build-remote-container.sh` の自己更新後の再実行を、ファイルを直接
  実行する形から「今動いている bash に自分自身を渡す」形へ変更。ホスト上の
  コピーに実行権が無い場合（共有フォルダ経由で置くと 0644 になりがち）に
  `/usr/bin/env: bad interpreter: Permission denied`（終了コード 126）で
  ビルドが始まらないまま落ちていたため。あわせて、差し替えるファイルには
  元の権限に加えて実行権も付ける（元の権限をそのまま引き継ぐと、実行権の
  無い状態が更新のたびに引き継がれるため）。実行権は読み取りを許可している
  相手にだけ付けるので、`0640` のような絞った権限は `0750` にとどまる。

## 2026-08-03 — 配布物ビルドのスクリプト化

判断の経緯は `docs/adr/0003-build-in-dev-container.md`。

### 追加

- `scripts/build.sh` — APK / AAB をビルドし、`dist/` に配布物一式
  （成果物 + `manifest.env` + `manifest.sha256`）を書き出す。`apk` / `aab` /
  `all` の指定と、`BUILD_MODE` / `BUILD_NUMBER` に対応。
  `android/key.properties` に `storeFile` が無い release ビルド（＝Gradle が
  debug 鍵へフォールバックするビルド）は警告し、manifest に
  `signing=debug-keystore` を残す。
- `scripts/build-remote-container.sh` — git も Flutter も無い配布先ホスト向けの
  一括ビルド（SYNC → BUILD → PICK → VERIFY → PUBLISH）。同一ホスト上の dev
  コンテナで `git pull` と `build.sh` を実行し、`dist/` を一時ディレクトリへ
  取り込み、チェックサムが通ってから入れ替える（照合が通るまで前回の配布物を
  残す）。実行のたびに自分自身を最新版へ差し替える。
- `scripts/build-remote-container.env.example` — 上記の設定雛形。

### 変更

- `build.sh` はビルド後に `lib/shared/build_info.dart` をビルド前の内容へ戻す
  （未コミットの変更を持っていた場合はその内容へ）。生成物でありながら
  コミット対象のため、汚れたままだとビルドホストの次回の `git pull --ff-only`
  が失敗するため。
- `scripts/generate_build_info.sh` が `BUILD_NUMBER` を受け付けるようになった。
  未指定なら従来どおりコミット数。`build.sh` は `flutter build --build-number`
  と同じ値を渡すため、About 画面の build number と成果物の versionCode・
  `manifest.env` が食い違わない。
- `.gitignore` に `dist/` を追加。

## 2026-08-03 — 初期スタックの確定と App Links 対応

判断の経緯は `docs/adr/0002-starter-stack.md`。

### 追加

- ブックマーク機能（サンプル）— `go_router` / `flutter_riverpod` / `sqflite` /
  `path` / `url_launcher` を 4 層すべてに通す題材。一覧・詳細・追加・削除・
  外部リンク起動。
  - Domain: `Bookmark` / `BookmarkDraft` / `BookmarkId` / `BookmarkRepository`
  - Application: 5 つのユースケースと `ExternalLinkLauncher` ポート
  - Infrastructure: `AppDatabase`（スキーマ + マイグレーション）、
    `SqfliteBookmarkRepository`、`UrlLauncherExternalLinkLauncher`
  - Presentation: `BookmarksPage` / `BookmarkDetailPage` と
    `presentation/providers/` の Riverpod provider
- Android App Links の基礎 — `autoVerify` 付き intent filter、カスタムスキーム、
  `flutter_deeplinking_enabled`、`assetlinks.json` の雛形、診断画面（`/link`）。
  手順は `docs/DEEP_LINKS.md`。
- `lib/presentation/navigation/app_routes.dart` — 公開 URL とアプリ内ルートの
  唯一の定義元。
- `lib/app/di/provider_overrides.dart` — サービスロケータと Riverpod の橋渡し。

### 変更

- ルーティングを `Navigator.onGenerateRoute` から `go_router` に移行
  （`MaterialApp.router`）。これによりプラットフォームから届くリンクが
  通常の遷移と同じ経路で解決される。
- `minSdk` を 36 に統一。`flutter_launcher_icons.min_sdk_android` が 21 のまま
  食い違っていたのを解消。
- `url_launcher` を `tool/check_architecture.dart` の Infrastructure 限定
  package に追加。
- 起動時に SQLite を開くようになった（`InfrastructureModule.create`）。
- `dependency_policy.reserved` が空になった（宣言済み依存はすべて使用中）。

### 削除

- `equatable`、`riverpod_annotation`、`riverpod_generator`。

## 2026-08-03 — CI 品質ゲートの導入とツールチェイン更新

### 追加

- `scripts/ci.sh` — 整形・静的解析・アーキテクチャ検査・依存関係検査・
  テスト・カバレッジ下限・デバッグ APK ビルドを 1 コマンドで実行。
  規約違反時は非ゼロ終了。`--fast` / `--keep-going` / `--help` に対応。
  コード生成を使うプロジェクトでは `build_runner build` と
  `git diff --exit-code` も自動的に実行される。
- `tool/check_architecture.dart` — Analyzer の AST を走査してレイヤー規約を強制。
  依存方向、レイヤー別の禁止 import / 禁止型、Domain での `DateTime.now()` /
  `print` / `debugPrint`、Domain 型の `ChangeNotifier` 継承と public setter、
  具象アダプターへの依存を検出する。
- `tool/check_dependencies.dart` — `pubspec.yaml` と `lib/` の import を突き合わせ、
  未宣言依存・未使用依存・古い予約記載を検出。`packages/` にレイヤーを分割した
  場合は pubspec レベルの依存方向も検査する。
- `tool/check_coverage.dart` — `lcov.info` を読んで Domain 90% /
  Application 85% / 全体 80% を強制。
- `.github/workflows/quality.yml` — PR と main への push で `scripts/ci.sh` を実行。
  リリース・タグ・マージ運用には触れない。
- `test/coverage_surface_test.dart` — `lib/` の全ライブラリを import し、
  どこからも参照されていないファイルが計測対象から消えて全体カバレッジが
  実態より高く出るのを防ぐ。
- `test/support/` — Repository の in-memory fake、`AppLogger` の記録用ダブル、
  `AppScope` を組んだウィジェットテスト用ハーネス。
- `test/tool/` — 検査ツール自体のテスト。各ルールについて、違反を含む
  フィクスチャで非ゼロ終了することを確認する。
- `docs/adr/0001-single-package-layers.md` — 単一パッケージ構成を選んだ理由。

### 変更

- Flutter 3.44.8 / Dart 3.12 に更新し、依存パッケージを最新メジャーへ。
  `CardTheme` → `CardThemeData` の破壊的変更に追従。
- Android ツールチェインを Gradle 8.14.3 / AGP 8.11.1 / Kotlin 2.2.20 に更新。
  Gradle 8.3 は Flutter 3.44 の最低要件 8.7 を下回りビルドできなかった。
  非推奨の `Project.buildDir` と、AGP 8 で無効な `android.enableJetifier` を除去。
- レイヤー構成を整理。`lib/shared/` に混在していた値オブジェクト・エンティティ・
  エラー・ログ契約・テーマ・i18n を、それぞれ domain / application / presentation へ移動。
  `lib/shared/` はフレームワーク非依存の定数のみになった。
- `AppInfoRepository` が Application の DTO を返していた（Domain → Application の
  逆流）のを、Domain エンティティ `AppInfo` に変更。
- `AppLogger` ポートの `logFiles()` を `logFilePaths()` に変更し、`dart:io` の
  `File` を Application から排除。
- Presentation が合成ルートを import していたのをやめ、ViewModel は
  コンストラクタ注入、画面は新設の `AppScope`（`InheritedWidget`）から取得する形に。
- 合成ルートが `SharedPreferences` を直接扱っていたのをやめ、
  `InfrastructureModule` がアダプターを組み立てて Domain インターフェースだけを返す。
- `analysis_options.yaml` を強化。`strict-casts` / `strict-inference` /
  `strict-raw-types`、未使用 import・dead code・型不整合を error 扱い。
  併用できない `prefer_relative_imports` を外し `always_use_package_imports` に統一。
- カバレッジを Domain 100% / Application 100% / 全体 90% まで引き上げ。

### 削除

- `test/domain/app_colors_test.dart` — `test/presentation/theme/` の同名テストと
  内容が重複していた旧配置。
