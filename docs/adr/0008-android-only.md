# 0008: Android 専用とし、iOS 版は作らない

- 日付: 2026-08-08
- 状態: 採用

## 文脈

`ios/` ディレクトリが存在せず、アプリは Android 専用のまま来た（旧 Progress
#24）。依存している `photo_manager`・`workmanager`・`flutter_secure_storage`・
`video_player`・`connectivity_plus` はいずれも iOS を持っているので、
プラットフォーム追加自体は技術的に可能ではある。

ただし「`ios/` を生成すれば動く」という規模の作業ではない。

1. **自動バックアップの前提が違う。** Android は WorkManager の周期タスクで
   15 分ごとに確実に起こしてもらえる（ADR-0006）。iOS の Background Fetch /
   BGTaskScheduler は**起動タイミングを OS が決め**、実行時間も短く、
   ユーザーの利用パターンによっては何時間も起きない。原本をまとめて送る
   `SyncNewPhotosUseCase` の呼び出し方を iOS 向けに設計し直す必要がある。
2. **配布の前提が違う。** Apple Developer Program の年額費用と、審査を
   通す前提の配布経路が要る。

## 決定

**iOS 版は作らない。当面 Android 専用とする。**

- `pubspec.yaml` の `flutter_launcher_icons` に `ios:` 節を置かない。
- `AndroidManifest.xml`・`android/` 以下だけを保守対象とする。
- iOS 固有の分岐をコードに先回りで入れない。必要になった時点で
  この ADR を差し替える。

ドメイン・アプリケーション層は Flutter にもプラットフォームにも依存しない
（ADR-0001）ため、この決定でプラットフォーム非依存のコードが Android に
寄ることはない。将来 iOS を足す場合に書き直しになるのは Infrastructure の
アダプターと、上記 1 のバックグラウンド実行の設計だけである。

## 帰結

- iOS ユーザーはサーバーの Web UI を使う。アプリの価値の中心である自動
  バックアップは iOS では提供しない。
- ADR-0006 末尾の「iOS を追加する場合は BGTaskScheduler 対応が別途必要」は
  この決定で保留となる。着手する判断が出た時点で読み直す。
- 旧 Progress #24 はこの ADR に置き換えたので、バックログからは外した。
