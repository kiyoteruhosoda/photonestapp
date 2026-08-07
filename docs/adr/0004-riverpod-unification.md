# 0004: 状態管理を Riverpod に一本化する

- 日付: 2026-08-07
- 状態: 採用

## 文脈

テンプレートには状態管理の入り口が 2 つあった。

- テーマ・言語・デバッグ設定・About・Logs・セッション:
  `get_it` + `ChangeNotifier` ViewModel + `AppScope`（`InheritedWidget`）
- ブックマーク・アルバム・アップロード: `flutter_riverpod`
  （provider を Presentation に宣言し、合成ルートが `overrideWithValue` で注入）

役割は同じ（合成ルートが注入し、Presentation は契約だけを見る）で、どちらも
`tool/check_architecture.dart` を通るが、「新しいコードをどちらで書くか」が
一目で決まらないことが並存の最大のコストだった（旧 Progress T2）。

## 決定

Presentation の状態管理を **Riverpod に一本化**する。

- `ChangeNotifier` ViewModel 6 本（Theme / Language / DebugSettings /
  About / Debug / Session）を `Notifier` / `FutureProvider` に置き換え、
  `AppScope` を削除する。
- `get_it` は合成ルートの配線（Infrastructure の組み立てとユースケース登録）
  専用として残す。Presentation からは見えない。
- go_router の `refreshListenable` は `Listenable` を要求するため、
  セッション変化は合成ルートの `RouterRefreshBridge`（`ChangeNotifier`）に
  変換して渡す。認証ガードは `redirect` 内で
  `ProviderScope.containerOf(context)` からセッションを読む。
- サーバー由来のキャッシュは `sessionIdentityProvider` を `build` で watch
  し、ログイン先（サーバー / アカウント）の変化で自動的に破棄する。
  従来の `SessionCacheReset` ウィジェットはこれで不要になり削除。
- Riverpod 3 の既定の自動リトライは無効化する（`ProviderScope(retry:)`）。
  エラー表示に明示的な「再試行」を置く方針と競合するため。

## 影響

- 影響範囲: ViewModel 全部とそのテスト、`AppScope`、テストハーネス、
  ViewModel を読む全画面、`app_widget` / `app_router`。
- テストは `TestScope.container`（`ProviderContainer`）経由で状態を
  読み書きする。ハーネスの `pumpInScope` / `pumpComponent` の使い方は不変。
- `riverpod_annotation` / `riverpod_generator` は引き続き採用しない
  （ADR 0002 のコード生成なし方針を維持）。

## 却下した代替案

- **現状維持（2 方式並存 + 線引きの明文化）**: 移行コストはゼロだが
  「どちらで書くか」の判断コストが残り続ける。テンプレートとしての
  分かりやすさを優先して却下。
- **AppScope に統一**: autoDispose / family / provider 単位のテスト差し替え
  など、既に Riverpod 側で使っている機能を手放すことになるため却下。
