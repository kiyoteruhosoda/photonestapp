# flutterbase

Flutter アプリケーションを素早く立ち上げるためのテンプレートプロジェクトです。

このリポジトリは、アプリ本体の雛形だけでなく、AI エージェントや開発者が作業するときのルールも含みます。`CLAUDE.md` はコンテキストを圧迫しない最小テンプレートとして維持し、詳細な考え方・運用方針・作業手順はこの README と `.claude/skills/` に分けます。

## Getting Started

このテンプレートを自分のアプリ用に fork / clone して使う場合は、まず以下を読んでください。

```text
docs/CUSTOMISATION.md
```

`docs/CUSTOMISATION.md` は、パッケージ名変更、アプリ名、Android label、launcher icon、debug keystore、検証手順など、fork 時に必要な具体的作業のガイドです。

ディープリンク（App Links）を使う場合は、ホスト名の差し替えと `assetlinks.json` の配信が必要です。手順は `docs/DEEP_LINKS.md` にあります。

## Starter Stack

テンプレートが採用している package と、それぞれの担当レイヤーです。すべて `lib/` のサンプル実装（ブックマーク機能）で実際に使われています。採否の理由は `docs/adr/0002-starter-stack.md`、置き場所の一覧は `docs/ARCHITECTURE.md` にあります。

| package | 用途 | レイヤー |
|---|---|---|
| `go_router` | ルーティングとディープリンク受け口 | 合成ルート（`lib/app/`） |
| `flutter_riverpod` | 状態管理（コード生成なし） | Presentation |
| `get_it` | サービスロケータ | 合成ルート |
| `sqflite` | ローカル DB | Infrastructure |
| `path` | DB ファイルパスの組み立て | Infrastructure |
| `url_launcher` | 外部リンク起動（ポートの背後） | Infrastructure |

`equatable` と `riverpod_annotation` / `riverpod_generator` は採用していません。値の等価性は手書きの `==` / `hashCode`、Riverpod の provider も手書きです。コード生成を挟まないぶん、clone してすぐ動きます。

## Purpose

* 再利用しやすい Flutter プロジェクト構造を提供する
* 初期セットアップ・設定・検証手順を標準化する
* DDD / OOP / SOLID / DI を意識した実装の出発点を提供する
* AI エージェントが読むトップレベル指示を小さく保ち、詳細は Skill と docs に分離する
* 何もしなくても最小起動できるテンプレートを維持する

## Guidance Layout

このリポジトリのガイドは、読む人と用途ごとに分けています。

| 場所 | 役割 | 書くこと |
|---|---|---|
| `CLAUDE.md` | AI エージェント向けの最小ルート指示 | 絶対に外せない方針、docs / skills の参照先 |
| `.claude/rules/` | 常時適用する短い原則 | アーキテクチャ、コーディング、Git、UI の基本ルール |
| `.claude/skills/` | 作業種別ごとの手順 | 機能追加、設定、ログ、テスト、PR などの工程 |
| `docs/` | プロジェクト文書 | 設計、運用、進捗、変更履歴、ADR、詳細な経緯 |
| `docs/CUSTOMISATION.md` | fork ガイド | テンプレート利用者が変更すべき app identity / Android / icon / signing |
| `README.md` | 人間向けの全体説明 | 方針の背景、設計思想、文書の読み方 |

`CLAUDE.md` を短くした理由は、AI エージェントのコンテキスト消費を抑えるためです。一方で、人間が読む説明まで削ると意図が失われるため、この README に背景をまとめています。

## Core Principles

### 1. 最小起動を壊さない

テンプレートは、初期状態または最小設定で起動できることを重視します。

* 何もしなくてもログイン画面または初期画面が表示される
* 開発者が最初に読むべき設定が分散しすぎていない
* 必須ではない外部サービスが未設定でも、開発体験が破綻しない
* セキュリティを強める前の開発初期段階では、まず動くことを優先する

ただし、本番運用に入る段階では、認証、認可、秘密情報、署名鍵、通信経路、ログの個人情報などを必ず見直します。

