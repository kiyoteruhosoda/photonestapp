# Progress

進行中・未着手タスクのみを管理する（完了したら本ファイルから削除し、必要なら `CHANGELOG.md` / `history/` へ移す）。


- 状態: ⬜未着手 / 🚧進行中 / 🟡要判断
- 影響度・重要度・難易度・工数: 大 / 中 / 小
- バックログは「優先」列の昇順（1 が最優先）。

## バックログ

| 優先 | # | 概要 | 状態 | 影響度 | 重要度 | 難易度 | 工数 |
|---|---|---|---|---|---|---|---|
| 1 | 1 | App Link のホストを実ドメインに差し替え、`assetlinks.json` を配信する | ⬜未着手 | 大 | 中 | 小 | 小 |
| 2 | 2 | ViewModel + `AppScope` を Riverpod に寄せるか決める | 🟡要判断 | 中 | 中 | 中 | 大 |


## 詳細

### 1. App Link のホストを実ドメインに差し替える

テンプレートの既定値は `flutterbase.example.com` で、実在しません。
そのままでは `autoVerify` が失敗し、リンクはブラウザで開きます
（アプリの起動やアプリ内遷移は壊れません）。

fork 後に必要な作業は 3 つで、いずれも `docs/DEEP_LINKS.md` に手順があります。

1. `lib/shared/app_config.dart` の `appLinkHost` を実ドメインにする。
2. `android/app/src/main/AndroidManifest.xml` の `android:host` を合わせる。
3. `docs/deep_links/assetlinks.json` に署名フィンガープリントを入れ、
   `https://<host>/.well-known/assetlinks.json` として配信する。

テンプレート側で決められるのはここまでなので、作業自体は fork 側に残します。

### 2. ViewModel + `AppScope` を Riverpod に寄せるか決める

現在、状態管理の入り口が 2 つあります。

- 既存のテーマ・言語・デバッグ設定・About・Logs: `get_it` + `ChangeNotifier`
  + `AppScope`（`InheritedWidget`）
- ブックマーク機能: `flutter_riverpod`（provider は Presentation に宣言し、
  合成ルートが `overrideWithValue` で実体を注入）

役割は同じ（合成ルートが注入し、Presentation は契約だけを見る）で、
どちらも `tool/check_architecture.dart` を通ります。ただしテンプレートとして
「どちらで書けばいいか」が一目で決まらないのは弱点です。

Riverpod に統一する場合、ViewModel 5 本とそのテスト、`AppScope`、
テストハーネスが影響範囲です。既存コードが動いている以上、急ぎではありません。
経緯は `docs/adr/0002-starter-stack.md`。
