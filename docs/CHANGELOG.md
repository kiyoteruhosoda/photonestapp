# Changelog

完了した重要な変更の短い要約を、新しいものから並べます。
詳しい経緯が必要なものは `docs/history/`、設計判断は `docs/adr/` にあります。

## 2026-08-10 — アルバムをアプリで作り、写真を入れられるようにした

- Progress A6。できたのは一覧と詳細の閲覧だけで、アルバムを作る・名前を直す・
  写真を入れるにはどれも Web の管理画面へ行く必要があった。ADR-0010 は A6 を
  「見る」の内側と読んでいる（見たい写真に辿り着く手段だから）。
  **サーバー側の変更は無い**（`POST /api/albums` と `PUT /api/albums/{id}` は
  既にあった）。

### 3 つの導線

- **アルバムタブの `+`** — 名前と説明を入れて作る。作成後は一覧が自分で
  読み直すので、引っ張って更新する必要は無い。
- **アルバム詳細の鉛筆** — 名前と説明を直す。ヘッダーの表示だけ差し替えるので、
  スクロール済みのメディアは読み直さない。送るのは名前と説明だけで、収録
  メディアには触れない。
- **詳細ビューアの「アルバムへ追加」** — シートでアルバムを選ぶか、その場で
  新しいアルバムを作る。新規作成はその写真を入れた状態で 1 リクエスト
  （空のアルバムが残る隙間を作らない）。

### 追加は「全置換」で送る

- サーバーに追加専用の API は無く、`PUT /api/albums/{id}` の `mediaIds` が
  収録メディアの全置換。したがって 1 枚足すには、現在の ID を読んでから
  1 つ足した配列を送る。読み出しは 500 件ずつのページ指定で、往復は
  `ceil(件数/500) + 1` 回。**追加専用エンドポイントはサーバーへ足していない**
  （判断は `docs/adr/0013-album-media-is-replaced-not-appended.md`）。
- 全置換である以上、ID を読み損ねると写真が消える。収録 ID が無い応答も、
  読めない ID が 1 つでも混じった応答も失敗として扱う。
- 既に入っている写真は「追加しました」ではなく「すでに入っています」と言い、
  **書き込みを 1 回も出さない**。同じ集合を送り返すと、読んだ直後に別の端末が
  足した／外した分を巻き戻してしまう。
- 作成・改名の後で一覧を読み直さない。応答はサーバーが確定させたアルバム
  そのものなので一覧へ差し込む。読み直すと、その読み込みが失敗したときに
  成功した書き込みがエラー画面の裏に隠れる。

### 権限

- `album:create`（作成）と `album:edit`（名前の変更・収録の変更）を
  `MediaPermission` へ足した。持っていない操作はボタンごと出さない
  （押してから 403 で断られない）。2 つは**別々に**判定する——ピッカーは
  `album:create` で「新しいアルバム」の行を、`album:edit` で既存アルバムの
  一覧を出す。どちらか片方だけを持つ主体がどちらもあり得る。

### 入れなかったもの

- 並び順の変更・カバーの指定・公開範囲・共有リンク・アルバムの削除。
  サーバーの API にはあるが、「保存する」「見る」のどちらも困っていない
  （ADR-0013「帰結」）。

## 2026-08-10 — 新しいタグをアプリから作れるようにした

- Progress A12。できたのは既にライブラリにあるタグの付け外しだけで、
  新しいタグを起こすには Web の管理画面へ行く必要があった。写真を撮って
  見ている端末で整理を完結できず、あとで PC に向かう手間が残っていた。
  **サーバー側の変更は無い**（`POST /api/tags` は既にあった）。

### 検索欄から 1 タップで作る

- タグエディタの検索欄に、ライブラリが持たない名前を入れると、候補一覧の
  先頭に「『〇〇』を作る」が出る。タップで作成し、そのまま選択済みになる。
  **画面もダイアログも増やしていない**。
- 大文字小文字を無視して既存名と照合するので、既にある名前には提示が出ない。
  サーバーも同じ比較で既存タグを返すため、押しても何も起きない状態にならない。
- 作成が届くのは保存を待たない（タグが先に存在しないとメディアに結べない）が、
  **メディア側は保存するまで変わらない**。閉じれば写真はそのまま。
- 追加の権限は要らない。`POST /api/tags` はタグの付け外しと同じ
  `media:tag-manage` を要求するので、エディタを開けている時点で満たしている。

### 属性は訊かない

- サーバーは `attr` を必須で取るが、アプリは常に `others` で作る。
  8 種の分類を家族に選ばせても大半が「その他」になり、写真へ戻るまでの
  操作だけが増える。分類が要るときは Web の管理画面で直す。
  判断は `docs/adr/0012-app-created-tags-are-unclassified.md`。

## 2026-08-09 — 自動バックアップの対象を端末アルバムで選べるようにした

- Progress A10。自動バックアップは端末のライブラリ**全体**を対象にしていた。
  `photosTakenAfter` が `onlyAll: true` かつ `RequestType.common` で問い合わせる
  ため、スクリーンショット・受信画像・保存したミームに加え、**画面録画や受信した
  動画まで**上がっていた。サーバー側のライブラリが実際の写真で埋もれ、回線と
  ストレージも食っていた。**サーバー側の変更は無い**（送る側を絞っただけ）。

### 対象を選べるようにした

- アップロードタブの既存カードに「バックアップする対象」を 1 行足し、
  ダイアログで端末アルバムを選ぶ。**画面（ルート）は増やしていない**。
- 既定は「この端末のすべて」。設定が無い既存インストールの挙動は変わらない。
  「すべて」は空集合として持ち、「一度も選んでいない」と読み分けない。
- 選択は端末アルバムの id で覚える。アルバム名を変えても外れない。
  存在しなくなったアルバムの id も残す（外部メディアの取り外しで対象が
  黙って広がらないように）。
- 絞り込みが掛かるのは**自動**バックアップだけ。グリッドから手で選んで送る
  経路はその場で利用者が選んでいるので絞らない。

### 「充電中のみ」は入れなかった

- 取りこぼしを起こしていたのは対象の広さであって実行のタイミングではない。
  条件を足すと「上がっていない理由」が 3 つに増え、失敗と待機の区別が付き
  にくくなる。判断は `docs/adr/0011-backup-target-albums.md`。

## 2026-08-09 — 権限の無い操作を出さないようにした

- Progress A9。`AuthSession` はログイン時にサーバーから scope を受け取り
  `hasScope()` まで持っていたのに、Presentation 層が一度も呼んでいなかった。
  結果として `media:tag-manage` を持たない利用者もタグエディタを開いてタグを
  選べてしまい、保存を押した瞬間に 403 で落ちていた。お気に入り・ゴミ箱・
  アップロードも同じ形。**サーバー側の変更は無い**（scope は既に届いていた）。

