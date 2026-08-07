# 0001. レイヤーを単一パッケージで保持し、依存方向は静的検査で強制する

- 状態: 採用
- 日付: 2026-08-03

## 文脈

DDD のレイヤー依存方向（presentation → application → domain、
infrastructure → application/domain）を破らせないための強制手段として、
主に 2 つの選択肢があります。

1. **マルチパッケージ**: `packages/domain`・`packages/application` …のように
   レイヤーごとに Dart パッケージを切り、各 `pubspec.yaml` の
   `dependencies` で依存方向を宣言する。
2. **単一パッケージ + 静的検査**: `lib/<layer>/` のディレクトリをレイヤーとし、
   import 方向を CI の検査ツールで強制する。

1 の方が強力です。Dart のパッケージ解決そのものが依存方向を保証するため、
違反は「CI が落ちる」ではなく「そもそもコンパイルできない」になります。

## 決定

**2 を採用します。** レイヤーは `lib/` 直下のディレクトリとして表現し、
依存方向は `tool/check_architecture.dart`（Analyzer の AST を走査）と
`tool/check_dependencies.dart` が強制します。

## 理由

- 本リポジトリは **テンプレート** であり、fork 直後の開発者が最初に触るのは
  「機能を 1 つ足す」作業です。マルチパッケージにすると、その最初の一歩に
  melos などのワークスペース管理・パッケージ間バージョン同期・
  IDE 設定が乗ります。テンプレートの初期コストとして重すぎます。
- Flutter のツールチェインは単一パッケージ前提の部分が残ります。
  `flutter test --coverage` は 1 パッケージ分の `lcov.info` しか出さないため、
  レイヤー別・全体のカバレッジ閾値を 1 コマンドで検査する仕組みが壊れます。
  マルチパッケージでは各パッケージのレポートを結合する層が別途必要です。
- AST 検査は「パッケージ境界では表現できない規約」も同時に見られます。
  Domain での `DateTime.now()`、Domain エンティティの public setter、
  Infrastructure 以外での `File` / `SharedPreferences` の使用などは、
  pubspec の依存関係だけでは検出できません。どちらにせよ AST 検査は必要で、
  そこにレイヤー方向も載せる方が仕組みが 1 つで済みます。
- 違反の検出タイミングの差は実運用では小さい。単一パッケージでも
  `./scripts/ci.sh` はローカルでそのまま走り、push 前に同じ結果が出ます。

## 結果

- レイヤー違反はコンパイルエラーではなく CI エラーになります。
  検査を無効化すれば規約は破れます。これは受け入れたトレードオフです。
- 検査ツール自体がテスト対象になります。
  `test/tool/check_architecture_test.dart` が、各ルールについて
  「違反を含むフィクスチャで非ゼロ終了すること」を確認します。
  ルールを追加したら、対応するフィクスチャも追加してください。
- `tool/check_dependencies.dart` は `packages/` ディレクトリが現れたら
  パッケージ間の依存方向も検査するように書いてあります。
  将来 1 に移行する場合、検査側の作り直しは不要です。

## 将来マルチパッケージへ移行する場合

1. `packages/<name>_domain`・`<name>_application` … を作り、
   `lib/<layer>/` の中身を移す。
2. 各 `pubspec.yaml` の `dependencies` を本書の依存方向どおりに書く
   （domain は他レイヤーへ依存しない、application は domain のみ、など）。
3. ルートの `pubspec.yaml` から各パッケージを `path` 依存で参照する。
4. `tool/check_dependencies.dart` が `packages/` を検出して
   パッケージ間方向の検査を自動で有効化します。追加作業は不要です。
5. `tool/check_coverage.dart` の閾値パスを、結合後の lcov のパス形式に
   合わせて更新してください。
