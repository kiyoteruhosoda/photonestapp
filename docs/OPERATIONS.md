# Operations

この文書は、デプロイ・リセット・マイグレーションなど、運用時に発生しやすい事象の一次切り分け手順をまとめます。

## 品質ゲート

すべての検査は 1 コマンドで走ります。CI (`.github/workflows/quality.yml`) が
実行するのも同じスクリプトなので、ローカルで通れば CI でも通ります。

```bash
./scripts/ci.sh                 # 全検査
./scripts/ci.sh --fast          # APK ビルドを飛ばす（開発中はこれで十分）
./scripts/ci.sh --keep-going    # 途中で止めず、最後に失敗一覧を出す
./scripts/ci.sh --help
```

実行される検査は次の順です。いずれかが失敗すると非ゼロ終了します。

| # | 検査 | コマンド |
|---|---|---|
| 1 | 依存解決 | `flutter pub get` |
| 2 | コード生成（使用時のみ） | `dart run build_runner build --delete-conflicting-outputs` |
| 3 | 生成物のコミット漏れ | `git diff --exit-code` |
| 4 | 整形 | `dart format --output=none --set-exit-if-changed .` |
| 5 | 静的解析 | `flutter analyze --fatal-infos --fatal-warnings` |
| 6 | アーキテクチャ規約 | `dart run tool/check_architecture.dart` |
| 7 | 依存関係規約 | `dart run tool/check_dependencies.dart` |
| 8 | テスト | `flutter test --coverage` |
| 9 | カバレッジ下限 | `dart run tool/check_coverage.dart` |
| 10 | ビルド | `flutter build apk --debug` |

2 と 3 は、`build.yaml` があるか `lib/` に `part '*.g.dart'` /
`part '*.freezed.dart'` があるときだけ走ります。現状このテンプレートは
コード生成を使っていないため自動的にスキップされます。

### 個別に走らせる

```bash
dart run tool/check_architecture.dart --verbose   # レイヤー違反の詳細
dart run tool/check_dependencies.dart --verbose   # pubspec と import の突き合わせ
flutter test --coverage
dart run tool/check_coverage.dart --verbose       # 下限割れ時に低い順で列挙
```

`tool/check_architecture.dart` は `--root` / `--package` を受け取ります。
テスト用フィクスチャに対して走らせるためのもので、通常は不要です。

### 検査ツール自体のテスト

`test/tool/` が各ルールについて「違反入りのフィクスチャで非ゼロ終了すること」を
確認します。時間がかかるので、開発中に飛ばしたい場合は次を使います。

```bash
flutter test --exclude-tags tool
```

### よくある失敗と対処

| 症状 | 原因 | 対処 |
|---|---|---|
| `banned-import` | Domain / Application が Flutter や I/O package を import した | そのコードを `lib/infrastructure/` へ移し、Application にポートを切る |
| `layer-direction` | 依存方向が外向きになった | `docs/ARCHITECTURE.md` の表を参照。Presentation から合成ルートを引いていないか確認 |
| `concrete-adapter-dependency` | 具象アダプターを直接参照した | Domain のインターフェースに差し替える。束ねてよいのは `lib/app/` だけ |
| `unused-dependency` | 使っていない runtime 依存がある | 削除するか、意図的なら `pubspec.yaml` の `dependency_policy.reserved` に記載 |
| `stale-reservation` | reserved の記載が実態と合っていない | 使い始めた package は reserved から外す |
| カバレッジ下限割れ | テスト不足 | `--verbose` で低い順に出るので上から潰す |
| `every library under lib/ is imported by this file` が落ちる | `lib/` にファイルを足したが `test/coverage_surface_test.dart` に import していない | 失敗メッセージのとおり import を追加 |
| `AndroidManifest — deep links` が落ちる | `AppConfig` と `AndroidManifest.xml` のホスト / スキームが食い違った | 両方を揃える。手順は `docs/DEEP_LINKS.md` |

## 配布物をビルドする

配布用の APK / AAB は `scripts/build.sh` で作ります。出力先ディレクトリ
（既定 `dist/`）が配布物の一式で、これをそのまま配布元のマシンへ渡せば足ります
（リポジトリも Flutter SDK も要りません）。

```bash
./scripts/build.sh              # APK + AAB（release）を dist/ へ
./scripts/build.sh apk          # APK だけ
./scripts/build.sh aab out      # AAB だけを out/ へ
./scripts/build.sh --help
```