### アプリが呼ぶ操作と、サーバーが要求する scope を対応づけた

- `MediaPermission`（Domain の値オブジェクト）が、アプリが実際に叩く
  エンドポイントと権限コードの対応を 1 箇所で持つ。`media:tag-manage`（タグ）、
  `media:metadata-manage`（お気に入り）、`media:delete`（ゴミ箱・復元）、
  `media:upload`（アップロード）。
- ゴミ箱と復元が同じコードなのはサーバーがそう決めているため
  （`DELETE /media/{id}` と `POST /media/{id}/restore` がどちらも
  `media:delete`）。**戻す側だけ許す構成は無い**ので、復元だけ出す余地はない。
- `GrantedPermissions` はセッションが実際に持つものだけを答える。サインアウト
  中は何も許さない。`grantedPermissionsProvider` がセッションから導出するので、
  トークン更新で scope が変われば次の再描画で導線も変わる。

### 押せない導線は消す

- 詳細ビューアの上部バーは、権限が無いアイコンを**無効化ではなく非表示**に
  する。写真に重なる小さなアイコンの列で灰色にすると「今はまだ」に読めるが、
  権限は待っても増えない。
- アップロードは**タブごと消える**。画面上のすべての操作が 403 に終わる
  タブは、無いほうがましだから。タブ列は位置ではなく行き先で持つように直した
  （消えると後ろの添字がずれるため）。
- ゴミ箱は、削除できないセッションからは設定の導線ごと消す。直接開いた場合も
  復元ボタンを出さない（一覧は残す——捨てたものが見えること自体は害が無い）。

## 2026-08-09 — 詳細ビューアからタグを付け外しできるようにした

- Progress A5 のうちタグの分。A3（お気に入り・ゴミ箱）と同じ
  「見ている写真をその場で整理できるか」を優先する順で、まずタグを入れた。
  アルバム編集とアカウント設定は A5 に残っている。

### 詳細ビューアにタグエディタを足した

- サーバーの `GET /api/tags` と `PUT /api/media/{id}/tags` はあるのに
  アプリからはどちらも呼んでおらず、タグの閲覧すらできなかった。
  ビューアの上部バーにタグのアイコンを足し、ボトムシートで開く。
- 境界は A3 と同じ形。`MediaTagRepository` は一覧の
  `MediaLibraryRepository` とも整理の `MediaCurationRepository` とも分けた
  ——タグ付けはサーバー側でも別の権限（`media:tag-manage`）で、閲覧しか
  しない画面から届く必要がない。
- **メディアのタグは開くたびにサーバーから読む。** 一覧の
  `GET /api/media` はタグを返さないため、そもそも一覧に乗っていない。
  provider は `autoDispose` で、閉じたら忘れる——古い集合から保存すると
  別端末の変更を黙って取り消してしまう。
- **保存するまで何も送らない。** エディタは自分が持つ集合を編集し、
  保存で全体を 1 回置き換える（サーバーのエンドポイントがその形）。
  3 つ足しても 1 リクエストで、保存せず閉じれば何も変わらない。
- 結果はサーバーが確定した値を採る。別端末が消したタグは戻ってこない集合に
  含まれず、画面はそれを表示する。
- タグ配列が無い応答は「タグ 0 件」ではなく失敗として扱う。読めなかった
  ものを空と解釈すると、次の保存が読めていないタグを消してしまう。
- 検索欄は写真タブと同じく 350ms 待ってから送る。
- タグの新規作成（`POST /api/tags`）は入れていない。ライブラリに既にある
  タグの付け外しだけで、新しいタグを起こすのは Web の管理画面のまま。

## 2026-08-09 — 写真タブの検索、サムネイルの一括取得、お気に入りとゴミ箱

- Progress A1・A2・A3・A4。サーバー側にあるのにアプリから使えていなかった
  ものを埋める回。

### 写真タブに検索・絞り込みを入れた（A1）

- サーバーの `GET /api/media` は `q` / `type` / `favorite` を受けるのに
  アプリはどれも送らず、時系列の全件だけを出していた。翻訳
  （`searchFieldLabel` / `searchFieldHint`）は en・ja とも既に入っており、
  画面だけが作られていなかった。
- 絞り込みは `MediaLibraryQuery`（値オブジェクト）で表す。等価性が
  フィールド単位なので「変わったか」が 1 回の比較で済み、タイムラインは
  それを watch して先頭の窓から読み直す。
- 検索欄は 350ms 待ってから送る。1 打鍵ごとに投げると 1 文字につき 1 往復
  になり、古い応答が新しい応答のあとに届く。キーボードの検索キーは待たない。
- **0 件の意味を 2 つに分けた。** 絞り込み中は「条件に合うものが無い」で
  直す先は条件（クリアの導線）、絞り込み無しは「ライブラリが空」で直す先は
  読み直し。検索欄は読み込み中・失敗時も残す（消すと条件を直せなくなる）。
- タブは 4 つのままで検索タブは作らない。写真タブの中で絞り込む形にした。

### サムネイルを署名付き URL の一括発行で取るようにした（A2）

- 1 枚ずつ `GET /api/media/{id}/thumbnail` を叩いており、グリッド 1 画面で
  認証付きラウンドトリップが数十回走っていた。SPA と同じく
  `POST /api/media/thumb-urls` でまとめて署名 URL を受け取り、実体は
  リバースプロキシ／CDN から引く。
- `ThumbnailUrlBatch` が同じフレームで求められたぶんを 1 リクエストに束ねる。
  待ちは `Duration.zero`＝時間待ちではなく「そのフレームの build が
  終わってから」。同じ (id, size) は 1 回、サイズ違いは別リクエスト、
  500 件超は分割。
- 発行できなかったメディア（削除済み）・発行そのものの失敗・署名 URL の
  期限切れや到達不能は、いずれもアプリサーバー経由へ落ちる。タイルが空の
  ままにならないことを優先する。
- ローカルのサムネイルキャッシュは従来どおり先に見るので、効くのは初回
  スクロールと再取得時。

### お気に入りと削除／ゴミ箱を触れるようにした（A3）

- `MediaCurationRepository` を一覧の `MediaLibraryRepository` とは別に置いた。
  閲覧しかしない画面から破壊的な操作へ手が届かないようにするため。
- ゴミ箱は `findTrashPage`（`deleted_only=1`）。`findPage` のフラグにしない
  ——別のリスト・別の操作（復元）で、混ぜると通常の一覧に削除済みが紛れ込む。
