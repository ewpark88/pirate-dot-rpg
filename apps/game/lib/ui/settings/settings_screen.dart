import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_bitmap.dart';
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
      appBar: AppBar(title: Text(l10n.uiSettingsTitle)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.uiSettingsLanguage),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<String>(
                key: const Key('settings.lang'),
                segments: [
                  ButtonSegment(value: 'system', label: Text(l10n.uiLangSystem)),
                  ButtonSegment(value: 'ko', label: Text(l10n.uiLangKo)),
                  ButtonSegment(value: 'en', label: Text(l10n.uiLangEn)),
                ],
                selected: {lang},
                onSelectionChanged: (v) => set('lang', v.single),
              ),
            ),
          ),
          for (final (key, label, value) in switches)
            SwitchListTile(key: Key('settings.$key'), title: Text(label), value: value, onChanged: (v) => set(key, v)),
          // 개인정보 옵션(UMP 재동의) — AdMob이 필요하다고 할 때만 (개인정보처리방침의 약속, 스펙 platform-m4).
          if (ads is AdMobAds && ads.privacyOptionsRequired)
            ListTile(
              key: const Key('settings.privacy'),
              title: Text(l10n.uiSettingsPrivacy),
              trailing: const PixelBitmap(PixelBitmaps.chevron),
              onTap: () => unawaited(ads.showPrivacyOptions()),
            ),
        ],
      ),
    );
  }
}
