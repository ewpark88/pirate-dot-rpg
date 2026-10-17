import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/adapters/save_transfer.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/flags.dart';
import 'package:pirate_dot/operator/operator_gate.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/pixel/pixel_bitmap.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_toggle.dart';
import 'package:pirate_dot/ui/settings/about_section.dart';
import 'package:pirate_dot/ui/settings/help_section.dart';
import 'package:pirate_dot/ui/settings/save_transfer_section.dart';
import 'package:pirate_dot/ui/settings/settings_rows.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 설정 화면 (설계서 4.12). 바꾸면 SetSetting만 보낸다 — 화면은 엔진이 돌려준 상태로 다시 그린다.
// TODO(ui): 알림, 크레딧(LICENSES.json), 버전 글자(운영자 열기를 그리로 옮김) — 다음 계획.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Settings에는 ==가 없어서 값 10개를 레코드로 골라 구독한다.
    final (lang, bgm, sfx, vibration, shake, flash, powerSave, autoBoss, autoUltimate, notifications) = ref.watch(
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
          v.autoUltimate,
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
      // 선장 필살기: 켜면 게이지가 차는 즉시 사용, 끄면 버튼을 직접(S2 boss-feel, 기본 켬).
      ('autoUltimate', l10n.uiSettingsAutoUltimate, autoUltimate),
      // 자동 강화 토글 없음 — 보상형 광고 10분으로만(사용자 지시 2026-10-16, 상단 바 '자동').
      // 오프라인 보상 가득 알림 (세이브 v4, ADR-0009).
      ('notifications', l10n.uiSettingsNotifications, notifications),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // k2 머리: 노란 리본 제목 + 왼쪽 뒤로 (AppBar 대신, 디자인 개편 — 쿵푸할매 창 머리).
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: RibbonHeader(title: l10n.uiSettingsTitle, padRight: 64),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: PixelButton(
                    key: const Key('settings.back'),
                    semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_rounded, size: 22, color: Skin.ink),
                  ),
                ),
              ],
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
                    (l10n.uiSettingsPlay, const ['autoBoss', 'autoUltimate', 'notifications']),
                  ])
                    _Group(
                      title: title,
                      child: Column(
                        children: [
                          for (final (key, label, value) in switches.where((e) => keys.contains(e.$1)))
                            if (key == 'flash')
                              const FlashLevelRow()
                            else ...[
                              PixelListRow(
                                onTap: () => set(key, !value),
                                // 줄마다 아이콘 (설정 r2 최종 다듬기).
                                leading: Icon(_settingIcon(key), size: 22, color: Skin.primaryEdge),
                                title: Text(label),
                                trailing: PixelToggle(
                                  key: Key('settings.$key'),
                                  value: value,
                                  semanticLabel: label,
                                  onChanged: (v) => set(key, v),
                                ),
                              ),
                              // 절전 모드 바로 아래: 절전 화면까지 시간.
                              if (key == 'powerSave') const SleepAfterRow(),
                            ],
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
                  // 가이드 v2: 처음 만나는 시스템 안내를 다시 켠다(ClearHints 'guide.').
                  PixelListRow(
                    key: const Key('settings.guideReplay'),
                    leading: const Icon(Icons.lightbulb_rounded, size: 22, color: Skin.primaryEdge),
                    title: Text(l10n.uiSettingsGuideReplay),
                    trailing: const PixelBitmap(PixelBitmaps.chevron),
                    onTap: () {
                      ref.read(guideQueueProvider.notifier).replay();
                      showSkinToast(context, l10n.uiSettingsGuideReplayDone);
                    },
                  ),
                  // 세이브 옮기기(기기 교체 — 가져오기가 되는 빌드만).
                  if (ref.watch(saveImportProvider) != null)
                    _Group(
                      key: const Key('settings.save'),
                      title: l10n.uiSaveTitle,
                      child: const SaveTransferSection(),
                    ),
                  // 정보: 개인정보처리방침 · 이용약관 · 문의하기 · 버전(출시 준비).
                  _Group(key: const Key('settings.about'), title: l10n.uiSettingsAbout, child: const AboutSection()),
                  // 운영자 빌드만: 패널 바로 열기(돈 알약 5번 탭은 안쪽 골드 칸이 먼저 받는다 — S1 2026-10-18).
                  if (kOperator)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton(
                        key: const Key('settings.operator'),
                        onPressed: () => unawaited(showOperatorPanel(context)),
                        child: Text(l10n.opOpenPanel),
                      ),
                    ),
                  // 도움말: 새 시스템 짧은 설명(S1 2026-10-18) + 큰 수 단위(계획 E11).
                  _Group(key: const Key('settings.help'), title: l10n.uiSettingsHelp, child: const HelpSection()),
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
  'powerSave' => Icons.battery_saver_rounded,
  'autoBoss' => Icons.military_tech_rounded,
  'autoUltimate' => Icons.bolt_rounded,
  _ => Icons.notifications_rounded,
};

/// 설정 묶음: 소제목 리본 + 안쪽 판 (k2).
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
        // k2: 소제목 리본 + 연보라 안쪽 판(굵은 외곽선).
        Padding(padding: const EdgeInsets.only(bottom: 6), child: SubRibbon(title)),
        DecoratedBox(
          decoration: Skin.inset(radius: Skin.radiusCard),
          child: ClipRRect(borderRadius: BorderRadius.circular(Skin.radiusCard), child: child),
        ),
      ],
    ),
  );
}
