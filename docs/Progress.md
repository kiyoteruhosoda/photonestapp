# Progress

進行中・未着手タスクのみを管理する（完了したら本ファイルから削除し、必要なら `CHANGELOG.md` / `history/` へ移す）。


- 状態: ⬜未着手 / 🚧進行中 / 🟡要判断
- 影響度・重要度・難易度・工数: 大 / 中 / 小
- バックログは「優先」列の昇順（1 が最優先）。

## バックログ

いまのところ空。所有ドメインが `nolumia.com` に決まったことで、保留していた
`applicationId`（#6）と App Link ホスト（#1）の判断が両方とも解けたため、
どちらも実装して `CHANGELOG.md` へ移した。

次の項目を起こすときは、上の書式で表を戻すこと。

| 優先 | # | 概要 | 状態 | 影響度 | 重要度 | 難易度 | 工数 |
|---|---|---|---|---|---|---|---|

## メモ（実装済みタスクの運用上の注意）

- **release 署名のフィンガープリントが未記入。** `docs/deep_links/assetlinks.json`
  は `package_name` と debug 署名の指紋まで入っているが、release 分は
  `REPLACE:WITH:YOUR:RELEASE:KEYSTORE:SHA256:FINGERPRINT` のまま。鍵を持つ人が
  `docs/DEEP_LINKS.md` の手順で埋め、サーバーの管理画面
  （Domains & URLs > Android アプリリンク）へ貼るまで、release ビルドの
  App Link は検証されずブラウザで開く。Play App Signing を使う場合は
  アップロード鍵ではなく Play Console の「アプリの署名鍵の証明書」の指紋を使う。
- `minSdk` は 31。App Links の intent filter が `android:pathAdvancedPattern`
  （API 31 以上）でパスを厳密に絞っているため、下げるならパス指定の書き換えが
  先。API 30 以下の端末はこの属性を無視し、filter がホスト全体へ静かに広がる。
- ローカル DB のファイル名は `flutterbase.db` のまま（`AppDatabase.fileName`）。
  端末内部の名前で画面にも API にも出ないため、改名しても得が無く、既存
  インストールのローカルデータを捨てるだけになる。
