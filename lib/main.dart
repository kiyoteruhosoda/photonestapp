import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/app/bootstrap/app_widget.dart';
import 'package:flutterbase/app/di/provider_overrides.dart';
import 'package:flutterbase/app/di/service_locator.dart';
import 'package:flutterbase/presentation/licenses/app_license_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ステータスバーをシースルーに設定
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  // 縦向き固定 (必要に応じてコメントアウト)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 依存性注入の初期化
  await setupServiceLocator();

  // LicenseRegistry に独自ライセンスを登録
  AppLicenseRegistrar.register();

  // ProviderScope は Riverpod のルート。overrides で合成ルートが
  // Presentation の provider に実体を注入する
  // (lib/app/di/provider_overrides.dart)。
  runApp(
    ProviderScope(
      overrides: buildProviderOverrides(),
      // Riverpod 3 は失敗した provider を既定で自動リトライする。この
      // アプリはエラー表示に明示的な「再試行」を置いているので、裏で
      // サーバーを叩き直す自動リトライは無効にする。
      retry: (retryCount, error) => null,
      child: const AppWidget(),
    ),
  );
}