- 結果は読み込み済みのタイムラインへ直接書き戻す。再読み込みだとスクロール
  位置と読み終えた窓を捨てることになる。お気に入りは**サーバーが確定した値**
  を採る（別端末が先に変えている場合がある）。復元だけはタイムラインを触らない
  ——撮影日時順のどこへ入るかを推測しないため、次の読み込みに任せる。
- ビューアにお気に入りと削除（確認つき）を追加。最後の 1 枚を削除したら閉じる。
  設定からゴミ箱へ入り、そこから復元できる。
- タグ・アルバムの作成と編集・プロフィール／パスワード変更・TOTP・パスキーは
  まだ触れない（Progress A5）。

### 参照されていない翻訳キーを削除した（A4）

- 197 キーのうち 21 個がどこからも参照されていなかった。FlutterBase 雛形の
  名残 10 個、検索ぶん 4 個、その他 7 個。en・ja の両方にあった。
- 検索ぶんのうち 2 個は A1 で使うようになった。`searchEmptyMessage` は
  「キーワードを入力して検索してください」という、既定で全件を出す今の
  写真タブに合わない文言だったため `searchNoResults` へ置き換えた。
  `navSearch` は検索タブを作らないと決めたので削除した。

---

## 2026-08-09 — テンプレートの識別子を実 ID に置き換え、App Links を実ドメインへ

- Progress #6・#1。どちらも「所有ドメイン未定」で保留していた項目で、
  `nolumia.com` に決まったことで同時に解けた。
- `applicationId` を `com.example.flutterbase` から **`com.nolumia.photonest`**
  へ変更（`com.example.*` は Play Console が拒否する）。Dart パッケージ名も
  `flutterbase` → `photonest` になり、`package:` の import 全部と Kotlin の
  パッケージ・ディレクトリが追随した（`scripts/rename_app.sh`）。
  `pubspec.yaml` の `description` は手で直した。
- `tool/check_architecture.dart` の既定 `--package` も `photonest` にした。
  ここはレイヤー所属を `package:<name>/...` の import から判定するため、
  古い名前のままだと**どの import も認識されず、検査していない木を
  「違反なし」と報告する**。CI は `--package` を渡さないので既定値が効く。
- App Link のホストを `flutterbase.example.com`（実在しない）から
  **`photonest.nolumia.com`** へ。PhotoNest サーバー自身＝ SPA と同じホストを
  使うので、アプリを入れている端末はアプリで、入れていない端末はブラウザで
  同じアルバムが開く。カスタムスキームも `flutterbase://` → `photonest://`。
- **intent filter でパスを絞った。** ホストが SPA と共用になったため、
  `android:host` だけの filter ではそのホストの URL を全部アプリが横取りし、
  `/admin/users` のような Web 専用ページまで `NotFoundPage` になっていた。
  アプリがルートを持つ `/albums/{数字}` と `/link` だけを要求する。
- そのために **`minSdk` を 24 から 31 へ引き上げた。** パスを厳密に絞れる
  `android:pathAdvancedPattern` が API 31 以上のため。前方一致の
  `pathPrefix` では SPA 専用のスライドショー（`/albums/42/slideshow`）まで
  巻き込む。API 30 以下の端末はこの属性を「無視」する——エラーにはならず
  filter がホスト全体へ静かに広がるので、`minSdk` とパス指定は必ず一緒に
  動かすこと。テスト（`test/android/android_manifest_test.dart`）で
  「autoVerify filter の全 `<data>` がパス属性を持つこと」と
  「`pathAdvancedPattern` を使うなら `minSdk >= 31`」を固定した。
  2026-08-07 に 36 → 24 へ下げた判断を部分的に戻す形になる。
- `minSdk` が 31 になったことで `WRITE_EXTERNAL_STORAGE`
  （`maxSdkVersion="28"`）はどの端末でも付与されなくなったため削除した。
  ギャラリーへの保存は Android 10+ の MediaStore 経由のみになる。
- `docs/deep_links/assetlinks.json` に実 `package_name` と debug 署名の
  指紋を記入。**release 署名の指紋は未記入**（鍵を持つ人が埋める）。
  配信はサーバー側の新設定 `ANDROID_APP_LINK_ASSETLINKS` が行う。

## 2026-08-09 — 自動バックアップを再開可能な分割アップロードに載せ替える

- photonest Progress F11a。送信は `POST /api/upload/prepare` の単発
  multipart で、回線が切れると常に先頭から送り直しだった。動画 1 本が
  数分〜数十分かかるため、不安定な回線では最後まで終わらないことがある。
- サーバーの分割アップロードへ切り替えた。`POST /api/upload/chunks` で
  ファイル名・サイズ・Content-Type を申告して `tempFileId` を受け取り、
  `PUT /api/upload/chunks/{tempFileId}` に `Content-Range` を付けて
  4 MiB ずつ追記し、全部届いたら `POST /api/upload/commit` で確定する。
  3 つの呼び出しはこれまでどおり同じ `X-Upload-Session` を運ぶ。
  単発の `POST /api/upload/prepare` は使わなくなったため、API クライアント
  からも multipart 送信を外した。
- 中断からの再開は 2 段構え。(a) 送信中に切れた場合は
  `GET /api/upload/chunks/{tempFileId}` で受信済みバイト数を問い合わせ、
  その続きから送り直す（同じ理由で 409 `offset_mismatch` /
  `upload_busy` も問い合わせで解決する）。同一チャンクの再試行は 3 回まで
  で、進捗が出ないまま回り続けることはない。(b) プロセスが落ちた場合に
  備え、再開キー（アップロードセッション ID・`tempFileId`・宣言サイズ）を
  `upload_resumptions` テーブル（schema v9、サーバー+アカウント単位で分離）
  に残す。バックグラウンドパスは OS に殺されて終わるのが普通で、メモリ上の
  記録では意味がないため。記録は最初のチャンクを送る**前**に書く。
- 記録が実体と食い違う場合は素直にやり直す。ファイル名・サイズが変わって
  いれば（再エンコード等）別物として最初から送り直し、サーバーが
  `upload_not_found` を返す（一時ファイルが掃除された）場合は申告からやり直す。
  コミットに成功したら記録を消す。
- 進捗（`onBytes`）はチャンク単位ではなくファイル全体に対して報告する。
  再開したアップロードのバーは 0 からではなく続きから伸びる。
- 再開キーの読み書きはすべてベストエフォート。コミット後の削除で失敗して
  アップロード自体を失敗扱いにすると、サーバーは受理済みなのに履歴へ記録
  されず、次のパスが同じ写真をもう一度送ってしまう。読めない・書けない場合
  は「再開できない」だけで、送信は続ける。
