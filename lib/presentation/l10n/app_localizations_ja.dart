import 'package:flutterbase/presentation/l10n/app_localizations.dart';

/// Japanese localisations.
class AppLocalizationsJa extends AppLocalizations {
  const AppLocalizationsJa();

  // ─── Navigation ───────────────────────────────────────────────────────
  @override
  String get appName => 'フラッターベース';
  @override
  String get navHome => 'ホーム';
  @override
  String get navSearch => '検索';
  @override
  String get navSettings => '設定';

  // ─── Drawer ───────────────────────────────────────────────────────────
  @override
  String get drawerClose => '閉じる';
  @override
  String get drawerAbout => 'このアプリについて';
  @override
  String get drawerLicenses => 'ライセンス';
  @override
  String get drawerDebug => 'デバッグ情報';
  @override
  String get drawerLogs => 'ログ';
  @override
  String get drawerBookmarks => 'ブックマーク';
  @override
  String get drawerDeepLink => 'ディープリンク';

  // ─── Home tab ─────────────────────────────────────────────────────────
  @override
  String get homeWelcomeTitle => 'ようこそ';
  @override
  String get homeCardBody =>
      'このアプリはデジタル庁デザインシステム（DADS）に準拠しています。'
      'カラートークン、タイポグラフィ、スペーシングを基盤とした一貫性のあるUIを提供します。';
  @override
  String get homeComponentsTitle => 'コンポーネント';
  @override
  String get homePrimaryButton => 'プライマリボタン';
  @override
  String get homeSecondaryButton => 'セカンダリボタン';
  @override
  String get homeTextFieldLabel => 'テキスト入力';
  @override
  String get homeTextFieldHint => 'ここに入力してください';
  @override
  String get homeListCardTitle => 'リストカード';
  @override
  String get homeListCardSubtitle => 'サブタイトル';
  @override
  String get homeListCardItem2 => '項目 2';

  // ─── Search tab ───────────────────────────────────────────────────────
  @override
  String get searchFieldLabel => '検索';
  @override
  String get searchFieldHint => 'キーワードを入力';
  @override
  String get searchEmptyMessage => 'キーワードを入力して検索してください';

  // ─── Settings tab ─────────────────────────────────────────────────────
  @override
  String get settingsTitle => '設定';
  @override
  String get settingsTheme => 'テーマ';
  @override
  String get settingsThemeSystem => 'システム設定に従う';
  @override
  String get settingsThemeLight => 'ライト';
  @override
  String get settingsThemeDark => 'ダーク';
  @override
  String get settingsLanguage => '言語';
  @override
  String get settingsLanguageSystem => 'システム設定に従う';
  @override
  String get settingsLanguageEnglish => '英語';
  @override
  String get settingsLanguageJapanese => '日本語';
  @override
  String get settingsAbout => 'このアプリについて';
  @override
  String get settingsLicenses => 'ライセンス';
  @override
  String get settingsDebug => 'デバッグ情報';
  @override
  String get settingsLogs => 'ログ';
  @override
  String get settingsBookmarks => 'ブックマーク';
  @override
  String get settingsDeepLink => 'ディープリンク';

  // ─── Footer ───────────────────────────────────────────────────────────
  @override
  String get footerAbout => 'このアプリについて';
  @override
  String get footerLicenses => 'ライセンス';

  // ─── About page ───────────────────────────────────────────────────────
  @override
  String get aboutTitle => 'このアプリについて';
  @override
  String get aboutVersion => 'バージョン';
  @override
  String get aboutBuildNumber => 'ビルド番号';
  @override
  String get aboutGitCommit => 'Gitコミット';
  @override
  String get aboutFlutterVersion => 'Flutterバージョン';
  @override
  String get aboutDartVersion => 'Dartバージョン';
  @override
  String get aboutPlatform => 'プラットフォーム';
  @override
  String get aboutPlatformValue => 'Android / iOS';
  @override
  String get aboutDebugUnlocked => 'デバッグモードを有効にしました';
  @override
  String get aboutDebugAlreadyOn => 'デバッグモードは既に有効です';

