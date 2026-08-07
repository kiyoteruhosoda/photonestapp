# 0003. 配布物のビルドを dev コンテナに寄せ、配布先には成果物だけを置く

- 状態: 採用
- 日付: 2026-08-03

## 文脈

配布物（APK / AAB）を作る経路は、これまで GitHub Actions
（`.github/workflows/build.yml`）だけでした。self-hosted runner を ACI で
起動し、署名鍵を Secrets から書き出してビルドし、artifact として上げます。

これは「main へ入ったものを配る」経路としては十分ですが、次の場面では使えません。

- 社内の NAS やファイルサーバーへ、その場で最新ビルドを置きたい。
- 外部ネットワークへ出せない環境で配布物を作りたい。
- CI を待たずに、任意のブランチの配布物を手元の判断で作りたい。

一方、配布先になるホスト（Synology DSM のような NAS）には git も Flutter SDK も
Android SDK も置けません。置けたとしても、そこを開発環境として維持する費用は
配布のためだけには見合いません。

同じ制約は `fastapitemplate` が先に解いていて、そちらでは
`scripts/build.sh`（ソース側でビルドして `dist/` を作る）と
`scripts/build-remote-container.sh`（配布先ホストで dev コンテナへビルドを
委ね、`dist/` を取り込む）に分かれています。

## 決定

**同じ 2 段構えを flutterbase にも置きます。**

| スクリプト | 走る場所 | 役割 |
|---|---|---|
| `scripts/build.sh` | Flutter が入っている場所（開発機・dev コンテナ・CI） | ビルドして `dist/` に配布物と manifest を書き出す |
| `scripts/build-remote-container.sh` | 配布先ホスト（git も Flutter も無い） | dev コンテナへ SYNC / BUILD を委ね、`dist/` を PICK して VERIFY する |

決めた点は 4 つです。

1. **配布物の一式はディレクトリ 1 つ**（既定 `dist/`）。APK / AAB に加えて
   `manifest.env`（commit・branch・version・署名鍵）と `manifest.sha256` を
   同梱します。手元に届いた APK が「どのコミットの、どの鍵で署名されたものか」を、
   ファイル名以外の手掛かりで確かめられるようにするためです。
2. **ビルドはコンテナの中**。配布先ホストに要るのは docker だけです。
   ツールチェーンの版はコンテナが持ちます。
3. **`build-remote-container.sh` は自分自身を更新する**。`dist/` に含まれない
   手置きのブートストラップなので `git pull` では更新されません。SYNC の後に
   dev コンテナ内の版と byte 比較し、異なれば差し替えて 1 度だけ再実行します。
4. **CI 経路は残す**。`.github/workflows/build.yml` は今までどおり動きます。
   このスクリプトは CI の置き換えではなく、CI を通せない場面の経路です。

## 理由

### なぜ配布先ホストでビルドしないのか

NAS に Flutter SDK と Android SDK を入れると、そのホストが暗黙の開発環境になります。
版が上がるたびに更新の面倒を見ることになり、しかも「そこでしか通らないビルド」が
生まれます。ビルドの再現性はコンテナイメージに閉じ込めるほうが安く済みます。

### なぜ 2 本に分けるのか

`build.sh` は Flutter がある場所ならどこでも同じように動きます。開発機でも、
CI でも、dev コンテナの中でも同じコマンドです。配布先ホスト固有の事情
（dev コンテナ名、ホストから見えるパス、自己更新）は
`build-remote-container.sh` 側に閉じています。分けておくと、CI から
`build.sh` を呼ぶようにするときに `build-remote-container.sh` を触らずに済みます。

### なぜ manifest を付けるのか

配布物は「転送されたもの」なので、途中で壊れます。`sha256` の照合は PICK の
直後に行えば、壊れた APK を配ってから気付く事態を防げます。
`manifest.env` の `signing` を記録するのは、debug 鍵で署名された release ビルドが
外へ出るのを防ぐためです（`android/app/build.gradle` は `key.properties` が
無いとき debug 鍵へフォールバックするので、ビルド自体は成功してしまいます）。

### なぜ生成物をビルド後に戻すのか

`lib/shared/build_info.dart` は `scripts/generate_build_info.sh` が生成しますが、
リポジトリにコミットされています。ビルドで書き換わったままにすると、dev コンテナの
ワーキングツリーが汚れ、次回の `git pull --ff-only` が失敗します。SYNC が毎回の
入口である以上、ビルドは「実行しても木を汚さない」必要があります。

## 影響

- 配布先ホストに必要なのは docker と、手置きの `build-remote-container.sh`
  （＋任意で `build-remote-container.env`）だけになります。
- ビルドに使う dev コンテナは配布先ホスト上で別途用意します。この ADR では
  そのコンテナのイメージ定義までは決めていません（Flutter / Android SDK / git が
  入っていて、リポジトリを clone 済みであることだけが前提です）。
- `dist/` は `.gitignore` へ入れます。ビルド生成物なので追跡しません。
- 手順は `docs/OPERATIONS.md`（配布物をビルドする／git も Flutter も無いホストで
  ビルドする）にあります。