- 再開キーの削除は `tempFileId` が一致する行だけを対象にする。手動
  アップロードは同期リースを取らないため自動パスと同じ写真で重なりうる。
  先に終わったほうが相手の行まで消すと、中断していたほうの進捗が失われる。
- 進捗が出ないまま打ち切ったアップロード（`upload_stalled`）は失敗一覧で
  「サーバーに拒否された」ではなく通信エラーとして扱う。次のパスが続きから
  再開してたいてい成功するため、諦めさせる文言は誤り。
- Domain に `UploadResumption` と `UploadResumptionRepository` を追加し、
  `SqfliteUploadResumptionRepository` が実装する。読み書きはファイル全体を
  メモリに載せず、送信する範囲だけをディスクから読む。

## 2026-08-08 — アップロード進捗のバイト単位化と失敗の永続化

- 旧 Progress #23。(a) 進捗が枚数単位で、大きい動画 1 本の間はバーが
  止まって見えた。(b) 失敗一覧はメモリ上にしかなく、アプリを閉じると
  どのファイルがなぜ落ちたのか分からなくなった。(c) 自動パスの失敗は
  件数だけで、繰り返し失敗する写真に気付けなかった。
- (a) `PhotoUploadRepository` に `onBytes` を足し、`http.MultipartRequest`
  を継承して `finalize()` のストリームを数えることで送信バイトを報告する
  （`http` に進捗フックが無いため）。`UploadPhotosUseCase` の
  `onProgress` は `UploadProgress`（確定枚数・総数・送信中のファイル名・
  送信バイト・総バイト）を返すようになり、`fraction` は確定枚数に
  送信中ファイルの割合を足して返す。トークン更新後の再送では 0 から
  やり直す（実際に送り直しているため）。
- (b)(c) `upload_failures` テーブル（schema v8、サーバー+アカウント単位で
  分離）に失敗を永続化する。`UploadFailure`（Domain）+
  `UploadFailureRepository` + `SqfliteUploadFailureRepository` を追加。
  記録は `UploadPhotosUseCase` 内で行うため手動・自動の両パスが同じ
  痕跡を残し、`automatic` 列でどちらだったかを残す。同じ写真の再失敗は
  `attempts` を数える（未対応フォーマット等、いつまでも成功しない写真に
  気付ける）。アップロードに成功した写真の行は削除するので、この表は
  常に「今まだ困っている写真」だけを持つ。
  記録の削除・書き込みの失敗はログに残して握りつぶす（サーバーは既に
  受理済みで、記帳のためにバッチを落とすほうが害が大きい）。
  アップロードタブの失敗サマリはこの表を読むようになり、再起動や
  バックグラウンドパスをまたいで残る。
  `automatic` はインスタンスではなく `execute` の引数で受ける。同じ
  ユースケースを手動画面・フォアグラウンドの自動パス・WorkManager の
  3 経路が使うため、コンストラクタ引数だと合成ルートのどれかが必ず
  取りこぼす（PR #14 レビュー対応）。
  変更通知はアイソレート内に閉じる。WorkManager 側の書き込みは別インスタンスの
  ストリームなので届かず、フォアグラウンド復帰時に読み直して拾う。

## 2026-08-08 — 全画面ビューアの前後移動・原本表示・端末保存

- 旧 Progress #22。全画面表示は 2048px のサムネイルを 1 枚出してタップで
  閉じるだけで、前後の写真へ移動できず（毎回閉じてグリッドから選び直し）、
  原本を見る／保存する導線も無かった。
  ビューアを `PageView` にして、開いたときのリスト（アルバムの並び、
  写真タブの時系列）をそのまま前後に送れるようにした。写真タブでは
  日付セクションをまたいで送れる。上部バーに「N / 全件」と閉じる・
  「原本を表示」・「端末に保存」を置く。
  タップで閉じる挙動は廃止した。スワイプ操作と競合し、誤タップで閉じる
  ほうが煩わしいため。閉じるのは明示的なボタンで行う。
- 原本は `POST /api/media/{id}/original-url` の署名付き URL を
  `Image.network` に渡す（`MediaOriginalRepository` + 
  `ApiMediaOriginalRepository`）。署名がそのまま認可なので、
  API クライアントは署名 URL への GET に Bearer トークンを付けない。
  読み込み中の進捗と失敗表示を持たせてある（原本は数十 MB になりうる）。
  既定は従来どおり 2048px のままで、原本は明示的に要求されたときだけ取る。
  動画は再生用レンディションを持つので「原本を表示」は無効、
  「端末に保存」で原本を取得する。
- 端末保存は `PhotoLibraryGateway.saveToLibrary` を新設し、
  `photo_manager` の `editor.saveImage` / `saveVideo` へ渡す
  （動画は一時ファイル経由。保存後に必ず削除する）。
  写真ライブラリの許可はダウンロードの**前**に確認する。拒否された後に
  原本 1 本分の通信を使ってしまわないため。
  API 28 以下向けに `WRITE_EXTERNAL_STORAGE`（`maxSdkVersion="28"`）を
  マニフェストへ追加した。
- `MediaPlaybackSource` を `SignedMediaUrl` に改名した。再生用と原本用で
  同じ「署名付きの短命 URL」を返すため、再生専用の名前が実態と合わなく
  なった。

## 2026-08-08 — ライブラリ全体を時系列で見る「写真」タブ

- 旧 Progress #21。写真を見る導線はアルバム詳細だけで、アルバムに入れて
  いない写真はアプリから一切見られなかった。サーバーには
  `GET /api/media`（撮影日時降順）があるのにアプリから呼んでいなかった。
  ボトムナビの先頭に「写真」タブを足し、ライブラリ全体を撮影日ごとの
  セクションに分けて表示する。ページングはスクロール末尾で次ページを
  読み、失敗時は読み込み済みを残したまま再試行ボタンを出す。
  絞り込み（種別・タグ・期間・フリーテキスト・お気に入り）はサーバー側に
  あるが今回は載せていない。
  `MediaLibraryRepository`（Domain）+ `ApiMediaLibraryRepository`
  （Infrastructure）+ `ListLibraryMediaUseCase`（Application）を追加。
  `/api/media` は snake_case で真偽値を 0/1 で返すため（`/api/albums` は
  camelCase と真の真偽値）、その差はアダプター内で吸収する。
  オフラインのスナップショットは持たない。ライブラリは際限なく増えるので
  古い写し取りはかえって誤解を生む（サムネイル自体は従来どおり
  SQLite キャッシュからオフラインでも出る）。
