# Deep Links (Android App Links)

このテンプレートは、Android の **App Links**（検証済み `https` リンク）と、
ローカル確認用の **カスタムスキーム**の両方を最小構成で備えています。

仕組みを実際に触るには、アプリ内の **ディープリンク**画面
（ドロワー / 設定 → ディープリンク、`/link`）を開いてください。
起動時の URL・クエリパラメータ・検証済みリンク・`adb` コマンドが表示されます。

## 3 つの部品

App Links は「どれか 1 つが欠けても静かに失敗する」仕組みです。
本テンプレートでの担当箇所は次のとおりです。

| 部品 | 場所 | 役割 |
|---|---|---|
| Intent Filter | `android/app/src/main/AndroidManifest.xml` | どの URL をこのアプリに渡すかを OS に宣言する |
| `flutter_deeplinking_enabled` | 同上（`<meta-data>`） | 受け取った URL を Flutter の Router API に渡す |
| ルート定義 | `lib/presentation/navigation/app_routes.dart` + `lib/app/bootstrap/app_router.dart` | パスを画面に対応づける |

加えて、`https` の App Link を**検証済み**にするには、ドメイン側に
`assetlinks.json` を配置する必要があります（後述）。

## URL とルートの対応

公開する URL のパスと、アプリ内ルートのパスは**同一の文字列**です。
`AppRoutes` が唯一の定義元で、ルーターもリンク生成もそこを読みます。

ホストは `photonest.nolumia.com`＝**PhotoNest サーバー自身**です。同じ URL を
Web の SPA も配信するため、アプリを入れている端末ではアプリが、入れていない
端末ではブラウザが同じアルバムを開きます。

| ルート | 画面 | App Link | 検証済みリンクとして要求するか |
|---|---|---|---|
| `/albums/:id` | アルバム詳細 | `https://<host>/albums/42` | する（`pathAdvancedPattern="/albums/[0-9]+"`） |
| `/link` | ディープリンク診断 | `https://<host>/link?ref=email` | する（`path="/link"`） |
| `/` `/login` `/about` `/debug` `/logs` `/notifications` | メイン・システム画面 | — | しない |

### なぜ全パスを要求しないのか

`android:host` だけを書いた intent filter は、**そのホストの URL をすべて**
アプリに渡します。このホストは SPA と共用なので、それでは `/admin/users` や
`/media` のような Web 専用ページまでアプリが横取りし、`NotFoundPage` を
出してしまいます。そのため `AndroidManifest.xml` ではアプリが実際に
ルートを持つパスだけを列挙しています。

パス指定は **`android:pathAdvancedPattern`（API 31 以上）** を使います。
パス全体を正規表現で照合するため、`/albums/42` だけを取り、その下にある
SPA 専用のスライドショー（`/albums/42/slideshow`）やアルバム一覧
（`/albums`）はブラウザに残せます。前方一致の `android:pathPrefix` では
これらまで巻き込みます。

**`minSdk` を 31 未満に下げるときは、このパス指定も書き換えてください。**
API 30 以下の端末は知らない属性を「無視」します。エラーにはならず、
`<data>` に残るのは scheme と host だけになり、filter がホスト全体へ
静かに広がります。`android/app/build.gradle` の `minSdk` に同じ注意書きが
あります。

ホスト名とスキームは `lib/shared/app_config.dart` の
`appLinkHost` / `appLinkScheme` / `customLinkScheme` にあります。
**`AndroidManifest.xml` の `android:host` と必ず一致させてください。**
食い違うと、リンクは検証に失敗してブラウザで開きます。

`AppConfig.appLink()` は任意のパスから URL を組み立てられるので、
**intent filter が要求していないパスの URL も作れます**。その URL は
（検証済みリンクではないので）ブラウザで開きます。アプリで開かせたい
パスを増やすときは、manifest の `pathPrefix` も足してください。

### カスタムスキームは 3 スラッシュ

`photonest:///albums/1` のように、**authority を空**にしてください。
Android の Flutter embedding は受け取った URI の *path* からアプリ内ルートを
組み立て、authority を捨てます。`photonest://albums/1` と書くと
ルートは `/1` になり、どのルートにも一致しません。
`AppConfig.customLink()` はこの形を生成します。

カスタムスキームは**誰でも同じスキームを登録できる**ため未検証です。
第三者から送られてくるリンクには使わないでください。

## 未知のリンクは「入力」であって「約束」ではない

外から来た URL は壊れていることがあります。テンプレートはすべて
画面上の状態として扱い、例外にしません。

- `/albums/abc` → `AlbumId.tryParse` が null → 詳細画面の not-found 表示
- `/albums/999`（存在しない）→ リポジトリが null → 同上
- `/no-such-screen` → `errorBuilder` → `NotFoundPage`

