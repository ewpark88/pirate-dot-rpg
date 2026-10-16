import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bitmap.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_toggle.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 설정 화면 (설계서 4.12). 바꾸면 SetSetting만 보낸다 — 화면은 엔진이 돌려준 상태로 다시 그린다.
// TODO(ui): 알림, 크레딧(LICENSES.json), 버전 글자(운영자 열기를 그리로 옮김) — 다음 계획.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Settings에는 ==가 없어서 값 9개를 레코드로 골라 구독한다.
    final (lang, bgm, sfx, vibration, shake, flash, powerSave, autoBoss, notifications) = ref.watch(
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
      // 자동 강화 토글 없음 — 보상형 광고 10분으로만(사용자 지시 2026-10-16, 상단 바 '자동').
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
                    child: const Icon(Icons.arrow_back_rounded, size: 22, color: Skin.ink),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.uiSettingsTitle, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                children: [
                  // 스킨 r2: 묶음마다 떠 있는 판 + 머리 글.
                  _Group(
                    title: l10n.uiSettingsLanguage,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: PixelSegmented<String>(
                        key: const Key('settings.lang'),
                        segments: [
                          ('system', l10n.uiLangSystem),
                          ('ko', l10n.uiLangKo),
                          ('en', l10n.uiLangEn),
                        ],
                        selected: lang,
                        onChanged: (v) => set('lang', v),
                      ),
                    ),
                  ),
                  for (final (title, keys) in [
                    (l10n.uiSettingsSound, const ['bgm', 'sfx', 'vibration']),
                    (l10n.uiSettingsDisplay, const ['shake', 'flash', 'powerSave']),
                    (l10n.uiSettingsPlay, const ['autoBoss', 'notifications']),
                  ])
                    _Group(
                      title: title,
                      child: Column(
                        children: [
                          for (final (key, label, value) in switches.where((e) => keys.contains(e.$1)))
                            PixelListRow(
                              onTap: () => set(key, !value),
                              // 줄마다 아이콘 (설정 r2 최종 다듬기).
                              leading: Icon(_settingIcon(key), size: 22, color: Skin.primaryEdge),
                              title: key == 'flash'
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(label),
                                        Text(l10n.uiSettingsFlashSub, style: Skin.text(12, color: Skin.sub)),
                                      ],
                                    )
                                  : Text(label),
                              trailing: PixelToggle(
                                key: Key('settings.$key'),
                                value: value,
                                semanticLabel: label,
                                onChanged: (v) => set(key, v),
                              ),
                            ),
                        ],
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
                  // 도움말: 큰 수 단위 (계획 E11).
                  _Group(
                    key: const Key('settings.help'),
                    title: l10n.uiSettingsHelp,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(l10n.uiNumberUnits, style: const TextStyle(color: PixelPalette.textDim)),
                    ),
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

/// 설정 줄 아이콘.
IconData _settingIcon(String key) => switch (key) {
  'bgm' => Icons.music_note_rounded,
  'sfx' => Icons.volume_up_rounded,
  'vibration' => Icons.vibration_rounded,
  'shake' => Icons.waves_rounded,
  'flash' => Icons.flash_on_rounded,
  'powerSave' => Icons.battery_saver_rounded,
  'autoBoss' => Icons.military_tech_rounded,
  _ => Icons.notifications_rounded,
};

/// 설정 묶음: 머리 글 + 떠 있는 판 (스킨 r2 ①).
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 4),
          child: Text(title, style: Skin.text(15, color: Skin.sub)),
        ),
        SkinDepth(
          padding: EdgeInsets.zero,
          child: ClipRRect(borderRadius: BorderRadius.circular(Skin.radiusCard), child: child),
        ),
      ],
    ),
  );
}