- あわせて `AlbumMediaItem` を `MediaItem` に改名した。同じ「サーバーが
  持つ写真・動画」をアルバム詳細と写真タブの両方が扱うため、アルバム
  文脈の名前が実態と合わなくなった。グリッドのタイルと全画面ビューアも
  `MediaTile` / `showMediaViewer` として切り出し、両画面で共有する。
  サムネイル・再生の provider は `album_providers.dart` から
  `media_providers.dart` へ移した。
- バグ修正: ページ追加読み込みが一度失敗したあと再試行が成功しても
  `loadMoreFailed` が下りず、再試行ボタンが出たままになっていた
  （アルバム詳細にも同じ不具合があったので同時に直した）。
- バグ修正: 追加読み込み中にプルダウン更新やサインイン先の切り替えが
  起きると、遅れて届いた古いページが新しい状態を上書きしていた。
  別アカウントのメディアが表示され続けうるため、build ごとに世代番号を
  進め、世代が変わった応答は捨てる（アルバム詳細も同様に直した）。

## 2026-08-08 — 自動アップロードを既定で Wi-Fi 限定にする

- 旧 Progress #20。自動アップロードは写真・動画の**原本**を送るのに、
  回線が従量課金かどうかを見ておらず（WorkManager の制約は
  `NetworkType.connected`、フォアグラウンドのパスは接続種別を参照すらして
  いなかった）、モバイル回線でも走っていた。設定「Wi-Fi 接続時のみ」
  （既定 ON。保存が無い＝この設定より前のインストールも ON 扱い）を
  `AutoUploadSettingsRepository` に追加し、二経路とも同じ判定を通す。
  バックグラウンドは登録制約を `NetworkType.unmetered` にして OS に
  判定させる。制約は登録時に焼き込まれるため、設定変更時は
  `SetAutoUploadUnmeteredOnlyUseCase` が再登録する
  （`ExistingPeriodicWorkPolicy.keep` → `update`。既存のタイミングは保たれる）。
  フォアグラウンドは `NetworkConnectionGateway`（Application ポート）+
  `ConnectivityPlusNetworkConnectionGateway`（Infrastructure、
  `connectivity_plus`）を新設し、`SyncNewPhotosUseCase` が
  ライブラリアクセス確認より**前**に判定する（スキップするパスで写真の
  権限ダイアログを出さないため）。スキップ理由は
  `SyncSkipReason.meteredConnection`。手動アップロードは対象外
  （ユーザーが明示的に押した操作をブロックしない）。
  アップロード中の判定は**1 枚ごと**にやり直す（`UploadPhotosUseCase` の
  `mayContinue`）。原本の送信は数分かかることがあり、Wi-Fi で始めたバッチが
  途中で回線を離れても、あるいは実行中に設定を ON にしても、残りが
  モバイル回線で流れ続けてしまうため（PR #12 レビュー対応）。
  途中で止めた分は履歴に記録されないので次のパスで再試行される。
  接続種別は transport（wifi / ethernet）で判定するため、
  ユーザーが従量課金と印を付けた Wi-Fi はフォアグラウンドでは
  unmetered 扱いになる（バックグラウンドは OS 判定なので正しく弾く）。

## 2026-08-08 — アルバムメタデータのオフラインスナップショット

- 旧 Progress #14。#10 でサムネイルの実体は SQLite に永続化されたが、
  アルバム構成のメタデータはネットワーク経由でしか得られず、オフラインの
  コールドスタートではキャッシュ済みサムネイルにたどり着けなかった
  （PR #6 のレビュー指摘）。アルバム一覧・詳細ページの応答を
  `album_snapshots` テーブル（schema v7、サーバー+アカウント単位で分離）に
  スナップショット保存し、取得が `InfrastructureError`（ネットワーク不達
  含む）で失敗したときのフォールバックとして読み出すようにした。
  `AlbumSnapshotRepository`（Domain）+ `SqfliteAlbumSnapshotRepository`
  （Infrastructure）を追加し、`ListAlbumsUseCase` / `GetAlbumUseCase` が
  サーバー優先・成功時に上書き保存・失敗時にフォールバックを編成する。
  `AuthenticationError` はフォールバックせずそのまま表面化させる
  （スナップショットでサインイン済みを装わない）。サーバーが null を返した
  アルバム（削除済み）はスナップショットも破棄する。スナップショット
  ストア自体の故障はログに残してサーバー直読みへ縮退する。
  リクエスト中にサインイン識別（サーバー+アカウント）が変わった場合、
  スナップショットには書き込みも読み出しもしない（旧アカウントの応答を
  新アカウントのキーで保存する汚染の防止。PR #10 レビュー対応）。
  フル一覧の保存成功時には、一覧に存在しなくなったアルバムの詳細ページ
  スナップショットを同一アカウント範囲で削除する（削除・非公開化された
  アルバムがオフラインのディープリンクで復活しない。同レビュー対応）。

## 2026-08-08 — バックアップ結果の通知（通知一覧）

- 旧 Progress #17。自動アップロードの各パスが結果（成功件数・失敗件数）を
  `backup_notifications` テーブル（schema v6）に記録し、ヘッダーの通知ボタン
  （ADR-0005 で予約済みだった no-op）から通知一覧 `/notifications` を開ける
  ようにした。未読件数はベルにバッジ表示され（同一プロセス内の書き込みは
  変更ストリーム経由で即時反映）、一覧を開くと**読み込んだ分だけ**既読になる
  （表示中に届いた結果は未読のまま残る）。
  記録は `SyncNewPhotosUseCase` 内で行うため、フォアグラウンド・
  バックグラウンド（WorkManager）どちらのパスも同じ痕跡を残す。
  通知の保存失敗はログに残して握りつぶす（アップロード自体は成功しており、
  通知行のためにパスを失敗させない）。

## 2026-08-08 — テンプレート残渣の整理とページング修正

- 旧 Progress #16。flutterbase テンプレート由来のブックマーク機能一式
  （画面・フォーム・sqflite リポジトリ・ユースケース 5 本・ドロワー項目・
  `/bookmarks` ディープリンク・l10n キー）を削除した。schema v5 で
  `bookmarks` テーブルをアップグレード時に DROP する。ディープリンクの
  例・ドキュメントはアルバムルート（`/albums/:id`）に置き換え、統合テストは
  アルバムタブとドロワー遷移を対象に書き換えた。外部リンク起動の
  `ExternalLinkLauncher` ポートと `url_launcher` 実装は汎用境界として残す。
- 旧 Progress #15。未使用の `AuthRepository.refresh` と
  `ApiAuthRepository.refresh` を削除した。実際のリフレッシュは
  `PhotoNestApiClient._refreshSession`（ローテーションされたトークン対を
  永続化する側）が唯一の実装になった。