  // ─── Debug page ───────────────────────────────────────────────────────
  @override
  String get debugTitle => 'デバッグ情報';
  @override
  String get debugWarning => 'このページはデバッグ専用です。リリースビルドでは表示しないでください。';
  @override
  String get debugAppInfoSection => 'アプリ情報';
  @override
  String get debugThemeSection => 'テーマ情報';
  @override
  String get debugThemeMode => 'テーマモード';
  @override
  String get debugThemeModeDark => 'ダークモード';
  @override
  String get debugThemeModeLight => 'ライトモード';
  @override
  String get debugPrimaryColor => 'プライマリカラー';
  @override
  String get debugSurfaceColor => 'サーフェイスカラー';
  @override
  String get debugActionsSection => 'デバッグ操作';
  @override
  String get debugClearLogs => 'ログをクリア';
  @override
  String get debugClearLogsSuccess => 'ログをクリアしました';
  @override
  String get debugClearCache => 'キャッシュをクリア';
  @override
  String get debugClearCacheSuccess => 'キャッシュをクリアしました';
  @override
  String get debugTestCrash => 'クラッシュテスト';
  @override
  String get debugTestCrashTitle => 'クラッシュテスト';
  @override
  String get debugTestCrashBody => 'テストのためにアプリをクラッシュさせますか？';
  @override
  String get debugCopyAll => 'すべてコピー';
  @override
  String get debugCopiedToClipboard => 'クリップボードにコピーしました';
  @override
  String get debugCancel => 'キャンセル';
  @override
  String get debugCrash => 'クラッシュ';
  @override
  String get debugAppName => 'アプリ名';
  @override
  String get debugVersion => 'バージョン';
  @override
  String get debugBuildNumber => 'ビルド番号';
  @override
  String get debugGitCommit => 'Gitコミット';
  @override
  String get debugFlutterVersion => 'Flutterバージョン';
  @override
  String get debugDartVersion => 'Dartバージョン';
  @override
  String get debugPlatform => 'プラットフォーム';
  @override
  String get debugDesignSystem => 'デザインシステム';
  @override
  String get debugBuildDate => 'ビルド日時';
  @override
  String get debugIsDebugBuild => 'デバッグビルド';

  // ─── Logs page ────────────────────────────────────────────────────────
  @override
  String get logsTitle => 'ログ';
  @override
  String get logsAll => 'すべて';
  @override
  String get logsVerbose => 'Verbose';
  @override
  String get logsDebug => 'Debug';
  @override
  String get logsInfo => 'Info';
  @override
  String get logsWarning => 'Warning';
  @override
  String get logsError => 'Error';
  @override
  String get logsClear => 'クリア';
  @override
  String get logsClearConfirmTitle => 'ログをクリア';
  @override
  String get logsClearConfirmBody => 'メモリ上のログをすべて削除しますか？';
  @override
  String get logsClearSuccess => 'ログをクリアしました';
  @override
  String get logsDownload => 'エクスポート';
  @override
  String get logsDownloadSuccess => 'ログをファイルに保存しました';
  @override
  String get logsDownloadError => 'ログの保存に失敗しました';
  @override
  String get logsEmpty => 'ログはありません';
  @override
  String get logsCancel => 'キャンセル';
  @override
  String get logsConfirm => 'クリア';
  @override
  String get logsCopied => 'ログをコピーしました';

  // ─── Developer settings ───────────────────────────────────────────────
  @override
  String get settingsDeveloper => '開発者';
  @override
  String get settingsDebugMode => 'デバッグモード';
  @override
  String get settingsDebugModeSubtitle => 'ログとデバッグ情報のメニューを表示';
  @override
  String get settingsLogLevel => 'ログレベル';
  @override
  String get logLevelVerbose => 'Verbose';
  @override
  String get logLevelDebug => 'Debug';
  @override
  String get logLevelInfo => 'Info';
  @override
  String get logLevelWarning => 'Warning';
  @override
  String get logLevelError => 'Error';