### 2. DDD + OOP + SOLID + DI

実装では、責務分離と依存方向を重視します。

基本的な依存方向は次の考え方です。

```text
Presentation -> Application -> Domain
Infrastructure -> Domain interfaces
```

* **Domain** は業務ルール・不変条件・ドメイン語彙を表現する
* **Application** はユースケースを調整し、Domain と外部境界をつなぐ
* **Infrastructure** は DB、API、ファイル、OS、外部サービスなどの具体実装を担当する
* **Presentation** は UI / 入出力 / 表示状態を担当し、業務ルールを持たない

Domain は UI、DB、HTTP、JSON、フレームワークの詳細に依存しないようにします。Infrastructure は Domain 側に定義された interface / abstract contract を実装します。これにより、テストしやすく、実装差し替えが可能な構成になります。

### 3. ポリモーフィズムを使う場所

条件分岐が増え続ける箇所では、単純な `if` / `switch` の肥大化を避け、用途に応じてポリモーフィズムを検討します。

例:

* 認証方式ごとの Strategy
* 通知チャネルごとの Sender
* 保存先ごとの Repository 実装
* 表示フォーマットごとの Formatter
* 権限判定ルールごとの Policy

ただし、過剰設計は避けます。分岐が少なく、将来の差し替え可能性も低い場合は、読みやすい単純な分岐で十分です。ポリモーフィズムは「変更理由が分かれる場所」「実装を差し替えたい場所」「テストダブルを使いたい境界」に限定して使います。

### 4. 設定はデフォルトから始める

開発環境では、なるべく少ない手順で起動できるようにします。

推奨する優先順位は次の通りです。

```text
組み込みデフォルト -> env ファイル -> 環境変数 -> 永続設定 -> migration / seed による自動設定
```

方針:

* 設定値は散らばった raw access ではなく、設定モジュールや設定サービスを通して取得する
* 開発用デフォルトは用意するが、秘密情報をログに出さない
* 本番向けの必須設定は起動時に fail-fast で検出する
* 設定の追加・上書きルールは `.claude/skills/configuration.md` に従う

### 5. Compose / scripts による運用容易性

ローカル開発・検証・配布の流れは、できるだけスクリプト化します。

目指す状態:

* 開発環境で build できる
* コンテナイメージや配布物を作れる
* Compose などで必要コンポーネントをまとめて起動できる
* reset の引数でデータ初期化の有無を選べる
* migration が必要な場合は、方針に従って明示または自動で実行される
* 重要な運用コマンドは `docs/OPERATIONS.md` に集約される

配布物のビルドは 2 本のスクリプトが担います。

```bash
./scripts/build.sh              # APK + AAB と manifest を dist/ へ
./build-remote-container.sh     # 配布先ホストで: dev コンテナへビルドを委ねて取り込む
```

`scripts/build.sh` は Flutter がある場所ならどこでも同じように動きます（開発機・CI・dev コンテナ）。`scripts/build-remote-container.sh` は、git も Flutter も置けないホスト（NAS 等）へ手置きして使うブートストラップで、同一ホスト上の dev コンテナへ `git pull` とビルドを委ねます。手順と設定は `docs/OPERATIONS.md`、経緯は `docs/adr/0003-build-in-dev-container.md` にあります。

手順が増えてきたら、README にすべてを書くのではなく、`docs/OPERATIONS.md` と `.claude/skills/operations.md` に分けます。

### 6. ログは起動時を最重要にする

問題が起きたときに後から追えるよう、ログは設計対象として扱います。

特に重要なログ:

* 起動開始・起動完了
* 設定の読み込み元と有効化された非秘密設定
* 外部依存の readiness
* migration / seed の実行結果
* 認証・認可・重要な業務イベント
* 失敗時の原因、相関 ID、復旧のヒント

ログには秘密情報や不要な個人情報を含めません。必要に応じて correlation ID / request ID を使い、複数コンポーネントをまたいで追跡できるようにします。

### 7. i18n と時刻

