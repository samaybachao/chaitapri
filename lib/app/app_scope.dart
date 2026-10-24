import 'package:flutter/widgets.dart';

import 'package:chai_tapri/app/app_services.dart';
import 'package:chai_tapri/state/settings_controller.dart';

/// Gives every screen access to the services. Widgets that call [AppScope.of] or
/// `context.t(...)` are rebuilt when the settings (language) change.
class AppScope extends InheritedNotifier<SettingsController> {
  AppScope({super.key, required this.services, required super.child})
    : super(notifier: services.settings);

  final AppServices services;

  /// The services; rebuilds the caller when the settings change.
  static AppServices of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.services;
  }

  /// The services, without rebuilding the caller when the settings change.
  static AppServices read(BuildContext context) {
    final AppScope? scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.services;
  }
}

extension AppContext on BuildContext {
  /// The services (rebuilds when the language changes).
  AppServices get app => AppScope.of(this);

  /// A text of the current language, e.g. `context.t('tab_menu')`.
  String t(String key, [Map<String, Object>? args]) {
    return AppScope.of(this).settings.strings.t(key, args);
  }
}
