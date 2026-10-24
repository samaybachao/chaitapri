import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chai_tapri/app/constants.dart';

/// Opens web pages, the Play Store and the mail app.
abstract class LinkOpener {
  /// Opens [url] outside the game. Returns false when nothing could handle it.
  Future<bool> open(String url);

  /// The privacy policy page.
  Future<bool> openPrivacyPolicy() => open(kPrivacyPolicyUrl);

  /// The Play Store page of the game ("Rate us"): the Play Store app first, the web
  /// page when the app cannot be opened.
  Future<bool> openStorePage() async {
    if (await open(kPlayStoreMarketUrl)) {
      return true;
    }
    return open(kPlayStoreWebUrl);
  }

  /// A new e-mail to the support address. (`Uri.encodeComponent` writes spaces as %20,
  /// which every mail app understands; `queryParameters` would write "+".)
  Future<bool> openSupportMail({required String subject}) {
    return open('mailto:$kContactEmail?subject=${Uri.encodeComponent(subject)}');
  }
}

/// The real implementation (url_launcher).
class UrlLauncherLinks extends LinkOpener {
  UrlLauncherLinks();

  @override
  Future<bool> open(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Could not open $url: $error');
      return false;
    }
  }
}
