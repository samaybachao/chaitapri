import 'package:flutter/material.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/app/app_services.dart';
import 'package:chai_tapri/app/bootstrap.dart';
import 'package:chai_tapri/ui/screens/boot_screens.dart';
import 'package:chai_tapri/ui/screens/home_screen.dart';
import 'package:chai_tapri/ui/theme.dart';

/// Creates the services; tests pass a version with fakes.
typedef Bootstrapper = Future<AppServices> Function();

Future<AppServices> _defaultBootstrapper() => bootstrap();

/// Widest the game is drawn; on tablets and foldables it is centred.
const double kMaxContentWidth = 520;

/// The root widget: loads the game, then shows the home screen.
class ChaiTapriApp extends StatefulWidget {
  const ChaiTapriApp({super.key, this.bootstrapper = _defaultBootstrapper});

  final Bootstrapper bootstrapper;

  @override
  State<ChaiTapriApp> createState() => _ChaiTapriAppState();
}

class _ChaiTapriAppState extends State<ChaiTapriApp> with WidgetsBindingObserver {
  late Future<AppServices> _future;
  AppServices? _services;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _start();
  }

  Future<AppServices> _start() async {
    final AppServices services = await widget.bootstrapper();
    if (_disposed) {
      services.dispose();
    } else {
      _services = services;
    }
    return services;
  }

  void _retry() {
    setState(() {
      _future = _start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _services?.game.handleLifecycle(state);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _services?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<AppServices> snapshot) {
        final AppServices? services = snapshot.data;
        if (services != null) {
          return AppScope(services: services, child: _GameApp(services: services));
        }
        if (snapshot.hasError) {
          debugPrint('Start-up failed: ${snapshot.error}');
          return _shell(BootErrorScreen(onRetry: _retry));
        }
        return _shell(const SplashScreen());
      },
    );
  }

  Widget _shell(Widget home) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: home,
    );
  }
}

class _GameApp extends StatelessWidget {
  const _GameApp({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (BuildContext context) => context.t('app_name'),
      theme: buildTheme(),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25),
          ),
          child: ColoredBox(
            color: AppColors.cream,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}
