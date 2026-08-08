# Architecture

このプロジェクトは DDD + OOP + SOLID + DI を前提とした Flutter アプリのテンプレートです。
本書は「どのコードがどこに属するか」と「その規約を CI がどう強制するか」を定義します。

規約の一覧は `.claude/rules/architecture.md`、実際の検査は
`tool/check_architecture.dart` と `tool/check_dependencies.dart` にあります。
**本書と検査コードが食い違った場合、検査コードが正**です（CI が落ちるのはそちらなので）。

## レイヤー

`lib/` 直下のディレクトリがそのままレイヤーです。

| ディレクトリ | 役割 | Flutter 依存 |
|---|---|---|
| `lib/domain/` | エンティティ・値オブジェクト・ドメインエラー・リポジトリ *インターフェース* | 不可 |
| `lib/application/` | ユースケース、外向きポート (`ports/`) | 不可 |
| `lib/infrastructure/` | 外部システムのアダプター（永続化・プラットフォーム・ネットワーク） | 可 |
| `lib/presentation/` | 画面・ウィジェット・Riverpod provider / Notifier・テーマ・i18n | 可 |
| `lib/app/` | 合成ルート（DI・起動・ルーティング）。`lib/main.dart` も含む | 可 |
| `lib/shared/` | フレームワーク非依存の定数のみ（`AppConfig` / `BuildInfo`） | 不可 |

`lib/shared/` は「どのレイヤーにも属さない定数置き場」であり、**他のどのレイヤーにも依存できません**。
迷ったら shared ではなく、そのコードを必要とするレイヤーに置いてください。

## 依存方向

矢印は常に内向きです。

```
        ┌──────────────┐
        │     app      │  合成ルート: 全レイヤーを見てよい唯一の場所
        └──────┬───────┘
               │ 束ねる
   ┌───────────┼───────────┐
   ▼           ▼           ▼
presentation  infrastructure
   │           │
   └─────┬─────┘
         ▼
    application
         ▼
      domain
         ▼
      shared
```

許可される import は次のとおりです（自分自身を含む）。

| from \ to | domain | application | infrastructure | presentation | app | shared |
|---|---|---|---|---|---|---|
| domain | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| application | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| infrastructure | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| presentation | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ |
| app | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| shared | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

**Presentation は `lib/app/` を import できません。** 画面が必要とする
ユースケースは `presentation/providers/` の Riverpod provider として宣言し、
本体は `UnimplementedError` を投げます。合成ルートの
`lib/app/di/provider_overrides.dart` が `overrideWithValue` で実体を差すので、
注入漏れは起動時に必ず失敗します。サービスロケータを画面から直接引く形に
すると矢印が外向きに逆転するため、CI で落ちます。

## CI が拒否するもの

`tool/check_architecture.dart` は Dart Analyzer の **AST** を走査します。
文字列検索ではないので、コメントや文字列リテラル中の一致では発火しません。

| ルール | 内容 |
|---|---|
| `layer-direction` | 上表に反する package import |
| `layer-placement` | どのレイヤーにも属さない `lib/**.dart` |
| `banned-import` | Domain / Application からの Flutter・`dart:io`・`dart:ui` import、Infrastructure 以外からの dio・http・sqflite・shared_preferences・path_provider・package_info_plus・url_launcher などの import |
| `infrastructure-only-type` | Infrastructure 以外での `File` / `Directory` / `HttpClient` / `Dio` / `MethodChannel` / `SharedPreferences` / `Database` などの使用（型注釈・コンストラクタ呼び出し・static アクセス） |
| `concrete-adapter-dependency` | Infrastructure と合成ルート以外での具象アダプター（Repository 実装など）への参照 |
| `domain-clock` | Domain での `DateTime.now()` |
| `domain-console-output` | Domain での `print()` / `debugPrint()` |
| `domain-purity` | Domain 型の `ChangeNotifier` / `ValueNotifier` / `Widget` などからの継承・実装 |
| `domain-public-setter` | Domain 型の public setter、および public な可変フィールド（暗黙の setter を持つため） |

