import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chai_tapri/app/app.dart';
import 'package:chai_tapri/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  // Errors outside the widget tree: log them and keep the game running.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Unhandled error: $error\n$stack');
    return true;
  };

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.cream,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ChaiTapriApp());
}