ユーザー向け文言は、将来の多言語化を前提に扱います。

* 表示文字列をコードへ直接散らばらせず、翻訳キーで管理する
* エラーコードや内部識別子は言語非依存で安定させる
* Domain / Application は特定の表示言語に依存しない
* locale の決定は Presentation 境界で行う
* ユーザー設定、所属地域、リクエスト情報、システム既定値などから表示言語を決める

時刻は内部では常に UTC で保存・交換します。UI 表示や帳票など、ユーザーに見せる境界でのみ、ユーザーの所属地域・タイムゾーンへ変換します。

この方針により、Domain の時刻計算、監査ログ、API、DB、テストを安定させつつ、表示だけを利用者に合わせられます。

## Documentation Policy

`docs/` は、現在の仕様・設計判断・運用手順を置く場所です。目的ごとに分け、同じ内容を複数箇所へ重複して書かないようにします。

| ファイル / ディレクトリ | 役割 | 書くこと | 書かないこと |
|---|---|---|---|
| `docs/ARCHITECTURE.md` | 設計ガイド | レイヤー構成、命名、設計パターン、採用 package の置き場所 | 個別の操作手順 |
| `docs/OPERATIONS.md` | 手順書 | 起動、build、reset、migration、配布コマンド | なぜそうしたかの長い経緯 |
| `docs/DEEP_LINKS.md` | 手順書 | App Links / カスタムスキームの設定と確認 | 設計判断の経緯 |
| `docs/Progress.md` | 進捗 | 未着手、進行中、要判断のタスク | 完了済みタスクの保管 |
| `docs/CHANGELOG.md` | 変更履歴 | 完了した重要変更の短い要約 | 詳細な調査ログ |
| `docs/adr/` | 設計判断 | ADR、採用・却下理由 | 日々の進捗 |
| `docs/history/` | 詳細経緯 | 大きな変更の背景、調査、移行記録 | 軽微な変更 |

判断に迷った場合は、以下で切り分けます。

* 操作手順か？ -> `docs/OPERATIONS.md`
* 設計の説明か？ -> `docs/ARCHITECTURE.md`
* 現在の仕様か？ -> 各 README または該当 docs
* 短い変更要約か？ -> `docs/CHANGELOG.md`
* 背景まで残すべき大きな変更か？ -> `docs/history/`
* 採用・却下を残す設計判断か？ -> `docs/adr/`

## Progress Management

`docs/Progress.md` は、未着手・進行中・要判断のタスクだけを置く場所です。完了した項目は残しません。

推奨フォーマット:

```markdown
| 優先 | # | 概要 | 状態 | 影響度 | 重要度 | 難易度 | 工数 |
|---|---|---|---|---|---|---|---|
| 1 | T1 | 〇〇を実装 | 🚧進行中 | 中 | 小 | 大 | 大 |
```

状態:

* `⬜未着手`
* `🚧進行中`
* `🟡要判断`

影響度・重要度・難易度・工数:

* `大`
* `中`
* `小`

補足が必要なものだけ、表の下に「詳細」として番号付きで記載します。

## Skills

詳細な手順は `.claude/skills/` に分けています。作業前に関連する Skill を読んでください。

| Skill | 用途 |
|---|---|
| `.claude/skills/implement-feature.md` | 機能追加を end-to-end で進める |
| `.claude/skills/design-domain.md` | Entity / Value Object / Domain Service / interface を設計する |
| `.claude/skills/add-usecase.md` | Application のユースケースを追加する |
| `.claude/skills/add-repository.md` | Repository / Gateway と Infrastructure 実装を追加する |
| `.claude/skills/add-ui.md` | UI / Presentation を追加する |
| `.claude/skills/configuration.md` | 設定値、上書き、起動時設定確認を追加する |
| `.claude/skills/operations.md` | build、配布、起動、reset、migration を整備する |
| `.claude/skills/logging.md` | 起動時・重要処理・失敗時ログを設計する |
| `.claude/skills/i18n-time.md` | 国際化、locale、UTC、タイムゾーン変換を扱う |
| `.claude/skills/write-tests.md` | Domain / Application / Infrastructure / Presentation のテストを追加する |
| `.claude/skills/create-pr.md` | PR 作成前の確認を行う |