- 旧 Progress #19。サーバーが `mediaTotal` を返さない場合の
  ページング打ち切りを修正した。`AlbumDetail.mediaTotal` は欠落時に
  ページ長へフォールバックせず null（不明）となり、不明な間は「続きあり」
  として扱って短いページの到着でページングを終える。
- 旧 Progress #18。`CLAUDE.md` のプロジェクト情報プレースホルダーを記入し、
  README をテンプレート「flutterbase」の説明から PhotoNest クライアント
  （PhotoNest サーバーの写真閲覧・バックアップ用 Flutter アプリ）の説明に
  書き換えた。

## 2026-08-08 — 動画対応（列挙・アップロード・再生）

- 旧 Progress #9。`PhotoManagerPhotoLibraryGateway` を `RequestType.common` に
  変更し、端末の動画も列挙対象にした（`LocalPhoto.isVideo` を追加、
  `READ_MEDIA_VIDEO` 権限を宣言）。アップロードの Content-Type マップに
  動画拡張子（mp4/mov/mkv/webm ほか）を追加。
- アップロードはプラットフォームがファイルパスを公開できる場合
  `MultipartFile.fromPath` でディスクからストリーミングし、長時間の動画でも
  ファイル全体をヒープに載せない（パスが無いアセットのみ従来のバイト列
  読み込みにフォールバック）。
- サーバー動画の再生を追加。`MediaPlaybackRepository`（`POST
  /api/media/{id}/playback-url` の署名付き URL をエンドポイントへ解決）と
  `video_player` ベースの `VideoPlaybackView` で、アルバム詳細から
  フルスクリーン再生できる。トランスコード中（409 `not_ready`）は
  「準備中」の翻訳済み文言を表示する。
- アルバム詳細のメディアに再生バッジを表示（サーバーが `isVideo` を返す。
  photonest 側の同日変更とセット）。

## 2026-08-08 — サムネイルのオフラインキャッシュとページング

- 旧 Progress #10。サーバーサムネイルを SQLite（schema v3 の
  `media_thumbnails` テーブル）へ永続化した。`GetMediaThumbnailUseCase` が
  キャッシュ優先で読み、ヒットすればネットワーク無しで描画される
  （オフライン・再起動後も表示可能）。サーバー + アカウント単位でスコープし、
  LRU で 128 MiB を上限に自動削除する（ADR 0007）。
- アルバム一覧はサーバーのページングを最後まで辿り、200 件超でも全件表示。
- アルバム詳細はメディアを 100 件ずつページ読み（`albumDetailProvider` が
  `AsyncNotifier` family になり、グリッド末尾で次ページを自動取得。失敗時は
  末尾タイルから再試行）。サーバー側 `GET /api/albums/{id}` の
  `page`/`pageSize` 対応とセット。

## 2026-08-08 — アプリを閉じている間の自動アップロード（WorkManager）

- 旧 Progress #4。`workmanager` の 15 分周期タスクで、アプリ終了中も
  新しい写真・動画を自動アップロードする（ADR 0006）。制約は
  「ネットワーク接続あり」「バッテリー残量低下時は実行しない」。
- Application に `BackgroundSyncScheduler` ポートを新設し、自動アップロードの
  ON/OFF と同期してスケジュールを登録・解除する。起動時にも設定が ON なら
  登録し直す（アプリ更新でスケジュールが消えた場合の自己修復）。
- フォアグラウンドとバックグラウンドの同期パスは共有 SQLite の同期リース
  （schema v4 の `sync_leases`）で相互排他し、別アイソレート同時実行による
  同一写真の二重アップロードを防ぐ（ADR 0006）。
- バックグラウンド側のエントリポイントは `lib/app/background/`（合成ルート）。
  既存の `SyncNewPhotosUseCase` をそのまま実行するため、アップロード履歴に
  よる冪等性・前提条件の再検査はフォアグラウンドと同一。

## 2026-08-07 — `integration_test` を認証ガード後の実態に合わせて修正し CI へ組み込み

- 旧 Progress #12。「起動直後に `NavigationBar` がある」前提だった
  `integration_test/app_test.dart` を、未ログイン起動はログイン画面・
  セッション保存済み起動はメイン画面、という認証ガード後の挙動に合わせて
  書き直した（セッションは実キーストアの `SessionRepository` へ直接保存して
  用意する。サーバーには接続しない）。
- `quality.yml` に `integration-tests` ジョブを追加し、Android エミュレータ
  （API 34, KVM）で `flutter test integration_test` を実行する。端末が要るため
  `scripts/ci.sh` には含めない（`docs/OPERATIONS.md` 参照）。

## 2026-08-07 — アップロードの進捗表示・キャンセル・失敗一覧 UI

- 旧 Progress #11。`UploadPhotosUseCase` に進捗コールバックと協調キャンセル
  （`UploadCancellation`、写真単位で中断）を追加し、`uploadRunProvider` が
  実行中バッチの進捗・結果を画面へ流す。
- アップロードタブは実行中に進捗バー（n/m）とキャンセルボタンを表示し、
  完了後に失敗があれば要約行から写真ごとの失敗一覧ダイアログを開ける。

## 2026-08-07 — サーバー由来エラー文言の翻訳キー化

- 旧 Progress #8。アルバム一覧・アルバム詳細・アップロード候補の読込エラーと
  写真ごとのアップロード失敗理由が、開発者向け英語の `AppError.message` を
  そのまま表示していたのをやめ、`LoginFailure` と同じ「失敗の種類で分類して
  翻訳キーへ写像する」方式に統一（`presentation/l10n/error_descriptions.dart`、
  `PhotoUploadFailureReason`）。

## 2026-08-07 — `azure-pipelines.yml` を削除し GitHub Actions へ一本化

- 旧 Progress #7。Azure パイプラインは `ios/` 不在で `Build_iOS` が必ず失敗、
  配布先の App Center も 2025-03 に廃止済み、release 鍵の配線も未接続で
  実質全損だったため削除。CI は GitHub Actions
  （`quality.yml` / `build.yml`）のみとする。

## 2026-08-07 — 通知ボタンは通知機能の予約済み入り口として残す（ADR-0005）

- 旧 Progress #13（ダミーの通知ボタンを削除するか実装するか）を「予約済みの
  入り口として残す」で決着。判断の経緯は
  `docs/adr/0005-notification-button-reserved.md`。コード変更なし。

## 2026-08-07 — `minSdk` を 36 から 24 へ引き下げ