| 環境変数 | 既定 | 意味 |
|---|---|---|
| `BUILD_MODE` | `release` | ビルド variant（`release` / `debug`） |
| `BUILD_NUMBER` | `git rev-list --count HEAD` | Android の versionCode |

出力されるもの:

| ファイル | 内容 |
|---|---|
| `<base>-<version>-<variant>.apk` | 端末へ入れる配布物 |
| `<base>-<version>-<variant>.aab` | Play Console へ上げる配布物 |
| `manifest.env` | commit / branch / version / 署名鍵 / ファイル名 |
| `manifest.sha256` | 転送破損を検出するためのチェックサム |

`<base>` は `android/app/build.gradle` の `appApplicationId` の末尾
（`android/gradle.properties` の `app.archivesBaseName` があればそちら）です。

出力先にある古い APK / AAB は毎回消してから書き出します。新しいものの隣に
前回の版が残っていると、配布元では見分けが付かないためです。

### 署名

`android/key.properties` に `storeFile` があれば release 鍵で、無ければ debug 鍵で
署名されます（`android/app/build.gradle` のフォールバック）。判定はファイルの有無
ではなく `storeFile` の有無で行います。`build.gradle` がそう判定するためで、
中身が空・書きかけの `key.properties` があっても debug 鍵になります。

debug 鍵になった場合は警告を出し、`manifest.env` の `signing` にも
`debug-keystore` と記録します。**社外へ配るビルドでは必ず
`signing=release-keystore` を確認してください。** 鍵の用意は
`docs/CUSTOMISATION.md` にあります。

### 生成物とワーキングツリー

`lib/shared/build_info.dart` は生成物ですがコミット対象です。ビルドで書き換わった
ままだとビルドホストの次の `git pull --ff-only` が失敗するため、`build.sh` は
ビルド前の内容へ戻してから終了します（失敗時も戻します）。開発機で未コミットの
変更を持っている場合も、その内容が戻ります。

`BUILD_NUMBER` を指定した場合、その値は `BuildInfo.buildNumber` にも渡ります。
アプリの About 画面が表示する build number と、成果物の versionCode・
`manifest.env` が食い違わないようにするためです。

## git も Flutter も無いホストでビルドする

NAS やファイルサーバーのように、git も Flutter SDK も置けないホストで配布物を
用意する場合は `scripts/build-remote-container.sh` を使います。ソース取得と
ビルドは**同じホスト上の dev コンテナ**の中で行い、出来上がった `dist/` を
ホストから見えるパス経由で配布ディレクトリへ取り込みます。

```bash
./build-remote-container.sh          # APK + AAB
./build-remote-container.sh apk
./build-remote-container.sh aab
```

実行される 5 ステップ:

| 順 | ステップ | 内容 |
|---|---|---|
| 1 | SYNC | dev コンテナ内で `git pull --ff-only` |
| 2 | BUILD | dev コンテナ内で `scripts/build.sh <target>` |
| 3 | PICK | 出来上がった `dist/` を配布ディレクトリ内の一時ディレクトリへ取り込む |
| 4 | VERIFY | `manifest.sha256` で取り込んだ配布物を照合する |
| 5 | PUBLISH | 照合できた配布物を入れ替える（旧版はここで消える） |

取り込みを一時ディレクトリで行うのは、**照合が通るまで前回の配布物を残す**ためです。
コピーが途中で失敗しても、壊れたビルドが届いても、ダウンロードできるのは
前回の正常なビルドのままです。

SYNC の直後に、dev コンテナ内の `build-remote-container.sh` と自分自身を
byte 単位で比較し、異なれば最新版へ差し替えて同じ引数で再実行します
（このスクリプトは `dist/` に含まれない手置きのブートストラップなので、
`git pull` では更新されないため）。再実行は 1 回に限定します。
再実行は「今動いている bash に自分自身を渡す」形で行うため、ホスト上の
コピーに実行権が無くても（共有フォルダ経由で置くと 0644 になりがちです）
そのまま続行します。差し替え後のファイルには実行権も付けますが、付けるのは
読み取りを許可している相手だけです（`0640` は `0750` になります）。

### 設定

