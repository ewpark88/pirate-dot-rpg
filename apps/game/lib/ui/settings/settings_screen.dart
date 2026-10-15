import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_bitmap.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_toggle.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 설정 화면 (설계서 4.12). 바꾸면 SetSetting만 보낸다 — 화면은 엔진이 돌려준 상태로 다시 그린다.
// TODO(ui): 알림, 크레딧(LICENSES.json), 버전 글자(운영자 열기를 그리로 옮김) — 다음 계획.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Settings에는 ==가 없어서 값 9개를 레코드로 골라 구독한다.
    final (lang, bgm, sfx, vibration, shake, flash, powerSave, autoBoss, autoUpgrade, notifications) = ref.watch(
      gameStateProvider.select((s) {
        final v = s.settings;
        return (
          v.lang,
          v.bgm,
          v.sfx,
          v.vibration,
          v.shake,
          v.flash,
          v.powerSave,
          v.autoBoss,
          v.autoUpgrade,
          v.notifications,
        );
      }),
    );
    final ads = ref.watch(adsPortProvider);
    void set(String key, Object value) => ref.read(commandSinkProvider).send(SetSetting(key, value));

    final switches = [
      ('bgm', l10n.uiSettingsBgm, bgm),
      ('sfx', l10n.uiSettingsSfx, sfx),
      ('vibration', l10n.uiSettingsVibration, vibration),
      ('shake', l10n.uiSettingsShake, shake),
      ('flash', l10n.uiSettingsFlash, flash),
      ('powerSave', l10n.uiSettingsPowerSave, powerSave),
      ('autoBoss', l10n.uiSettingsAutoBoss, autoBoss),
      ('autoUpgrade', l10n.uiSettingsAutoUpgrade, autoUpgrade),
      // 오프라인 보상 가득 알림 (세이브 v4, ADR-0009).
      ('notifications', l10n.uiSettingsNotifications, notifications),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 도트 머리줄: 뒤로 + 제목 (AppBar 대신).
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  PixelButton(
                    key: const Key('settings.back'),
                    semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const PixelBitmap(PixelBitmaps.back),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.uiSettingsTitle, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.uiSettingsLanguage),
                        const SizedBox(height: 8),
                        PixelSegmented<String>(
                          key: const Key('settings.lang'),
                          segments: [
                            ('system', l10n.uiLangSystem),
                            ('ko', l10n.uiLangKo),
                            ('en', l10n.uiLangEn),
                          ],
                          selected: lang,
                          onChanged: (v) => set('lang', v),
                        ),
                      ],
                    ),
                  ),
                  for (final (key, label, value) in switches)
                    PixelListRow(
                      onTap: () => set(key, !value),
                      title: Text(label),
                      trailing: PixelToggle(
                        key: Key('settings.$key'),
                        value: value,
                        semanticLabel: label,
                        onChanged: (v) => set(key, v),
                      ),
                    ),
                  // 개인정보 옵션(UMP 재동의) — AdMob이 필요하다고 할 때만 (개인정보처리방침의 약속, 스펙 platform-m4).
                  if (ads is AdMobAds && ads.privacyOptionsRequired)
                    PixelListRow(
                      key: const Key('settings.privacy'),
                      title: Text(l10n.uiSettingsPrivacy),
                      trailing: const PixelBitmap(PixelBitmaps.chevron),
                      onTap: () => unawaited(ads.showPrivacyOptions()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
