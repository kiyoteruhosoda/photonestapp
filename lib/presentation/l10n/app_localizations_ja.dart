import 'package:photonest/presentation/l10n/app_localizations.dart';

/// Japanese localisations.
class AppLocalizationsJa extends AppLocalizations {
  const AppLocalizationsJa();

  // ─── Navigation ───────────────────────────────────────────────────────
  @override
  String get appName => 'PhotoNest';
  @override
  String get navHome => 'ホーム';
  @override
  String get navSettings => '設定';
  @override
  String get navAlbums => 'アルバム';
  @override
  String get navPhotos => '写真';
  @override
  String get navUpload => 'アップロード';

  // ─── Login ────────────────────────────────────────────────────────────
  @override
  String get loginTitle => 'ログイン';
  @override
  String get loginSubtitle => 'PhotoNest サーバーにログインします';
  @override
  String get loginServerLabel => 'サーバー URL';
  @override
  String get loginServerHint => 'https://photos.example.com';
  @override
  String get loginEmailLabel => 'メールアドレス';
  @override
  String get loginEmailHint => 'you@example.com';
  @override
  String get loginPasswordLabel => 'パスワード';
  @override
  String get loginSubmit => 'ログイン';
  @override
  String get loginErrorInvalidInput => 'サーバー URL・メールアドレス・パスワードを確認してください。';
  @override
  String get loginErrorInvalidCredentials => 'メールアドレスまたはパスワードが正しくありません。';
  @override
  String get loginErrorNetwork => 'サーバーに接続できません。URL と通信環境を確認してください。';
  @override
  String get loginTotpLabel => '認証アプリのコード';
  @override
  String get loginTotpRequired => 'このアカウントは二要素認証を使っています。認証アプリのコードを入力してください。';
  @override
  String get loginErrorInvalidTotp => 'コードが一致しません。次に表示されるコードで試してください。';

  // ─── Albums ───────────────────────────────────────────────────────────
  @override
  String get albumsTitle => 'アルバム';
  @override
  String get albumsEmpty => 'アルバムがありません';
  @override
  String get albumsEmptyHint => 'サーバーで作成したアルバムがここに表示されます。';
  @override
  String albumsMediaCount(int count) => '$count 件';
  @override
  String get albumNotFound => 'アルバムが見つかりません';
  @override
  String get albumNotFoundHint => 'サーバー側で削除された可能性があります。';
  @override
  String get albumEmpty => 'このアルバムにはまだ写真がありません。';

  @override
  String get albumLoadMoreRetry => '続きを読み込めませんでした。タップで再試行できます。';

  // ─── Albums: creating, renaming, filing photos ────────────────────────
  @override
  String get albumCreateTitle => '新しいアルバム';
  @override
  String get albumEditTitle => 'アルバム名を変更';
  @override
  String get albumNameLabel => '名前';
  @override
  String get albumDescriptionLabel => '説明（任意）';
  @override
  String get albumNameRequired => 'アルバムの名前を入力してください。';
  @override
  String get albumSaveFailed => 'アルバムを保存できませんでした。';
  @override
  String get albumCreateAction => '作成';
  @override
  String get albumRenameAction => '保存';
  @override
  String albumCreated(String title) => '「$title」を作成しました。';
  @override
  String get albumAddToAlbum => 'アルバムへ追加';
  @override
  String get albumPickerTitle => 'アルバムへ追加';
  @override
  String get albumPickerNewAlbum => '新しいアルバム…';
  @override
  String get albumPickerEmpty => 'アルバムがありません。作成するとこの写真を入れられます。';
  @override
  String albumAddedTo(String title) => '「$title」へ追加しました。';
  @override
  String albumAlreadyContains(String title) => '「$title」にはすでに入っています。';
  @override
  String get albumAddFailed => 'アルバムへ追加できませんでした。';

  // ─── Photos (library timeline) ────────────────────────────────────────