- `minSdk = 36`（Android 16）は現実の端末シェアのほぼ全域を切り捨てており、
  旧端末のカメラロール移行という主要ユースケースと矛盾していたため、
  Android 7.0（API 24）まで引き下げた。`pubspec.yaml` の
  `min_sdk_android` も 24 に更新。
- API 33 未満には `READ_MEDIA_*` 権限が無いため、`AndroidManifest.xml` に
  `READ_EXTERNAL_STORAGE`（`maxSdkVersion="32"`）を追加。
- API 26 未満は adaptive icon（`mipmap-anydpi-v26`）を使えないため、
  `assets/icon/app_icon.png` からレガシー密度別の
  `mipmap-*/ic_launcher.png`（mdpi〜xxxhdpi）を生成してコミット
  （`dart run flutter_launcher_icons` の再実行でも同等物が生成される）。

## 2026-08-07 — 状態管理を Riverpod に一本化

判断の経緯は `docs/adr/0004-riverpod-unification.md`。

- `ChangeNotifier` ViewModel 6 本（Theme / Language / DebugSettings /
  About / Debug / Session）を Riverpod の `Notifier` / `FutureProvider` に
  置き換え、`AppScope`（`InheritedWidget`）を削除。
- 認証ガードは `redirect` 内で `ProviderScope.containerOf` からセッションを
  読み、セッション変化は合成ルートの `RouterRefreshBridge` が
  `refreshListenable` に伝える。
- サーバー由来のキャッシュ（アルバム・サムネイル・アップロード候補）は
  `sessionIdentityProvider` を watch して自動破棄する形になり、
  `SessionCacheReset` ウィジェットを削除。
- Riverpod 3 の既定の自動リトライを無効化（明示的な「再試行」UI と競合し、
  失敗時に裏でサーバーを叩き直してしまうため）。

## 2026-08-07 — 認証トークンの保存先を Keystore へ移行

- `SessionRepository` の実装を SharedPreferences（平文）から
  `flutter_secure_storage`（Android Keystore）へ差し替え。secure storage の
  API は非同期のため、起動時に一度読み込んでメモリに保持し、save / clear が
  キャッシュとキーストアを同時に更新する（`load()` の同期契約は不変）。
- 旧ビルドが SharedPreferences に残した平文トークンは起動時に Keystore へ
  移行し、平文側は無条件に削除する。

## 2026-08-07 — PhotoNest クライアント機能（ログイン・アルバム・アップロード）

テンプレート（flutterbase）を PhotoNest のモバイルクライアントとして実装。
バックエンドは photonest リポジトリの FastAPI（`/api`）。API 仕様は
サーバーの `/api/docs`（OpenAPI）を出所とする。

### 追加

- **ログイン**: サーバー URL + メールアドレス + パスワードでログイン
  （`POST /api/auth/login`、scope は `gui:view`）。アクセストークン失効時は
  `POST /api/auth/refresh` で自動更新し、ローテーションされたリフレッシュ
  トークンを即座に永続化。ルーターに認証ガードを追加し、未ログイン時は
  `/login` へ、ログイン済みでの `/login` は `/` へリダイレクト。
- **アルバム閲覧**: アルバム一覧（`GET /api/albums`）と詳細
  （`GET /api/albums/{id}`、`/albums/:id` ルート）。サムネイルは
  `GET /api/media/{id}/thumbnail`（Bearer 認証）をバイト列で取得して表示。
- **写真アップロード**: 端末の最近の写真から選択して
  `POST /api/upload/prepare` → `POST /api/upload/commit`（`X-Upload-Session`
  ヘッダー）で送信。アップロード済みの写真は SQLite の履歴
  （`uploaded_photos` テーブル、スキーマ v2）で管理し二重送信を防ぐ。
- **自動アップロード**: photo_manager の変更通知とフォアグラウンド復帰を
  トリガーに、有効化時点以降に撮影された未送信の写真を自動送信
  （`AutoUploadCoordinator`）。有効化時に基準時刻を一度だけ記録するため、
  既存のカメラロール全体を巻き込まない。カメラ（撮影）機能は持たない。
- 依存: `http` / `http_parser` / `photo_manager`。Android に
  `READ_MEDIA_IMAGES` / `READ_MEDIA_VISUAL_USER_SELECTED` 権限を追加。

### 変更

- アプリ identity を PhotoNest に変更（`AppConfig` / Android label / l10n）。
- MainPage のタブを ホーム/検索/設定 から アルバム/アップロード/設定 に変更し、
  テンプレートのデモコンテンツ（Home/Search タブ）を削除。設定タブに
  アカウント表示とログアウトを追加。
- アップロード後の写真がサーバーのライブラリに現れるのは、サーバー側の
  取り込みジョブ（local import）実行後。クライアントは受領（コミット成功）
  までを保証する。

## 2026-08-05 — 自己更新後の再実行が終了コード 126 で落ちる問題の修正

- `scripts/build-remote-container.sh` の自己更新後の再実行を、ファイルを直接
  実行する形から「今動いている bash に自分自身を渡す」形へ変更。ホスト上の
  コピーに実行権が無い場合（共有フォルダ経由で置くと 0644 になりがち）に
  `/usr/bin/env: bad interpreter: Permission denied`（終了コード 126）で
  ビルドが始まらないまま落ちていたため。あわせて、差し替えるファイルには
  元の権限に加えて実行権も付ける（元の権限をそのまま引き継ぐと、実行権の
  無い状態が更新のたびに引き継がれるため）。実行権は読み取りを許可している
  相手にだけ付けるので、`0640` のような絞った権限は `0750` にとどまる。

## 2026-08-03 — 配布物ビルドのスクリプト化

判断の経緯は `docs/adr/0003-build-in-dev-container.md`。

### 追加

- `scripts/build.sh` — APK / AAB をビルドし、`dist/` に配布物一式
  （成果物 + `manifest.env` + `manifest.sha256`）を書き出す。`apk` / `aab` /
  `all` の指定と、`BUILD_MODE` / `BUILD_NUMBER` に対応。
  `android/key.properties` に `storeFile` が無い release ビルド（＝Gradle が
  debug 鍵へフォールバックするビルド）は警告し、manifest に
  `signing=debug-keystore` を残す。
- `scripts/build-remote-container.sh` — git も Flutter も無い配布先ホスト向けの
  一括ビルド（SYNC → BUILD → PICK → VERIFY → PUBLISH）。同一ホスト上の dev
  コンテナで `git pull` と `build.sh` を実行し、`dist/` を一時ディレクトリへ
  取り込み、チェックサムが通ってから入れ替える（照合が通るまで前回の配布物を
  残す）。実行のたびに自分自身を最新版へ差し替える。
