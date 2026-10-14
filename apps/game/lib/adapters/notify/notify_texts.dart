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
/// [hours]는 가득 차는 시간(`meta.offline.maxSec`) — 문구에 숫자를 박지 않는다.
/// 톤(설계서 4.9): 재촉·손해 강조 없이 "모아 뒀다"만 알린다.
NotifyTexts notifyTextsFor(String lang, {required int hours}) {
  final code = lang == 'system' ? PlatformDispatcher.instance.locale.languageCode : lang;
  final supported = AppLocalizations.supportedLocales.any((l) => l.languageCode == code);
  final l = lookupAppLocalizations(Locale(supported ? code : 'en'));
  return NotifyTexts(
    title: l.platformNotifyOfflineFullTitle,
    body: l.platformNotifyOfflineFullBody(hours),
    channelName: l.platformNotifyChannelName,
  );
}