  @override
  String get photosEmpty => 'サーバーにまだ写真がありません。';
  @override
  String get photosUndatedSection => '撮影日不明';
  @override
  String get photosLoadMoreRetry => '続きを読み込めませんでした。再試行';

  @override
  String get mediaVideoLabel => '動画';
  @override
  String mediaViewerPosition(int position, int total) => '$position / $total';
  @override
  String get mediaShowOriginal => '原本を表示';
  @override
  String get mediaOriginalUnavailable => '原本を読み込めませんでした。';
  @override
  String get mediaSaveToDevice => '端末に保存';
  @override
  String get mediaSaveDone => '端末に保存しました。';
  @override
  String get mediaSaveNoAccess => '保存するには写真ライブラリへのアクセス許可が必要です。';
  @override
  String get mediaSaveDownloadFailed => '原本をダウンロードできませんでした。';
  @override
  String get mediaSaveWriteFailed => '端末に保存できませんでした。';
  @override
  String get mediaAddFavorite => 'お気に入りに追加';
  @override
  String get mediaRemoveFavorite => 'お気に入りから外す';
  @override
  String get mediaFavoriteFailed => 'お気に入りを変更できませんでした。';
  @override
  String get mediaMoveToTrash => 'ゴミ箱へ移動';
  @override
  String get mediaMoveToTrashConfirm => 'ゴミ箱へ移動しますか？サーバーが完全に削除するまでは元に戻せます。';
  @override
  String get mediaMovedToTrash => 'ゴミ箱へ移動しました。';
  @override
  String get mediaTrashFailed => 'ゴミ箱へ移動できませんでした。';

  @override
  String get mediaTagsTitle => 'タグ';
  @override
  String get mediaTagsSave => '保存';
  @override
  String get mediaTagsNoneOnMedia => 'このアイテムにはまだタグがありません。';
  @override
  String get mediaTagsSearchLabel => 'タグを検索';
  @override
  String get mediaTagsNoMatches => '一致するタグがありません。';
  @override
  String mediaTagsCreate(String name) => '「$name」を作る';
  @override
  String get tagAttributeThing => 'もの';
  @override
  String get tagAttributePerson => '人物';
  @override
  String get tagAttributePlace => '場所';
  @override
  String get tagAttributeEvent => 'イベント';
  @override
  String get tagAttributeScene => 'シーン';
  @override
  String get tagAttributeActivity => '活動';
  @override
  String get tagAttributeSource => '出典';
  @override
  String get tagAttributeOthers => 'その他';

  @override
  String get videoNotReady => '動画はサーバーで準備中です。しばらくしてからもう一度お試しください。';

  @override
  String get videoUnavailable => 'この動画は再生できません。';

  // ─── Trash ────────────────────────────────────────────────────────────
  @override
  String get trashTitle => 'ゴミ箱';
  @override
  String get trashEmpty => 'ゴミ箱は空です';
  @override
  String get trashRestore => '元に戻す';
  @override
  String get trashRestored => '元に戻しました。';
  @override
  String get trashRestoreFailed => '元に戻せませんでした。ファイルが既に完全に削除された可能性があります。';