`tool/check_dependencies.dart` は package グラフ側を見ます。

| ルール | 内容 |
|---|---|
| `undeclared-dependency` | `lib/` が import しているのに `pubspec.yaml` に無い package |
| `unused-dependency` | `pubspec.yaml` の `dependencies` にあるのに `lib/` が import していない package |
| `stale-reservation` | `dependency_policy.reserved` の記載が実態と合っていない |
| `package-direction` | `packages/` にレイヤーを分割した場合の、pubspec レベルでの依存方向違反 |

### `dependency_policy.reserved` について

`pubspec.yaml` 末尾の `dependency_policy.reserved` は、「宣言済みだが `lib/` から
未使用」であることを意図的に宣言するためのリストです。ここに無い未使用 package は
CI で落ちます。

**現在このリストは空です。** 宣言しているランタイム依存はすべて `lib/` から
使われています（`docs/adr/0002-starter-stack.md`）。実装より先に依存を宣言したい
場合だけ、ここに追加してください。使い始めたら削除します（使用中の package が
reserved に残っていても CI が落ちます）。

## 初期スタックの置き場所

採用している package と、このアーキテクチャ上の担当レイヤーです。
判断の経緯は `docs/adr/0002-starter-stack.md` にあります。

| package | レイヤー | 置き場所 |
|---|---|---|
| `go_router` | 合成ルート | `lib/app/bootstrap/app_router.dart`。画面は `presentation/navigation/app_routes.dart` の定数だけを参照する |
| `flutter_riverpod` | Presentation | `lib/presentation/providers/`。実体の注入は `lib/app/di/provider_overrides.dart` |
| `get_it` | 合成ルート | `lib/app/di/service_locator.dart` のみ |
| `sqflite` | Infrastructure | `lib/infrastructure/database/`・`lib/infrastructure/repositories/` |
| `path` | Infrastructure | DB ファイルパスの組み立て。純粋な文字列処理なのでレイヤー制限は掛けていない |
| `url_launcher` | Infrastructure | `lib/infrastructure/links/`。`ExternalLinkLauncher` ポートの背後 |
| `shared_preferences` / `path_provider` / `package_info_plus` | Infrastructure | 既存のアダプター群 |
| `http` / `http_parser` | Infrastructure | `lib/infrastructure/api/photonest_api_client.dart` と API リポジトリ群。ベース URL 解決・Bearer 付与・401 時のトークン再発行はクライアントに集約 |
| `connectivity_plus` | Infrastructure | `lib/infrastructure/device/connectivity_plus_network_connection_gateway.dart`。`NetworkConnectionGateway` ポート（Application）の背後。自動アップロードが従量課金回線を避けるための接続種別の取得にだけ使う |
| `photo_manager` | Infrastructure | `lib/infrastructure/device/photo_manager_photo_library_gateway.dart`。`PhotoLibraryGateway` ポート（Application）の背後 |
| `workmanager` | Infrastructure | `lib/infrastructure/background/`。`BackgroundSyncScheduler` ポート（Application）の背後。バックグラウンド側のエントリポイントは `lib/app/background/`（第二の合成ルート） |
| `video_player` | Presentation | `lib/presentation/widgets/ui/video_playback_view.dart`。再生はウィジェットそのもの（テクスチャ描画）なのでポートを切らず Presentation に置く。再生 URL の取得は `MediaPlaybackRepository`（Domain インターフェース + API アダプター）が担う |

`equatable` と `riverpod_annotation`（および `riverpod_generator`）は
採用していません。値の等価性は手書きの `==` / `hashCode`、Riverpod の
provider は手書きで書きます。

### 状態管理は Riverpod に一本化

Presentation の状態はすべて Riverpod で持ちます（ADR 0004）。原則は変わらず
**合成ルートが実体を注入し、Presentation は契約だけを見る** です。

- ユースケースの provider は Presentation に宣言し、本体は
  `UnimplementedError` を投げます。`lib/app/di/provider_overrides.dart` が
  `overrideWithValue` で実体を差すので、注入漏れは起動時に必ず失敗します
  （黙って null にはなりません）。
