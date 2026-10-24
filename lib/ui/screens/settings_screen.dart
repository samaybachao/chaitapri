import 'package:flutter/material.dart';

import 'package:chai_tapri/app/app_scope.dart';
import 'package:chai_tapri/app/app_services.dart';
import 'package:chai_tapri/app/constants.dart';
import 'package:chai_tapri/l10n/strings.dart';
import 'package:chai_tapri/ui/dialogs/dialogs.dart';
import 'package:chai_tapri/ui/theme.dart';
import 'package:chai_tapri/ui/widgets/feedback.dart';

/// Language, vibration, privacy, support and reset.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _open(BuildContext context, Future<bool> Function() action) async {
    final bool ok = await action();
    if (!ok && context.mounted) {
      showToast(context, context.t('link_failed'));
    }
  }

  Future<void> _reset(BuildContext context) async {
    final AppServices services = AppScope.read(context);
    final bool confirmed = await showResetDialog(context);
    if (!confirmed) {
      return;
    }
    await services.game.resetProgress();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = context.app;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t('settings_title'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: <Widget>[
                _SectionCard(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        context.t('set_language'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            backgroundColor: AppColors.cream,
                            foregroundColor: AppColors.chai,
                            selectedBackgroundColor: AppColors.chai,
                            selectedForegroundColor: Colors.white,
                          ),
                          segments: <ButtonSegment<String>>[
                            for (final String code in kSupportedLanguages)
                              ButtonSegment<String>(
                                value: code,
                                label: Text(Strings.forLanguage(code).t('lang_$code')),
                              ),
                          ],
                          selected: <String>{services.settings.languageCode},
                          onSelectionChanged: (Set<String> picked) {
                            if (picked.isNotEmpty) {
                              services.settings.setLanguage(picked.first);
                            }
                          },
                        ),
                      ),
                    ),
                    SwitchListTile(
                      value: services.settings.vibration,
                      onChanged: services.settings.setVibration,
                      activeThumbColor: AppColors.leaf,
                      secondary: const Icon(Icons.vibration, color: AppColors.chai),
                      title: Text(context.t('set_vibration')),
                    ),
                  ],
                ),
                ListenableBuilder(
                  listenable: services.ads,
                  builder: (BuildContext context, Widget? child) {
                    return _SectionCard(
                      children: <Widget>[
                        _Entry(
                          icon: Icons.policy,
                          label: context.t('set_privacy_policy'),
                          onTap: () => _open(context, services.links.openPrivacyPolicy),
                        ),
                        if (services.ads.privacyOptionsRequired)
                          _Entry(
                            icon: Icons.privacy_tip,
                            label: context.t('set_privacy_options'),
                            onTap: services.ads.showPrivacyOptions,
                          ),
                        _Entry(
                          icon: Icons.rate_review,
                          label: context.t('set_rate'),
                          onTap: () => _open(context, services.links.openStorePage),
                        ),
                        _Entry(
                          icon: Icons.mail,
                          label: context.t('set_contact'),
                          onTap: () => _open(
                            context,
                            () => services.links.openSupportMail(subject: kAppName),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                _SectionCard(
                  children: <Widget>[
                    _Entry(
                      icon: Icons.delete_forever,
                      label: context.t('set_reset'),
                      color: AppColors.chili,
                      onTap: () => _reset(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    context.t('set_version', <String, Object>{'version': kAppVersion}),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    context.t('set_credits', <String, Object>{'name': kDeveloperName}),
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.chai,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color == AppColors.chili ? color : AppColors.ink)),
      onTap: onTap,
    );
  }
}