  // ─── Bookmarks (sample feature) ──────────────────────────────────────
  @override
  String get bookmarksTitle => 'ブックマーク';
  @override
  String get bookmarksEmpty => 'ブックマークがありません';
  @override
  String get bookmarksEmptyHint => '保存したリンクは端末内の SQLite に保存されます。';
  @override
  String get bookmarksAdd => 'ブックマークを追加';
  @override
  String get bookmarksAddTitle => '新しいブックマーク';
  @override
  String get bookmarksTitleLabel => 'タイトル';
  @override
  String get bookmarksTitleHint => 'Flutter ドキュメント';
  @override
  String get bookmarksUrlLabel => 'URL';
  @override
  String get bookmarksUrlHint => 'https://docs.flutter.dev';
  @override
  String get bookmarksSave => '保存';
  @override
  String get bookmarksCancel => 'キャンセル';
  @override
  String get bookmarksInvalidInput => 'タイトルと http/https の URL を入力してください。';
  @override
  String get bookmarksSaved => 'ブックマークを保存しました';
  @override
  String get bookmarksRemoved => 'ブックマークを削除しました';
  @override
  String get bookmarkDetailTitle => 'ブックマーク';
  @override
  String get bookmarkNotFound => 'ブックマークが見つかりません';
  @override
  String get bookmarkNotFoundHint => '削除されたか、別の端末のリンクを開いた可能性があります。';
  @override
  String get bookmarkOpen => 'リンクを開く';
  @override
  String get bookmarkOpenFailed => 'このリンクを開けるアプリがありません';
  @override
  String get bookmarkRemove => '削除';
  @override
  String get bookmarkRemoveConfirmTitle => 'ブックマークの削除';
  @override
  String get bookmarkRemoveConfirmBody => 'このブックマークを端末から削除しますか？';
  @override
  String get bookmarkUrlLabel => 'URL';
  @override
  String get bookmarkCreatedAtLabel => '保存日時';
  @override
  String get bookmarkDeepLinkLabel => 'ディープリンク';

  // ─── Deep links (App Links) ──────────────────────────────────────────
  @override
  String get deepLinkTitle => 'ディープリンク';
  @override
  String get deepLinkIntro =>
      'Android の App Links は、検証済みの https URL を直接このアプリで開きます。'
      'ルーターはリンクのパスを、アプリ内遷移と同じルート定義に照合します。';
  @override
  String get deepLinkOpenedWith => '起動時の URL';
  @override
  String get deepLinkNoParameters => 'クエリパラメータはありません';
  @override
  String get deepLinkParameters => 'クエリパラメータ';
  @override
  String get deepLinkVerifiedSection => '検証済み App Link';
  @override
  String get deepLinkCustomSchemeSection => 'カスタムスキーム（未検証）';
  @override
  String get deepLinkTrySection => '動作確認';
  @override
  String get deepLinkTryHint => 'アプリをインストールした状態で実行すると、外部から起動できます。';
  @override
  String get deepLinkCopy => 'コピー';
  @override
  String get deepLinkCopied => 'クリップボードにコピーしました';

  // ─── Licenses page ───────────────────────────────────────────────────
  @override
  String get licensesTitle => 'ライセンス';
  @override
  String get licensesDetails => '詳細は各パッケージのライセンスファイルをご参照ください。';

  // ─── Common ──────────────────────────────────────────────────────────
  @override
  String get commonRetry => '再試行';
  @override
  String get commonMenu => 'メニュー';
  @override
  String get commonNotifications => '通知';
  @override
  String get commonNotFound => '404 - ページが見つかりません';
  @override
  String get commonPageNotFound => 'ページが見つかりません';
  @override
  String get commonLoading => '読み込み中...';
  @override
  String get commonError => 'エラーが発生しました';
  @override
  String get commonEmpty => 'データがありません';
}