- 画面状態は `Notifier` / `AsyncNotifier` / `FutureProvider`
  （`presentation/providers/`）。かつての `ChangeNotifier` ViewModel と
  `AppScope`（`InheritedWidget`）は廃止しました。
- go_router の `refreshListenable` は `Listenable` を要求するため、
  セッション変化は合成ルートが `RouterRefreshBridge`（`ChangeNotifier`）に
  変換して渡します。認証ガード自体は `redirect` 内で
  `ProviderScope.containerOf(context)` からセッションを読みます。
- サーバー由来のキャッシュ（アルバム・サムネイル・アップロード候補）は
  `sessionIdentityProvider` を `build` で watch し、ログイン先の変化で
  自動的に破棄されます。

Presentation から `lib/app/` を import することはできません。

## ルーティングとディープリンク

ルート定義は `lib/app/bootstrap/app_router.dart`（合成ルート）、
パス定数は `lib/presentation/navigation/app_routes.dart`（Presentation）です。
画面は後者だけを見ます。

公開する URL のパスとアプリ内ルートのパスは同一です。Android は受け取った
App Link の *パス*を Flutter に渡し、go_router がそれを通常の遷移と同じ
経路で解決します。設定手順は `docs/DEEP_LINKS.md`。

## パッケージ分割について

レイヤーを別 Dart パッケージ（`packages/domain` など）に分割すると、
pubspec レベルでも依存方向を強制できます。本テンプレートは単一パッケージ構成を
採用しました。理由と、将来分割する場合の手順は `docs/adr/0001-single-package-layers.md`
にあります。`tool/check_dependencies.dart` は `packages/` が現れた時点で
自動的にパッケージ間の方向も検査します。

## 命名

- Repository インターフェースは `domain/repositories/` に `<Concept>Repository`。
- その実装は `infrastructure/repositories/` に `<Technology><Concept>Repository`
  （例: `SharedPreferencesThemePreferenceRepository`）。
- 外向きポートは `application/ports/`（例: `AppLogger`）。
- ユースケースは `application/usecases/<feature>/` に `<Verb><Noun>UseCase`。
- `Helper` / `Util` / `Manager` / `Common` は使いません。ドメイン語彙を使ってください。

## テスト方針

`test/` は `lib/` と同じ構造をとります。共通のテストダブルは `test/support/` です。

- `test/support/fakes.dart` — 各 Repository の in-memory 実装。書き込み内容を記録し、
  失敗も注入できます。
- `test/support/recording_app_logger.dart` — `AppLogger` ポートの記録用ダブル。
- `test/support/test_harness.dart` — Riverpod の override 一式 + テーマ +
  i18n を組んだウィジェットテスト用ハーネス（`pumpInScope` /
  `pumpComponent`）。`TestScope.container` から provider の状態を直接
  読み書きできます。

特に次を必ずテストします。

- Domain エンティティの状態遷移、値オブジェクトの不正値
- ユースケースの正常系・異常系
- Repository・外部ポートの呼び出し（記録用ダブルで検証）
- Notifier / provider の状態遷移

### カバレッジ目標

| 範囲 | 下限 |
|---|---|
| `lib/domain/` | 90% |
| `lib/application/` | 85% |
| 全体 | 80% |

`tool/check_coverage.dart` が `coverage/lcov.info` を読んで強制します。

`flutter test --coverage` は「テストから到達したライブラリ」しか計測しないため、
どこからも import されていないファイルはレポートに現れず、全体の数字が実態より
高く出ます。これを防ぐために `test/coverage_surface_test.dart` が `lib/` の全
ライブラリを import しています。`lib/` にファイルを追加したらこのファイルにも
import を足してください（足し忘れるとテストが落ち、追加すべき行を教えてくれます）。

## 参照

- 操作手順・コマンド: `docs/OPERATIONS.md`
- ディープリンク（App Links）の設定: `docs/DEEP_LINKS.md`
- 設計判断の記録: `docs/adr/`
- 完了した変更の要約: `docs/CHANGELOG.md`
