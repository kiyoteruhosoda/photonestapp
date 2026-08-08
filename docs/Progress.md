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
| 3 | 22 | 全画面ビューアで前後の写真へ移動できず、原本も見られない | ⬜未着手 | 中 | 中 | 小 | 中 |
| 4 | 23 | アップロードの進捗が枚数単位で、失敗の詳細がアプリ再起動で消える | ⬜未着手 | 小 | 中 | 中 | 中 |


## 詳細

### 22. 全画面ビューアの操作が足りない

`album_detail_page.dart` の `_showFullImage` は 2048px のサムネイルを
`InteractiveViewer` に載せてタップで閉じるだけ。

- 前後の写真へスワイプで移動できない（毎回閉じてグリッドから選び直す）。
- 表示されるのは 2048px のサムネイルで、原本を見る／保存する導線がない。
- お気に入り・タグなど、サーバー側にある操作へつながっていない。

まず `PageView` でアルバム内の前後移動を入れる。原本は
`POST /api/media/{id}/original-url` の署名付き URL が使えるので、
「原本を表示」「端末に保存」を足すかは別途判断する。

写真タブ（旧 #21）でも同じビューアを開くので、直すと両方に効く。

Web 側にも前後移動がない（photonest の Progress U10）ので、
挙動を揃えて決める。

### 23. アップロードの進捗が枚数単位で、失敗の詳細が残らない

手動アップロードの基本的な導線は揃っている。`_buildRunControls` が
「何枚中何枚目」の `LinearProgressIndicator` と中断ボタンを出し、
`_FailureSummary` → `_showFailures` が失敗したファイルと理由を一覧し、
`_uploadSelected` は成功した ID だけを `_selected` から外すので、
失敗分は選択されたまま残りボタンを押せば再試行になる。自動パスも
`markUploaded` を成功時にしか呼ばないため、失敗した写真は次のパスで
自然に再試行される。残っているのは以下の 3 点。

**(a) 進捗が枚数単位で、1 ファイル内のバイト進捗がない**

`UploadPhotosUseCase.execute` の `onProgress` は写真が 1 枚片付くたびに
`(completed, total)` を返す。サーバー側が単発 multipart で再開もできない
（photonest の Progress F11）ため、大きい動画を 1 本上げている間は
バーが止まったまま数分動かず、固まったように見える。

**(b) 失敗一覧がアプリ再起動で消える**

`UploadRunNotifier` はメモリ上の `Notifier` で、失敗の詳細は
`UploadRunState.lastResult` にしか無い。アプリを閉じるとどのファイルが
なぜ落ちたのか分からなくなる。

**(c) 自動パスの失敗はファイルが特定できない**

`RecordBackupResultUseCase` は `uploadedCount` / `failedCount` の件数だけを
`backup_notifications` に記録する。バックグラウンドで落ちた写真は
次のパスで再試行されるので取りこぼしはないが、繰り返し失敗し続ける写真
（未対応フォーマット等）にユーザーが気付けない。

対応: (a) はアップロードポートに進捗コールバックを足す。(b)(c) は失敗を
sqflite に永続化し、通知の詳細から辿れるようにする。

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
