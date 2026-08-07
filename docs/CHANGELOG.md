# Changelog

完了した重要な変更の短い要約を、新しいものから並べます。
詳しい経緯が必要なものは `docs/history/`、設計判断は `docs/adr/` にあります。

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
