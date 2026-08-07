# CLAUDE.md

このファイルは、プロジェクト固有ルールを置くための最小テンプレートです。言語・フレームワーク・業務仕様はプレースホルダーとして扱い、詳細な手順は `.claude/skills/` に分けます。

## プロジェクト

- 名称: `<PROJECT_NAME>`
- 種別: `<PROJECT_TYPE>`
- 主要スタック: `<LANGUAGE_OR_STACK>`
- 仕様・設計の参照先: `docs/`

## 基本方針

1. 何もしなくても最小起動でき、まずログイン画面または初期画面が表示される状態を保つ。
2. DDD + OOP + SOLID + DI を意識し、責務と依存方向を明確にする。
3. デフォルト設定だけで開発環境を動かせるようにし、環境変数や永続設定で上書き可能にする。
4. Compose 等で必要コンポーネントをまとめて起動できるようにする。
5. Build、配布物作成、起動、reset、migration をできるだけスクリプト化する。
6. 起動時・重要処理・失敗時は、後から追跡できるログを必ず出す。
7. i18n を前提に、ユーザー向け文言は翻訳キーで管理する。
8. 時刻は内部では常に UTC で扱い、UI 表示時にユーザーの所属地域・タイムゾーンへ変換する。

## ドキュメント運用

`docs/` は現在の仕様・設計判断・運用手順の置き場です。重複して書かず、迷ったら以下へ分けます。

- `docs/ARCHITECTURE.md`: 設計・レイヤー・命名規則
- `docs/OPERATIONS.md`: 操作手順・コマンド
- `docs/Progress.md`: 未着手・進行中・要判断のタスクのみ
- `docs/CHANGELOG.md`: 完了した重要変更の短い要約
- `docs/adr/`: 設計判断（`NNNN-*.md`）
- `docs/history/`: 要約だけでは追えない大きな変更の経緯

## 作業フロー

1. 開始前に関連する `.claude/skills/` を読む。
2. 必要なら `docs/Progress.md` に作業項目を追加する。
3. 小さく実装し、Domain / Application / Infrastructure / Presentation の責務を混ぜない。
4. 設定・起動・ログ・運用に影響する変更は該当 docs に反映する。
5. 完了した作業は `docs/Progress.md` から消し、重要なら `docs/CHANGELOG.md` または `docs/history/` に移す。
6. テスト・静的解析・フォーマットなど、プロジェクトで定義されたチェックを実行する。

## Skills

詳細手順はここへ分離します。

- `.claude/skills/implement-feature.md`: 機能追加
- `.claude/skills/design-domain.md`: ドメイン設計
- `.claude/skills/add-usecase.md`: ユースケース追加
- `.claude/skills/add-repository.md`: 永続化境界追加
- `.claude/skills/add-ui.md`: UI 追加
- `.claude/skills/configuration.md`: 設定追加・上書き
- `.claude/skills/operations.md`: Build / 配布 / 起動 / reset / migration
- `.claude/skills/logging.md`: ログ設計・追加
- `.claude/skills/i18n-time.md`: 国際化・時刻設計
- `.claude/skills/write-tests.md`: テスト追加
- `.claude/skills/create-pr.md`: PR 作成
