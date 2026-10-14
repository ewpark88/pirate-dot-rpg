import 'dart:ui';

import 'package:pirate_dot/l10n/gen/app_localizations.dart';

/// 알림 한 건의 문구 (`parts/platform.*.arb`).
class NotifyTexts {
  const NotifyTexts({required this.title, required this.body, required this.channelName});

  final String title;
  final String body;

  /// Android 알림 채널 이름(시스템 설정에 보인다).
  final String channelName;
}

/// [lang]은 `settings.lang`: `system` | `ko` | `en`. 위젯 밖이라 `lookupAppLocalizations`로 찾는다.
NotifyTexts notifyTextsFor(String lang) {
  final code = lang == 'system' ? PlatformDispatcher.instance.locale.languageCode : lang;
  final supported = AppLocalizations.supportedLocales.any((l) => l.languageCode == code);
  final l = lookupAppLocalizations(Locale(supported ? code : 'en'));
  return NotifyTexts(
    title: l.platformNotifyOfflineFullTitle,
    body: l.platformNotifyOfflineFullBody,
    channelName: l.platformNotifyChannelName,
  );
}
