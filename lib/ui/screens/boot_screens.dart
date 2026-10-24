import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'package:chai_tapri/l10n/strings.dart';
import 'package:chai_tapri/ui/theme.dart';

Strings _systemStrings() {
  return Strings.forLanguage(languageForSystem(PlatformDispatcher.instance.locale.languageCode));
}

/// Shown while the game loads (usually well under a second).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Strings strings = _systemStrings();
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.local_cafe, size: 84, color: AppColors.chai),
            const SizedBox(height: 12),
            Text(
              strings.t('app_name'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.chai,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.saffronDark),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the game could not start (damaged data, unreadable storage).
class BootErrorScreen extends StatelessWidget {
  const BootErrorScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Strings strings = _systemStrings();
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 64, color: AppColors.chili),
              const SizedBox(height: 12),
              Text(
                strings.t('boot_error_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(strings.t('boot_error_body'), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRetry,
                style: gameButtonStyle(minWidth: 140),
                child: Text(strings.t('try_again')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
