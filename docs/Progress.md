# Progress

進行中・未着手タスクのみを管理する（完了したら本ファイルから削除し、必要なら `CHANGELOG.md` / `history/` へ移す）。


- 状態: ⬜未着手 / 🚧進行中 / 🟡要判断
- 影響度・重要度・難易度・工数: 大 / 中 / 小
- バックログは「優先」列の昇順（1 が最優先）。

## バックログ

| 優先 | # | 概要 | 状態 | 影響度 | 重要度 | 難易度 | 工数 |
|---|---|---|---|---|---|---|---|
| 1 | 20 | 自動アップロードが従量課金回線でも走る（Wi-Fi 限定の設定がない） | ⬜未着手 | 大 | 大 | 小 | 小 |
| 2 | 6 | `applicationId` をテンプレートの `com.example.flutterbase` から実 ID へ変更する（`com.example.*` は Play Console が拒否） | 🟡要判断 | 大 | 大 | 小 | 小 |
| 3 | 1 | App Link のホストを実ドメインに差し替え、`assetlinks.json` を配信する | 🟡要判断 | 大 | 中 | 小 | 小 |
| 4 | 21 | ライブラリ全体を時系列で見る画面がない（閲覧はアルバム経由のみ） | ⬜未着手 | 大 | 大 | 中 | 大 |
| 5 | 22 | 全画面ビューアで前後の写真へ移動できず、原本も見られない | ⬜未着手 | 中 | 中 | 小 | 中 |
| 6 | 23 | アップロードの進捗・失敗の再試行導線がない | ⬜未着手 | 中 | 中 | 中 | 中 |
| 7 | 24 | iOS 版がない（`ios/` ディレクトリごと存在しない） | 🟡要判断 | 大 | 中 | 大 | 大 |


## 詳細

### 20. 自動アップロードを Wi-Fi 限定にできない

`workmanager_background_sync_scheduler.dart` の制約は
`networkType: NetworkType.connected` ＋ `requiresBatteryNotLow: true` で、
**回線が従量課金かどうかを見ていない**。フォアグラウンド側の
`SyncNewPhotosUseCase` は接続種別をそもそも参照しない。
`AutoUploadSettingsRepository` にも on/off しか無く、ユーザーが
「Wi-Fi のときだけ」を選ぶ手段がない。

写真・動画の原本をまとめて上げる機能なので、モバイル回線で走ると
通信量が一気に溶ける。バックアップアプリとしては既定で Wi-Fi 限定に
するのが期待値に近い。

対応: 設定に「Wi-Fi 接続時のみアップロード」（既定 ON）を足し、
WorkManager 側は `NetworkType.unmetered`、フォアグラウンド側は
接続種別を返すポートを新設して同じ判定を通す。設定画面のトグルと
l10n キー（en / ja）も要る。

### 21. ライブラリ全体を時系列で見る画面がない

タブは「アルバム / アップロード / 設定」の 3 つで、写真を見る導線は
アルバム詳細だけ。サーバー側には `GET /api/media`（撮影日時降順・
種別／タグ／期間／フリーテキスト／お気に入りの絞り込み付き）があるのに、
アプリからは呼んでいない。アルバムに入れていない写真はアプリから
一切見られない。

「サーバーの写真閲覧クライアント」（CLAUDE.md のプロジェクト定義）と
名乗るうえで一番大きい欠落。アルバムタブの隣に写真タブを足し、
`GET /api/media` のページングに載せるのが最小構成。
絞り込みは後追いでよい。

### 22. 全画面ビューアの操作が足りない

`album_detail_page.dart` の `_showFullImage` は 2048px のサムネイルを
`InteractiveViewer` に載せてタップで閉じるだけ。

- 前後の写真へスワイプで移動できない（毎回閉じてグリッドから選び直す）。
- 表示されるのは 2048px のサムネイルで、原本を見る／保存する導線がない。
- お気に入り・タグなど、サーバー側にある操作へつながっていない。

まず `PageView` でアルバム内の前後移動を入れる。原本は
`POST /api/media/{id}/original-url` の署名付き URL が使えるので、
「原本を表示」「端末に保存」を足すかは別途判断する。

Web 側にも前後移動がない（photonest の Progress U10）ので、
挙動を揃えて決める。

### 23. アップロードの進捗・再試行が見えない

`UploadTab` と通知一覧は「何件成功・何件失敗」の結果を出すが、
アップロード中の進捗（何件中何件目・転送量）と、失敗した個別の写真を
選んで再試行する導線がない。サーバー側のアップロードは単発 multipart で
再開もできない（photonest の Progress F11）ので、大きい動画が失敗すると
次のパスを待つしかない。

まずアプリ側だけで閉じる範囲として、`UploadPhotosResult` の失敗リストを
永続化して一覧に出し、手動再試行を足す。

### 24. iOS 版がない

`ios/` ディレクトリが存在せず、Android 専用。`photo_manager`・
`workmanager`・`flutter_secure_storage`・`video_player` はいずれも
iOS を持っているので、プラットフォーム追加自体は可能。

**要判断**: iOS の自動バックアップは Background Fetch の制約が Android と
まったく違い（起動タイミングを OS が決める・実行時間が短い）、
`SyncNewPhotosUseCase` の呼び出し方を iOS 向けに設計し直す必要がある。
Apple Developer Program の費用と配布経路も前提になるため、
やるかどうかをプロダクトオーナーが決めてから着手する。

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