いずれの場合もホーム画面が下に積まれているため、戻る操作が行き止まりになりません。

## `assetlinks.json` の配置

`android:autoVerify="true"` を付けると、Android はインストール時に

```
https://<appLinkHost>/.well-known/assetlinks.json
```

を取得し、APK の署名証明書のフィンガープリントと突き合わせます。
一致した場合のみ、リンクがブラウザではなくこのアプリで開きます。

配信する内容は `docs/deep_links/assetlinks.json` にあります。
`package_name`（`com.nolumia.photonest`）と debug 署名のフィンガープリントは
記入済みで、**release 署名のフィンガープリントだけが未記入**です。

1. release のフィンガープリントを取得する

   ```bash
   # リリース用（android/key.properties の storeFile）
   keytool -list -v -keystore <release.jks> -alias <alias> | grep SHA256
   ```

   **Play App Signing を使う場合は、この鍵ではなく Play Console の
   「アプリの署名鍵の証明書」に表示される SHA-256 を登録します。**
   アップロード鍵の指紋を入れても検証は通りません（Play が再署名した
   APK の署名は別物のため）。

   debug 側は同梱の共有キーストア（`android/app/debug.keystore`）のもので、
   記入済みです。取り直す場合は次のとおり。

   ```bash
   keytool -list -v -keystore android/app/debug.keystore \
     -alias androiddebugkey -storepass android -keypass android \
     | grep SHA256
   ```

2. `docs/deep_links/assetlinks.json` の
   `REPLACE:WITH:YOUR:RELEASE:KEYSTORE:SHA256:FINGERPRINT` を 1 で取得した
   値に置き換える。`package_name` は `android/app/build.gradle` の
   `applicationId` と一致している必要があり、
   `test/android/android_manifest_test.dart` がずれを検出します。

3. PhotoNest サーバー（`photonest.nolumia.com`）から
   `https://photonest.nolumia.com/.well-known/assetlinks.json` として、
   `Content-Type: application/json` で配信する。リダイレクト不可。

   サーバー側は環境変数 `ANDROID_APP_LINK_ASSETLINKS`（または管理画面の
   「Android App Links」設定）に**このファイルの中身をそのまま**入れると
   配信されます。未設定なら 404 を返します。手順は PhotoNest サーバー側の
   `docs/OPERATIONS.md`「Android App Links」を参照してください。

4. 端末に再インストールして検証を走らせ、結果を確認する。

   ```bash
   adb shell pm get-app-links com.nolumia.photonest
   ```

   `verified` と表示されれば成功です。`legacy_failure` などが出る場合は
   ホスト名・フィンガープリント・配信 URL のいずれかが食い違っています。

## 動作確認

検証が済んでいなくても、`adb` からは Intent を直接送れます。
ルーティング側だけを先に確認したいときに使ってください。

```bash
# App Link（検証済みなら実機のブラウザからも同じ挙動）
adb shell am start -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE \
  -d "https://photonest.nolumia.com/albums/1"

# カスタムスキーム（検証不要）
adb shell am start -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE \
  -d "photonest:///link?ref=email"
```

同じコマンドはアプリ内の `/link` 画面にも表示され、コピーできます。

ルーターに届いたリンクは必ず 1 行ログに残ります
（`[Router] → /albums/1`）。ログ画面（デバッグモード時のみ表示）から
確認できます。「リンクがアプリに届いているのか、それともルートが
一致していないのか」を切り分けるのに使ってください。

## テスト

ディープリンクの挙動は `test/app/bootstrap/app_router_test.dart` で
実際のルーターを使って検証しています。Android が渡してくるのは URL の
*パス*なので、テストは `initialLocation` にパスを与えて同じ経路を通します。

`AppRoutes` と `AppConfig` の対応（App Link とカスタムスキームが同じ
ルートに解決されること）は `test/presentation/navigation/app_routes_test.dart`
にあります。

Dart 側と Android 側の食い違いは `test/android/android_manifest_test.dart` が
検出します。`AppConfig.appLinkHost` と `AndroidManifest.xml` の `android:host`、
カスタムスキーム、`flutter_deeplinking_enabled` の有無、
`assetlinks.json` の `package_name` と `applicationId` の一致を確認します。
ホスト名を変えるときは、この 1 本が落ちるかどうかが更新漏れの目印になります。

## iOS について

本テンプレートに `ios/` ディレクトリはまだありません。追加する場合、
iOS の Universal Links には `apple-app-site-association` の配信と
Associated Domains の設定が必要ですが、**アプリ内のルート定義はそのまま
再利用できます**（go_router が同じ経路でパスを受け取るため）。