## Development Workflow

推奨する基本フローです。

1. 変更の目的と最小スコープを決める
2. 関連する `.claude/skills/` を読む
3. 必要なら `docs/Progress.md` にタスクを追加する
4. Domain の語彙・不変条件・interface を先に整理する
5. Application の UseCase を作る
6. Infrastructure の adapter / repository / gateway を実装する
7. Presentation から UseCase を呼び出す
8. 設定、ログ、i18n、時刻、運用に影響があれば docs / skills に沿って更新する
9. テスト・静的解析・フォーマットを実行する
10. 完了した Progress は削除し、重要なら CHANGELOG / history / ADR に移す

## Testing Policy

テストは、外側からだけでなく内側のルールを直接確認します。

優先順位:

1. **Domain tests**: 不変条件、Value Object、Entity、Domain Service、Policy
2. **Application tests**: UseCase、トランザクション境界、Domain error、adapter failure
3. **Infrastructure tests**: DB、外部 API、mapper、migration
4. **Presentation tests**: loading / empty / error / normal、入力、表示、画面遷移

時刻、乱数、UUID、外部サービスは直接呼ばず、差し替え可能な interface を通します。これにより、テスト時に固定実装や fake を注入できます。

カバレッジの下限は Domain 90% / Application 85% / 全体 80% です。共通のテストダブルは `test/support/` にあります。詳細は `.claude/skills/write-tests.md` を参照してください。

## Quality Gate

規約は文章だけでは守られないので、CI が機械的に検査します。ローカルでも CI でも同じスクリプトが走ります。

```bash
./scripts/ci.sh          # 全検査
./scripts/ci.sh --fast   # APK ビルドを飛ばす（開発中はこれで十分）
```

検査の内訳と失敗時の対処は `docs/OPERATIONS.md`、規約そのものは `docs/ARCHITECTURE.md` にあります。

主なものだけ挙げると:

* `dart format` と `flutter analyze --fatal-infos --fatal-warnings`（info も失敗扱い）
* レイヤー依存方向、レイヤーごとの禁止 import / 禁止型、Domain での `DateTime.now()` / `print` / `debugPrint`、Domain 型の `ChangeNotifier` 継承と public setter — `tool/check_architecture.dart` が Analyzer の AST で検査します（文字列検索ではありません）
* `pubspec.yaml` と実際の import の突き合わせ — `tool/check_dependencies.dart`
* カバレッジ下限 — `tool/check_coverage.dart`
* `flutter build apk --debug`

検査ツール自体も `test/tool/` でテストしています。各ルールについて、違反を含むフィクスチャで非ゼロ終了することを確認しているので、「あるのに効いていない検査」にはなりません。

## Naming and Anti-patterns

名前は、実装都合ではなくドメイン語彙を優先します。

避けたい名前:

* `Helper`
* `Util`
* `Manager`
* `Common`
* `Misc`

これらの名前が必要に見える場合は、責務が曖昧になっている可能性があります。何を表すのか、どの文脈の概念なのかを見直してください。

避けたい実装:

* UI から Repository 実装を直接生成する
* Domain が UI / DB / HTTP / JSON に依存する
* Application に表示文言や画面都合が入る
* Infrastructure に業務ルールが入る
* 設定値をあちこちで直接読む
* 文字列メソッド名などによる過度な動的呼び出し
* 例外を握りつぶしてログも出さない

## Fork Customisation

アプリ名、package、Android namespace / applicationId、launcher icon、debug keystore、README の表示名など、fork 時に変えるべき項目は `docs/CUSTOMISATION.md` にまとめています。

`CLAUDE.md` や `.claude/skills/` はエージェント作業のためのルールです。アプリの identity 変更は、必ず `docs/CUSTOMISATION.md` を優先してください。
