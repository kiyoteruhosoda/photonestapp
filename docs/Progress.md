# Progress

進行中・未着手タスクのみを管理する（完了したら本ファイルから削除し、必要なら `CHANGELOG.md` / `history/` へ移す）。


- 状態: ⬜未着手 / 🚧進行中 / 🟡要判断
- 影響度・重要度・難易度・工数: 大 / 中 / 小
- バックログは「優先」列の昇順（1 が最優先）。

## バックログ

| 優先 | # | 概要 | 状態 | 影響度 | 重要度 | 難易度 | 工数 |
|---|---|---|---|---|---|---|---|
| 1 | 6 | `applicationId` をテンプレートの `com.example.flutterbase` から実 ID へ変更する（`com.example.*` は Play Console が拒否） | 🟡要判断 | 大 | 大 | 小 | 小 |
| 2 | 1 | App Link のホストを実ドメインに差し替え、`assetlinks.json` を配信する | 🟡要判断 | 大 | 中 | 小 | 小 |


## 詳細

### 6. `applicationId` の変更

`android/app/build.gradle` が `com.example.flutterbase` のままで、Kotlin パッケージも
テンプレートのまま。`pubspec.yaml` の `name` / `description` も `flutterbase` の
ままで、Dart の import はすべて `package:flutterbase/...` を指している。
`scripts/rename_app.sh` が Dart パッケージ名・import・Android パッケージを
まとめて書き換えるので、実 ID が決まれば 1 回の実行で揃う
（`description` だけは手で直す）。

**要判断**: 実 ID はプロダクトオーナーが所有ドメインから決める必要があり、
コード側では決められない（一度 Play Console に上げた ID は変更不可）。
決まり次第 `./scripts/rename_app.sh <実ID>` を実行するだけで完了する。
候補の考え方: 所有ドメインの逆順 + アプリ名（例: 所有ドメインが
`example.com` なら `com.example.photonest`）。

2026-08-08 プロダクトオーナー確認: 所有ドメイン未定のため保留継続。
ドメイン決定が判断の前提（#1 と同時に決める）。

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

**要判断**: 実際に配信に使うドメイン（PhotoNest サーバーを公開しているホスト等）と、
`assetlinks.json` に入れる署名フィンガープリント（release 鍵）が決まらないと
着手できない。ドメインが決まれば上記 1〜3 は `docs/DEEP_LINKS.md` の手順どおりで
工数小。#6 の `applicationId` 決定と同時に決めるのが望ましい
（`assetlinks.json` は `package_name` に実 ID を含むため）。

2026-08-08 プロダクトオーナー確認: 所有ドメイン未定のため保留継続。