  // ─── Upload ───────────────────────────────────────────────────────────
  @override
  String get uploadAutoTitle => '新しい写真を自動アップロード';
  @override
  String get uploadAutoSubtitle => 'これから撮影した写真を自動的にアップロードします。';
  @override
  String get uploadAutoDenied => '自動アップロードには写真ライブラリへのアクセス許可が必要です。';
  @override
  String get uploadAutoUnmeteredTitle => 'Wi-Fi 接続時のみ';
  @override
  String get uploadAutoUnmeteredSubtitle => 'モバイル通信では自動アップロードせず、Wi-Fi 接続を待ちます。';
  @override
  String get uploadAutoAlbumsTitle => 'バックアップする対象';
  @override
  String get uploadAutoAlbumsAll => 'この端末のすべて';
  @override
  String uploadAutoAlbumsCount(int count) => '$count 個のアルバム';
  @override
  String get uploadAutoAlbumsDialogTitle => 'バックアップする対象';
  @override
  String get uploadAutoAlbumsAllOption => 'この端末のすべて';
  @override
  String get uploadAutoAlbumsAllOptionSubtitle => 'スクリーンショット・保存した画像・動画も含まれます。';
  @override
  String get uploadAutoAlbumsEmpty => 'この端末にアルバムが見つかりません。';
  @override
  String get uploadAutoAlbumsPickOne => 'アルバムを 1 つ以上選んでください。';
  @override
  String uploadAutoAlbumsItemCount(int count) => '$count 件';
  @override
  String get uploadPermissionTitle => '写真へのアクセスがありません';
  @override
  String get uploadPermissionBody => '写真をアップロードするには、写真ライブラリへのアクセスを許可してください。';
  @override
  String get uploadPermissionRetry => 'アクセスを許可';
  @override
  String get uploadEmpty => 'この端末に写真が見つかりません。';
  @override
  String get uploadRecentSection => '最近の写真';
  @override
  String uploadSelectedCount(int count) => '$count 件選択中';
  @override
  String get uploadSubmit => '選択した写真をアップロード';
  @override
  String uploadDone(int count) => '$count 件アップロードしました。';
  @override
  String uploadFailed(int count) => '$count 件アップロードできませんでした。';
  @override
  String get uploadUploadedBadge => 'アップロード済み';
  @override
  String uploadProgress(int completed, int total) =>
      '$total 件中 $completed 件をアップロード中…';
  @override
  String get uploadCancel => 'キャンセル';
  @override
  String get uploadCancelled => 'アップロードを中止しました。';
  @override
  String get uploadShowFailures => '詳細';
  @override
  String uploadFailureAttempts(int attempts) => '$attempts 回失敗';
  @override
  String get uploadFailureAutomatic => '自動アップロード';
  @override
  String get uploadFailureListTitle => 'アップロードに失敗した写真';
  @override
  String get uploadFailureMissing => '端末のライブラリに見つかりません。';
  @override
  String get uploadFailureUnsupported => '対応していないファイル形式です。';
  @override
  String get uploadFailureRejected => 'サーバーがこの写真を受け付けませんでした。';

  // ─── Session / sign out ───────────────────────────────────────────────
  @override
  String get settingsSignOut => 'ログアウト';
  @override
  String get settingsSignOutConfirmTitle => 'ログアウトしますか？';
  @override
  String get settingsSignOutConfirmBody => '再度ログインするまで自動アップロードは停止します。';
  @override
  String get settingsSignOutCancel => 'キャンセル';
  @override
  String get settingsSignedInAs => 'ログイン中のアカウント';