スクリプトと同じ場所に `build-remote-container.env`（`KEY=VALUE` 形式。雛形は
`scripts/build-remote-container.env.example`）を置くか、環境変数で与えます。
**スクリプト冒頭の既定値は書き換えないでください**（自己更新で丸ごと差し替わり、
編集は次回実行時に失われます）。

| キー | 既定 | 意味 |
|---|---|---|
| `APP_PROJECT` | ディレクトリから自動取得 | プロジェクト名 |
| `APP_DEV_CONTAINER` | `ubuntu-dev` | ビルドを行う dev コンテナ名 |
| `APP_DEV_USER` | `sshuser` | コンテナ内の実行ユーザー |
| `APP_DEV_WORKDIR` | `/work/project/{PROJECT}` | コンテナ内のリポジトリ working dir |
| `APP_DIST_DIR` | （必須） | ホストから見える `dist/` の絶対パス |
| `APP_ARTIFACT_DIR` | スクリプトの場所 | 配布ディレクトリ |
| `BUILD_MODE` | （未設定） | `build.sh` へそのまま渡す |

値の中の `{PROJECT}` は確定したプロジェクト名へ展開されます。ディレクトリ構成が
`/<プロジェクト名>/<チャネル>`（例 `/volume1/builds/flutterbase/internal`）なら
プロジェクト名は親ディレクトリ名から決まるので、`PROJECT` の指定は不要です。

### よくある失敗と対処

| 症状 | 原因 | 対処 |
|---|---|---|
| `git pull inside the dev container failed` | コンテナ内のワーキングツリーが汚れている | コンテナ内で `git status` を見る。`build.sh` 以外が生成物を書き換えていないか確認 |
| SELF-UPDATE 直後に `bad interpreter: Permission denied`（終了コード 126） | 自己更新に対応していない古いホスト側コピーが、実行権の無いファイルを直接実行しようとした | もう一度実行する（差し替えは済んでいるので次回は通る）。以後は再実行が bash 経由になるため再発しません |
| `dist not found` | `APP_DIST_DIR` がコンテナ内のパスを指している | ホストから見えるパスを指定する |
| `checksum mismatch` | 取り込み中に転送が壊れた | もう一度実行する。繰り返すなら共有フォルダの状態を確認 |
| `signing=debug-keystore` のまま配ってしまった | `android/key.properties` が無い | 鍵を置いて再ビルドする（`docs/CUSTOMISATION.md`） |

## ローカル DB (SQLite)

スキーマとマイグレーションは `lib/infrastructure/database/app_database.dart`
に集約しています。DB を開くのはアプリ起動時（`InfrastructureModule.create`）
の 1 回だけです。

| 項目 | 値 / 場所 |
|---|---|
| ファイル名 | `flutterbase.db`（`AppDatabase.fileName`） |
| 配置 | プラットフォームの databases ディレクトリ（`getDatabasesPath()`） |
| スキーマ版 | `AppDatabase.schemaVersion` |
| マイグレーション | `AppDatabase._upgrade` の `if (from < n)` ラダー |

### スキーマを変更する

1. `AppDatabase.schemaVersion` を 1 つ上げる。
2. `_upgrade` に `if (from < <新しい版>) { ... }` を追加する。
   既存のブロックは消さないでください。数リリース飛ばして更新した端末は、
   上から順に全部を通ります。
3. `_create` にも同じ最終形を反映する（新規インストール用）。
4. `test/infrastructure/database/app_database_test.dart` にケースを足す。

### リセット

アプリのデータを消せば DB ファイルごと消えます。

```bash
adb shell pm clear com.example.flutterbase
```

### テスト

Android / iOS の sqflite プラグインはホスト上では動かないため、テストは
`sqflite_common_ffi` の `databaseFactory` に差し替えて**同じ production コード**
を実行します。`AppDatabase.open` が top-level の `openDatabase` ではなく
ambient な `databaseFactory` を使っているのはこのためです。

```dart
setUpAll(() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
});
```

## ディープリンク

App Links / カスタムスキームの設定・確認手順は `docs/DEEP_LINKS.md` にあります。

切り分けの起点はログです。ルーターに届いたリンクは必ず
`[Router] → /bookmarks/1` の形で残ります。

- ログが出ない → リンクがアプリに届いていない（intent filter か検証の問題）
- ログは出るが画面が出ない → ルートが一致していない（`AppRoutes` を確認）

アプリ内の `/link` 画面（ドロワー → ディープリンク）に、起動時 URL と
`adb` コマンドが表示されます。