- `scripts/build-remote-container.env.example` — 上記の設定雛形。

### 変更

- `build.sh` はビルド後に `lib/shared/build_info.dart` をビルド前の内容へ戻す
  （未コミットの変更を持っていた場合はその内容へ）。生成物でありながら
  コミット対象のため、汚れたままだとビルドホストの次回の `git pull --ff-only`
  が失敗するため。
- `scripts/generate_build_info.sh` が `BUILD_NUMBER` を受け付けるようになった。
  未指定なら従来どおりコミット数。`build.sh` は `flutter build --build-number`
  と同じ値を渡すため、About 画面の build number と成果物の versionCode・
  `manifest.env` が食い違わない。
- `.gitignore` に `dist/` を追加。

## 2026-08-03 — 初期スタックの確定と App Links 対応

判断の経緯は `docs/adr/0002-starter-stack.md`。

### 追加

- ブックマーク機能（サンプル）— `go_router` / `flutter_riverpod` / `sqflite` /
  `path` / `url_launcher` を 4 層すべてに通す題材。一覧・詳細・追加・削除・
  外部リンク起動。
  - Domain: `Bookmark` / `BookmarkDraft` / `BookmarkId` / `BookmarkRepository`
  - Application: 5 つのユースケースと `ExternalLinkLauncher` ポート
  - Infrastructure: `AppDatabase`（スキーマ + マイグレーション）、
    `SqfliteBookmarkRepository`、`UrlLauncherExternalLinkLauncher`
  - Presentation: `BookmarksPage` / `BookmarkDetailPage` と
    `presentation/providers/` の Riverpod provider
- Android App Links の基礎 — `autoVerify` 付き intent filter、カスタムスキーム、
  `flutter_deeplinking_enabled`、`assetlinks.json` の雛形、診断画面（`/link`）。
  手順は `docs/DEEP_LINKS.md`。
- `lib/presentation/navigation/app_routes.dart` — 公開 URL とアプリ内ルートの
  唯一の定義元。
- `lib/app/di/provider_overrides.dart` — サービスロケータと Riverpod の橋渡し。

### 変更

- ルーティングを `Navigator.onGenerateRoute` から `go_router` に移行
  （`MaterialApp.router`）。これによりプラットフォームから届くリンクが
  通常の遷移と同じ経路で解決される。
- `minSdk` を 36 に統一。`flutter_launcher_icons.min_sdk_android` が 21 のまま
  食い違っていたのを解消。
- `url_launcher` を `tool/check_architecture.dart` の Infrastructure 限定
  package に追加。
- 起動時に SQLite を開くようになった（`InfrastructureModule.create`）。
- `dependency_policy.reserved` が空になった（宣言済み依存はすべて使用中）。

### 削除

- `equatable`、`riverpod_annotation`、`riverpod_generator`。

## 2026-08-03 — CI 品質ゲートの導入とツールチェイン更新

### 追加

- `scripts/ci.sh` — 整形・静的解析・アーキテクチャ検査・依存関係検査・
  テスト・カバレッジ下限・デバッグ APK ビルドを 1 コマンドで実行。
  規約違反時は非ゼロ終了。`--fast` / `--keep-going` / `--help` に対応。
  コード生成を使うプロジェクトでは `build_runner build` と
  `git diff --exit-code` も自動的に実行される。
- `tool/check_architecture.dart` — Analyzer の AST を走査してレイヤー規約を強制。
  依存方向、レイヤー別の禁止 import / 禁止型、Domain での `DateTime.now()` /
  `print` / `debugPrint`、Domain 型の `ChangeNotifier` 継承と public setter、
  具象アダプターへの依存を検出する。
- `tool/check_dependencies.dart` — `pubspec.yaml` と `lib/` の import を突き合わせ、
  未宣言依存・未使用依存・古い予約記載を検出。`packages/` にレイヤーを分割した
  場合は pubspec レベルの依存方向も検査する。
- `tool/check_coverage.dart` — `lcov.info` を読んで Domain 90% /
  Application 85% / 全体 80% を強制。
- `.github/workflows/quality.yml` — PR と main への push で `scripts/ci.sh` を実行。
  リリース・タグ・マージ運用には触れない。
- `test/coverage_surface_test.dart` — `lib/` の全ライブラリを import し、
  どこからも参照されていないファイルが計測対象から消えて全体カバレッジが
  実態より高く出るのを防ぐ。
- `test/support/` — Repository の in-memory fake、`AppLogger` の記録用ダブル、
  `AppScope` を組んだウィジェットテスト用ハーネス。
- `test/tool/` — 検査ツール自体のテスト。各ルールについて、違反を含む
  フィクスチャで非ゼロ終了することを確認する。
- `docs/adr/0001-single-package-layers.md` — 単一パッケージ構成を選んだ理由。

### 変更

- Flutter 3.44.8 / Dart 3.12 に更新し、依存パッケージを最新メジャーへ。
  `CardTheme` → `CardThemeData` の破壊的変更に追従。
- Android ツールチェインを Gradle 8.14.3 / AGP 8.11.1 / Kotlin 2.2.20 に更新。
  Gradle 8.3 は Flutter 3.44 の最低要件 8.7 を下回りビルドできなかった。
  非推奨の `Project.buildDir` と、AGP 8 で無効な `android.enableJetifier` を除去。
- レイヤー構成を整理。`lib/shared/` に混在していた値オブジェクト・エンティティ・
  エラー・ログ契約・テーマ・i18n を、それぞれ domain / application / presentation へ移動。
  `lib/shared/` はフレームワーク非依存の定数のみになった。
- `AppInfoRepository` が Application の DTO を返していた（Domain → Application の
  逆流）のを、Domain エンティティ `AppInfo` に変更。
- `AppLogger` ポートの `logFiles()` を `logFilePaths()` に変更し、`dart:io` の
  `File` を Application から排除。
- Presentation が合成ルートを import していたのをやめ、ViewModel は
  コンストラクタ注入、画面は新設の `AppScope`（`InheritedWidget`）から取得する形に。
- 合成ルートが `SharedPreferences` を直接扱っていたのをやめ、
  `InfrastructureModule` がアダプターを組み立てて Domain インターフェースだけを返す。
- `analysis_options.yaml` を強化。`strict-casts` / `strict-inference` /
  `strict-raw-types`、未使用 import・dead code・型不整合を error 扱い。
  併用できない `prefer_relative_imports` を外し `always_use_package_imports` に統一。
- カバレッジを Domain 100% / Application 100% / 全体 90% まで引き上げ。

### 削除

- `test/domain/app_colors_test.dart` — `test/presentation/theme/` の同名テストと
  内容が重複していた旧配置。