  // ─── Account (credentials) ────────────────────────────────────────────
  @override
  String get accountTitle => 'アカウント';
  @override
  String get accountOpen => 'パスワードと二要素認証';
  @override
  String get accountEmailLabel => 'ログイン中のアカウント';
  @override
  String get accountPasswordSection => 'パスワード';
  @override
  String get accountPasswordHint => 'ここで変更しても、この端末はログインしたままです。';
  @override
  String get accountPasswordNewLabel => '新しいパスワード';
  @override
  String get accountPasswordConfirmLabel => '新しいパスワード（確認）';
  @override
  String accountPasswordTooShort(int minimum) => '$minimum 文字以上にしてください。';
  @override
  String get accountPasswordMismatch => '2 つの入力が一致しません。';
  @override
  String get accountPasswordChange => 'パスワードを変更';
  @override
  String get accountPasswordChanged => 'パスワードを変更しました。';
  @override
  String get accountPasswordFailed => 'パスワードを変更できませんでした。';
  @override
  String get accountTwoFactorSection => '二要素認証';
  @override
  String get accountTwoFactorOn => '有効 — ログイン時にコードを訊かれます。';
  @override
  String get accountTwoFactorOff => '無効 — ログインはパスワードだけです。';
  @override
  String get accountTwoFactorEnable => '有効にする';
  @override
  String get accountTwoFactorDisable => '無効にする';
  @override
  String get accountTwoFactorDisableConfirmTitle => '二要素認証を無効にしますか？';
  @override
  String get accountTwoFactorDisableConfirmBody => '以降のログインはパスワードだけになります。';
  @override
  String get accountTwoFactorDisabled => '二要素認証を無効にしました。';
  @override
  String get accountTwoFactorEnabled => '二要素認証を有効にしました。';
  @override
  String get accountTwoFactorFailed => '二要素認証を変更できませんでした。';
  @override
  String get accountTwoFactorSetupTitle => '二要素認証を有効にする';
  @override
  String get accountTwoFactorSetupIntro =>
      '認証アプリにこのアカウントを登録し、表示されたコードを入力してください。';
  @override
  String get accountTwoFactorOpenApp => '認証アプリで開く';
  @override
  String get accountTwoFactorNoApp => '認証アプリが見つかりません。下のセットアップキーを使ってください。';
  @override
  String get accountTwoFactorSecretLabel => 'セットアップキー';
  @override
  String get accountTwoFactorSecretCopied => 'セットアップキーをコピーしました。';
  @override
  String get accountTwoFactorScanHint => '別の端末から読み取る場合はこちら。';
  @override
  String get accountTwoFactorCodeLabel => 'アプリに表示されたコード';
  @override
  String get accountTwoFactorCodeRequired => '認証アプリのコードを入力してください。';
  @override
  String get accountTwoFactorConfirm => '確認して有効にする';
  @override
  String get accountTwoFactorInvalidCode => 'コードが一致しません。次に表示されるコードで試してください。';
  @override
  String get accountPasskeysUnavailable => 'パスキーはブラウザの PhotoNest から設定します。';

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
  String get drawerDeepLink => 'ディープリンク';

  // ─── Media search ─────────────────────────────────────────────────────
  @override
  String get searchFieldLabel => '検索';
  @override
  String get searchFieldHint => 'ファイル名・カメラ・キャプション・タグ';
  @override
  String get searchNoResults => '条件に合う写真がありません';
  @override
  String get searchClearFilters => '条件をクリア';
  @override
  String get searchFilterAll => 'すべて';
  @override
  String get searchFilterPhotos => '写真';
  @override
  String get searchFilterVideos => '動画';
  @override
  String get searchFilterFavorites => 'お気に入り';

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

  // ─── Notifications ───────────────────────────────────────────────────
  @override
  String get notificationsTitle => '通知';
  @override
  String get notificationsEmpty => '通知はまだありません';
  @override
  String get notificationsEmptyHint => 'バックアップの結果がここに表示されます。';
  @override
  String get notificationBackupCompleted => 'バックアップが完了しました';
  @override
  String get notificationBackupHadFailures => 'バックアップでエラーが発生しました';

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

  // ─── Common ──────────────────────────────────────────────────────────
  @override
  String get commonRetry => '再試行';
  @override
  String get commonClose => '閉じる';
  @override
  String get commonCancel => 'キャンセル';
  @override
  String get commonSave => '保存';
  @override
  String get commonErrorNetwork => 'サーバーに接続できませんでした。通信環境を確認して再試行してください。';
  @override
  String get commonErrorSessionExpired => 'セッションの有効期限が切れました。もう一度ログインしてください。';
  @override
  String get commonMenu => 'メニュー';
  @override
  String get commonNotifications => '通知';
  @override
  String get commonNotFound => '404 - ページが見つかりません';
  @override
  String get commonPageNotFound => 'ページが見つかりません';
  @override
  String get commonError => 'エラーが発生しました';
}
