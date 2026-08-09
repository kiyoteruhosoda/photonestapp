# CLAUDE.md

このファイルは、プロジェクト固有ルールの最小ルート指示です。詳細な手順は `.claude/skills/` に分けます。

## プロジェクト

- 名称: PhotoNest
- 種別: Flutter モバイルアプリ（PhotoNest サーバーの写真閲覧・バックアップクライアント）
- 主要スタック: Flutter / Dart
- 仕様・設計の参照先: `docs/`

## プロダクトの範囲（最優先の制約）

**このアプリは「撮った写真を確実に保存する」「保存した写真を見る」ためのもの。**
家族が使う道具であって、機能の展示場ではない。判断に迷ったらこの 2 つに戻る。
判断の経緯は `docs/adr/0010-product-scope-save-and-view.md`
（出所はサーバー側 `photonest` の ADR-0028）。

### 機能を足すときの制約

1. **既定は「作らない」。** 足りない機能を見つけたことは、作る理由にならない。
   「保存する」「見る」のどちらかが**実際に困っている**ことを先に示す。
   他の写真アプリにあるから、サーバーが API を持っているから、は理由にならない。
2. **利用者に届くところまでを 1 単位にする。** エンティティのフィールド・
   リポジトリ・ローカル DB の列だけを先に入れない。画面に出ないなら要らない。
   **コードとデータだけが増えて利用者が置き去りになる**のが、最も起きやすい失敗。
3. **入れないと決めたら ADR に残す。** 理由が残っていないと、次のレビューで
   同じものが「欠落」として再び挙がる（前例: `0005` 通知ボタン、
   `0008` iOS 版、`0009` 撮影パラメータ）。
4. **タブと画面を増やすより、今ある導線を短くする方を先に考える。**
   写真を見るまでのタップ数が、このアプリの品質そのもの。

バグ修正・性能・オフライン耐性・失敗の可視化はこの制約の対象外（むしろ推奨）。
制約が掛かるのは**利用者から見た機能**を増やす変更。

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