## Android ツールチェイン

`android/` は Flutter 3.44 系に合わせて次で固定しています。

| 項目 | バージョン | 定義場所 |
|---|---|---|
| Gradle | 8.14.3 | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | 8.11.1 | `android/settings.gradle` |
| Kotlin | 2.2.20 | `android/settings.gradle` |
| JDK | 17 | `android/app/build.gradle` (`compileOptions`) |

Flutter は AGP 9 / Gradle 9 系もサポートしますが、AGP 9 は新 DSL のみを
読むため、Groovy の `build.gradle` をそのまま使うなら 8 系に留めるのが安全です。
上げる場合は `android.newDsl` と `build.gradle` の書き換えをセットで行ってください。

Gradle のバージョンが低いと `flutter build` は
`Your project's Gradle version ... is lower than Flutter's minimum supported version`
で失敗します。Flutter を上げたらこの表も合わせて更新してください。

## デプロイ時の確認観点

デプロイは次の境界ごとに分けて確認します。

| 境界 | 確認対象 | 代表的な失敗 |
|---|---|---|
| Image | 実行イメージと revision | 古い image、想定外の tag |
| Runtime | ホスト kernel / cgroup / libc | バイナリ互換性不足 |
| Database | 起動状態 / healthcheck | 初期化待ち、volume 破損 |
| Migration | migration ツール / schema | migration binary の起動失敗、SQL エラー |

境界を分けることで、単一の巨大な `if` / `switch` 的な切り分けではなく、責務ごとの Strategy として原因を特定しやすくします。

## MariaDB reset 後に `sqlx: GLIBC_2.39 not found` が出る場合

### 症状

`./deploy.sh reset` などで DB volume を削除し、MariaDB の healthcheck が `healthy` になった後、migration フェーズで次のエラーが出ます。

```text
sqlx: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.39' not found (required by sqlx)
DB migration failed after 3 attempts
```

この場合、MariaDB 自体は起動できています。失敗している境界は **Database** ではなく **Migration runtime** です。

### 原因

`sqlx` CLI バイナリが、実行コンテナまたはホストに入っている glibc より新しい glibc を要求しています。

典型例:

* Ubuntu 24.04 など glibc 2.39 系で build した `sqlx` を、Debian bookworm / bullseye 系の image で実行している
* CI で作った `sqlx` バイナリを、NAS や古い distro ベースのコンテナへコピーしている
* migration image と builder image の OS 世代が揃っていない

### 推奨対応

migration image の中で、実行環境と同じ libc 世代に合わせて `sqlx` を build / install してください。DDD の境界で考えると、migration 実行は API や Web とは別の Infrastructure concern なので、専用 image に閉じ込めるのが安全です。

推奨方針:

1. `sqlx` をホストや別 OS 世代の CI artifact からコピーしない
2. `migrate` service の Dockerfile 内で `cargo install sqlx-cli --no-default-features --features mysql` を実行する
3. builder stage と runtime stage の distro 系統を合わせる
4. どうしても単体バイナリを配布する場合は、配布先より古い glibc で build する

例:

```dockerfile
FROM rust:1-bookworm AS builder
RUN cargo install sqlx-cli --locked --no-default-features --features mysql

FROM debian:bookworm-slim AS migrate
COPY --from=builder /usr/local/cargo/bin/sqlx /usr/local/bin/sqlx
COPY migrations /app/migrations
WORKDIR /app
CMD ["sqlx", "migrate", "run"]
```

builder と runtime をどちらも bookworm 系にしておくと、`sqlx` が要求する glibc と runtime の glibc がずれにくくなります。

### 確認コマンド

migration コンテナ内で次を確認します。

```sh
ldd --version
sqlx --version
ldd "$(command -v sqlx)"
```

`ldd` の glibc version が `sqlx` の要求 version より古い場合は、migration image の作り直しが必要です。

### 暫定回避

すぐに復旧が必要な場合は、次のどちらかを選びます。

* runtime と同じ OS 世代の環境で `sqlx` を再 build して image を作り直す
* `sqlx` CLI を使わず、API binary に組み込んだ migration runner など、同一 image 内で build 済みの実行経路へ切り替える

ただし、ホストへ新しい glibc を手動導入する対応は推奨しません。NAS や appliance 系環境では OS 全体の互換性を壊すリスクがあります。
