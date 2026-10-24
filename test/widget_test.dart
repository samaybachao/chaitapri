import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chai_tapri/app/app.dart';
import 'package:chai_tapri/app/app_services.dart';
import 'package:chai_tapri/app/bootstrap.dart';
import 'package:chai_tapri/app/constants.dart';
import 'package:chai_tapri/core/config.dart';
import 'package:chai_tapri/core/game_state.dart';
import 'package:chai_tapri/services/clock.dart';
import 'package:chai_tapri/services/key_value_store.dart';
import 'package:chai_tapri/services/save_service.dart';
import 'package:chai_tapri/state/settings_controller.dart';
import 'package:chai_tapri/ui/scene/stall_scene.dart';

import 'support/fakes.dart';
import 'support/test_support.dart';

const String _englishChosen = '{"v":1,"lang":"en","vibration":true}';

class _Env {
  _Env({required this.services, required this.links, required this.ads});

  final AppServices services;
  final FakeLinks links;
  final FakeAdsService ads;
}

/// Builds the real app services on in-memory storage and fake ads / links.
Future<_Env> _start(
  WidgetTester tester, {
  bool languageChosen = true,
  void Function(GameConfig config, GameState state)? prepare,
}) async {
  // A tall phone-like screen, so that nothing needed by a test is scrolled out of view.
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final MemoryKeyValueStore store = MemoryKeyValueStore();
  final FakeClock clock = FakeClock(DateTime(2026, 10, 24, 12));
  final FakeLinks links = FakeLinks();
  final FakeAdsService ads = FakeAdsService();

  if (languageChosen) {
    store.values[SettingsController.storageKey] = _englishChosen;
  }
  if (prepare != null) {
    final GameConfig config = loadTestConfig();
    final GameState state = GameState.initial(config, nowMs: clock.nowMs());
    state.sessions = 1;
    prepare(config, state);
    await tester.runAsync(() => SaveService(store).save(state));
  }

  final AppServices? services = await tester.runAsync(
    () => bootstrap(
      store: store,
      clock: clock,
      ads: ads,
      links: links,
      analytics: MemoryAnalytics(),
      runLoop: false,
    ),
  );
  return _Env(services: services!, links: links, ads: ads);
}

/// Shows the app and lets the start-up animations (dialogs, route changes) play.
Future<void> _show(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(ChaiTapriApp(bootstrapper: () async => services));
  await _settle(tester);
}

/// The stall scene animates forever, so `pumpAndSettle` would never return.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Removes the app so that its services are disposed.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  silenceDebugPrint();

  testWidgets('first start asks for the language and switches to Hindi', (WidgetTester tester) async {
    final _Env env = await _start(tester, languageChosen: false);
    await _show(tester, env.services);

    expect(find.text('English'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);

    await tester.tap(find.text('हिन्दी'));
    await _settle(tester);

    expect(env.services.settings.languageCode, 'hi');
    expect(env.services.settings.languageChosen, isTrue);
    expect(find.text('अपग्रेड'), findsWidgets);
    expect(find.text('English'), findsNothing);
    await _close(tester);
  });

  testWidgets('tapping the stall earns coins and moves the tutorial', (WidgetTester tester) async {
    final _Env env = await _start(tester);
    await _show(tester, env.services);

    expect(find.byType(StallScene), findsOneWidget);
    expect(find.textContaining('Tap the stall to brew chai!'), findsOneWidget);

    await tester.tap(find.byType(StallScene));
    await tester.pump(const Duration(milliseconds: 100));

    expect(env.services.game.state.totalTaps, 1);
    expect(env.services.game.coins.value, greaterThan(0));
    expect(find.textContaining('(1/'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('the three tabs show their content and the daily reward can be collected', (
    WidgetTester tester,
  ) async {
    final _Env env = await _start(tester);
    await _show(tester, env.services);

    expect(find.text('Chulha'), findsOneWidget);

    await tester.tap(find.text('Menu'));
    await _settle(tester);
    expect(find.text('Cutting chai'), findsOneWidget);
    expect(find.text('Railway Station Stall'), findsOneWidget);

    await tester.tap(find.text('Daily'));
    await _settle(tester);
    expect(find.text('Daily reward'), findsOneWidget);
    expect(env.services.game.dailyAvailable, isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Collect'));
    await _settle(tester);
    expect(env.services.game.dailyAvailable, isFalse);
    expect(env.services.game.coins.value, greaterThanOrEqualTo(100));
    expect(find.text('Collected! See you tomorrow.'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('an upgrade can be bought when there are enough coins', (WidgetTester tester) async {
    final _Env env = await _start(tester);
    await _show(tester, env.services);

    env.services.game.engine.addCoins(1000);
    env.services.game.advance(0.01);
    await tester.pump(const Duration(milliseconds: 100));

    final Finder buyButtons = find.byType(FilledButton);
    expect(buyButtons, findsWidgets);
    final int before = env.services.game.state.levels[0];
    env.services.game.buyUpgrade(0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(env.services.game.state.levels[0], before + 1);
    expect(find.textContaining('Lv 1'), findsWidgets);
    await _close(tester);
  });

  testWidgets('welcome back pays the offline earnings', (WidgetTester tester) async {
    final _Env env = await _start(
      tester,
      prepare: (GameConfig config, GameState state) {
        state.tutorialStep = 3;
        state.levels[0] = 5;
        state.levels[3] = 5;
        state.lastSeenMs = DateTime(2026, 10, 24, 10).millisecondsSinceEpoch;
      },
    );
    await _show(tester, env.services);

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(env.services.game.hasPendingOffline, isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Collect'));
    await _settle(tester);

    expect(find.text('Welcome back!'), findsNothing);
    expect(env.services.game.hasPendingOffline, isFalse);
    expect(env.services.game.coins.value, greaterThan(0));
    await _close(tester);
  });

  testWidgets('settings: privacy policy link and reset progress', (WidgetTester tester) async {
    final _Env env = await _start(tester);
    await _show(tester, env.services);

    env.services.game.engine.addCoins(500);
    env.services.game.buyUpgrade(0);
    expect(env.services.game.state.levels[0], 1);

    await tester.tap(find.byIcon(Icons.settings));
    await _settle(tester);
    expect(find.text('Version $kAppVersion'), findsOneWidget);

    await tester.tap(find.text('Privacy policy'));
    await tester.pump();
    expect(env.links.opened, <String>[kPrivacyPolicyUrl]);

    await tester.tap(find.text('Reset progress'));
    await _settle(tester);
    expect(find.text('Reset progress?'), findsOneWidget);

    await tester.tap(find.text('Delete everything'));
    await _settle(tester);

    expect(env.services.game.state.levels[0], 0);
    expect(env.services.game.coins.value, 0);
    expect(env.services.settings.languageCode, 'en');
    expect(find.text('Version $kAppVersion'), findsNothing, reason: 'back on the main screen');
    await _close(tester);
  });

  testWidgets('start-up errors show a retry button', (WidgetTester tester) async {
    int attempts = 0;
    final AppServices good = (await _start(tester)).services;
    await tester.pumpWidget(
      ChaiTapriApp(
        bootstrapper: () async {
          attempts += 1;
          if (attempts == 1) {
            throw StateError('storage is broken');
          }
          return good;
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await _settle(tester);

    expect(attempts, 2);
    expect(find.text('Something went wrong'), findsNothing);
    expect(find.byType(StallScene), findsOneWidget);
    await _close(tester);
  });
}
