import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_toggle.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';

// 설정 '정보' (출시 준비, S1 2026-10-18): 개인정보처리방침 · 이용약관 · 문의하기(메일 앱) · 버전.
// 주소는 여기 상수 자리(docs/store — 게시 블로그 · 문의 메일). 링크 열기는 앱이 url_launcher로 덮는다(pubspec은 S1) —
// 덮기 전엔 주소를 클립보드에 넣고 알린다.

/// 개인정보처리방침 공개 주소(docs/store/privacy-policy — 블로그 게시).
const privacyPolicyUrl = 'https://rich-fire.blogspot.com/p/privacy-policy.html';

/// 이용약관 공개 주소.
const termsUrl = 'https://rich-fire.blogspot.com/p/terms.html';

/// 문의 메일(docs/store/privacy-policy 문의처).
const contactEmail = 'repo.dev88@gmail.com';

/// 앱 버전(빌드 때 --dart-define=APP_VERSION=1.0.0+12, 없으면 pubspec 기본).
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1');

/// 링크·메일 열기. 열었으면 true. 기본 null = 열 수 없음(클립보드로 대신).
final appLinkOpenerProvider = Provider<Future<bool> Function(Uri uri)?>((_) => null);

Future<void> openAppLink(BuildContext context, WidgetRef ref, Uri uri, String copyText) async {
  final open = ref.read(appLinkOpenerProvider);
  if (open != null && await open(uri)) return;
  await Clipboard.setData(ClipboardData(text: copyText));
  if (context.mounted) showSkinToast(context, AppLocalizations.of(context).uiLinkCopied);
}

class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget link(String key, IconData icon, String label, Uri uri, String copy) => PixelListRow(
      key: Key(key),
      leading: Icon(icon, color: Skin.sub),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded, color: Skin.sub),
      onTap: () => unawaited(openAppLink(context, ref, uri, copy)),
    );
    return Column(
      children: [
        link(
          'settings.privacyPolicy',
          Icons.privacy_tip_rounded,
          l10n.uiSettingsPrivacy,
          Uri.parse(privacyPolicyUrl),
          privacyPolicyUrl,
        ),
        link('settings.terms', Icons.description_rounded, l10n.uiSettingsTerms, Uri.parse(termsUrl), termsUrl),
        link(
          'settings.contact',
          Icons.mail_rounded,
          l10n.uiSettingsContact,
          Uri(scheme: 'mailto', path: contactEmail, queryParameters: {'subject': l10n.uiContactSubject}),
          contactEmail,
        ),
        PixelListRow(
          key: const Key('settings.version'),
          leading: const Icon(Icons.info_outline_rounded, color: Skin.sub),
          title: Text(l10n.uiSettingsVersion(appVersion)),
        ),
      ],
    );
  }
}
