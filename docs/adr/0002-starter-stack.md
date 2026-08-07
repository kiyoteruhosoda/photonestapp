# 0002. 初期スタックを確定し、テンプレート内で実際に使う

- 状態: 採用
- 日付: 2026-08-03

## 文脈

本テンプレートは長らく、`go_router` / `flutter_riverpod` / `sqflite` /
`path` / `url_launcher` / `equatable` / `riverpod_annotation` を
`pubspec.yaml` に宣言しつつ、`lib/` からは一度も import していませんでした
（`dependency_policy.reserved` に「意図的な予約」として列挙）。

予約は「未使用の依存」を CI が見逃さないようにする仕組みとしては機能しますが、
テンプレートとしては次の問題が残ります。

- fork した開発者は、その package を**このアーキテクチャの中でどう置くか**
  を自分で決めることになります。`sqflite` は Infrastructure なのか、
  Riverpod の provider はどのレイヤーに置くのか、といった判断が毎回発生します。
- 宣言だけの依存はバージョンが上がっても誰も気づきません。実際に使われて
  いなければ、テストも CI も壊れないからです。

## 決定

**採用する 5 つを実際に使い、採用しない 2 つを削除します。**

| package | 扱い | 置き場所 |
|---|---|---|
| `go_router` | 採用 | `lib/app/bootstrap/app_router.dart`（合成ルート）。画面はパス定数のみを参照 |
| `flutter_riverpod` | 採用 | `lib/presentation/providers/`。実体の注入は `lib/app/di/provider_overrides.dart` |
| `sqflite` | 採用 | `lib/infrastructure/database/` と `lib/infrastructure/repositories/` |
| `path` | 採用 | `lib/infrastructure/database/app_database.dart`（DB ファイルパス組み立て） |
| `url_launcher` | 採用 | `lib/infrastructure/links/`。`ExternalLinkLauncher` ポートの背後 |
| `equatable` | 不採用 | — |
| `riverpod_annotation` | 不採用（`riverpod_generator` も削除） | — |

これらを実際に使う題材として、ブックマーク機能をテンプレートに含めます。
一覧・詳細・追加・削除・外部リンク起動という最小構成で、
Domain / Application / Infrastructure / Presentation の 4 層すべてと、
App Links の受け口までを 1 本の線でつないでいます。

`dependency_policy.reserved` の仕組み自体は残します（空リスト）。
今後、実装より先に依存を宣言したくなった場合の逃げ道として有効です。

## 理由

### `equatable` を採用しない

- 値の等価性は `==` と `hashCode` を数行書けば済み、その数行は
  「この型はエンティティか値オブジェクトか」を読む側に明示します。
  `Bookmark` は id だけで比較（エンティティ）、`BookmarkDraft` は
  全フィールドで比較（値オブジェクト）です。`equatable` の
  `props` に何を並べるかは同じ判断ですが、意図は伝わりにくくなります。
- Domain を pure Dart に保つ方針と、外部パッケージへの継承（`extends
  Equatable`）は相性が良くありません。Domain の基底クラスが
  サードパーティになります。

### `riverpod_annotation` / `riverpod_generator` を採用しない

- コード生成が入ると、`pubspec.yaml` を触るたびに
  `dart run build_runner build` が必要になり、`scripts/ci.sh` にも
  「生成物がコミット済みか」の検査が増えます。テンプレートの
  「clone してすぐ動く」性質を優先します。
- 手書きの provider は 5 行程度で、`Provider` / `AsyncNotifierProvider` /
  `FutureProvider.family` の使い分けがそのままコードに出ます。
  生成物の裏に隠れるより、テンプレートとしては読みやすい。
- 生成を後から導入することは可能です。その場合はこの ADR を置き換えてください。

### `url_launcher` をポートの背後に置く

`url_launcher` は Presentation から直接呼んでもコンパイルは通りますが、
プラットフォームチャネルを叩く以上は Infrastructure の仕事です。
`tool/check_architecture.dart` の `_ioPackages` に追加し、
Infrastructure 以外からの import を CI で落とすようにしました。
おかげで `OpenBookmarkUseCase` はプラットフォームなしでテストできます。

### Riverpod と `get_it` の併存

既存の ViewModel は `get_it` + `ChangeNotifier` + `AppScope` で配線されており、
これは残します。Riverpod は新しいブックマーク機能にのみ使います。

両者の役割は同じ「合成ルートが実体を注入し、Presentation は契約だけを見る」です。
Riverpod 側では、provider を Presentation に宣言して本体は
`UnimplementedError` を投げ、`lib/app/di/provider_overrides.dart` が
`overrideWithValue` で実体を差します。読まずに使うと起動時に落ちるので、
注入忘れが黙って通ることはありません。

テンプレートとしては、どちらか一方に寄せる余地があります。ここでは
「既存コードを壊さずに Riverpod の置き場所を示す」ことを優先しました。

## 結果

- `dependency_policy.reserved` は空になりました。宣言されている
  ランタイム依存はすべて `lib/` から使われています。
- ルーティングが `Navigator.pushNamed` から `go_router` に変わりました。
  画面は `AppRoutes` の定数を `context.push` に渡します。
- 起動時に SQLite を開くようになりました（`InfrastructureModule.create`）。
  ホスト上のテストは `sqflite_common_ffi` で同じコードを動かします。
- App Links の受け口ができました。詳細は `docs/DEEP_LINKS.md`。
