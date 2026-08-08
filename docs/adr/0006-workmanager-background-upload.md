# 0006: バックグラウンド自動アップロードは WorkManager の周期タスクで行う

- 日付: 2026-08-08
- 状態: 採用

## 文脈

自動アップロード（旧 Progress #4）は、アプリ起動中の photo_manager 変更通知と
フォアグラウンド復帰時にしか動かなかった。アプリを完全に閉じている間の撮影も
アップロードするには、OS のバックグラウンド実行が必要になる。

Android での選択肢は次の 3 つだった。

1. **WorkManager（`workmanager` プラグイン）** — OS がスケジュールする周期
   タスク。最短 15 分間隔で、Doze・アプリスタンバイと協調する。制約
   （ネットワーク・バッテリー）を宣言でき、追加の権限が要らない。
2. **Foreground Service** — 即時性は高いが常駐通知が必須で、写真の自動
   アップロードに常駐は過剰。電池消費もユーザーに見える形で増える。
3. **Push 起床（FCM）** — サーバー起点の起床はこのユースケース（端末内の
   新規撮影の検知）と噛み合わない。撮影を知っているのは端末だけ。

## 決定

**1. WorkManager の 15 分周期タスクを採用する。**

- 制約は `networkType: connected` と `requiresBatteryNotLow: true`。
  オフラインでの空振りと低電池時の実行を OS 側で抑止する。
- Application に `BackgroundSyncScheduler` ポートを置き、
  `WorkmanagerBackgroundSyncScheduler`（Infrastructure）が実装する。
  スケジュールの登録・解除は自動アップロードの ON/OFF
  （`SetAutoUploadEnabledUseCase`）と同期し、起動時
  （`AutoUploadCoordinator.start`）にも設定が ON なら登録し直す。
- バックグラウンドのエントリポイント（`@pragma('vm:entry-point')`）は
  `lib/app/background/background_sync_entrypoint.dart`。ヘッドレス Flutter
  エンジンで動く第二の合成ルートとして、`InfrastructureModule` を組み立てて
  既存の `SyncNewPhotosUseCase` を 1 回実行する。
- タスクの戻り値は「パス自体が落ちたときだけ false（OS に再試行させる）」。
  写真単位の失敗は履歴に残らないため次の周期で自然に再試行され、
  OS のバックオフ再試行を重ねると電池を無駄にするだけになる。

## 帰結

- 撮影からアップロードまで最大 15 分＋OS のバッチ化分の遅延がある。
  即時性が要る場合はアプリを開けばフォアグラウンドの監視が即座に動く。
- 同期パスは前提条件（機能 ON・ログイン済み・ライブラリ権限）を毎回
  再検査し、アップロード履歴で冪等なので、フォアグラウンドの監視と
  バックグラウンドの周期実行が重なっても二重アップロードは起きない。
- iOS を追加する場合は `registerPeriodicTask` の BGTaskScheduler 対応
  （Info.plist の identifier 宣言）が別途必要になる。
