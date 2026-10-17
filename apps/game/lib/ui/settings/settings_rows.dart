import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_toggle.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/state/idle.dart';

/// 설정 '번쩍임' 세 단계 끔·약·강(기본 약 — 사용자 '번쩍임 눈 아프다'). flashLevel 하나만 보낸다(엔진이 flash도 맞춘다).
class FlashLevelRow extends ConsumerWidget {
  const FlashLevelRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final level = ref.watch(gameStateProvider.select((s) => s.settings.flashLevel));
    return _ChoiceRow(
      icon: Icons.flash_on_rounded,
      title: l10n.uiSettingsFlash,
      sub: l10n.uiSettingsFlashSub,
      child: PixelSegmented<String>(
        key: const Key('settings.flashLevel'),
        segments: [
          ('off', l10n.uiSettingsFlashOff),
          ('soft', l10n.uiSettingsFlashSoft),
          ('full', l10n.uiSettingsFlashFull),
        ],
        selected: level,
        onChanged: (v) => ref.read(commandSinkProvider).send(SetSetting('flashLevel', v)),
      ),
    );
  }
}

/// 설정 '절전 화면까지' 1·5·10·20·30분. 절전 모드가 꺼져 있으면 흐리게 + 고를 수 없음(절전 화면도 안 뜬다).
class SleepAfterRow extends ConsumerWidget {
  const SleepAfterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (sec, powerSave) = ref.watch(
      gameStateProvider.select((s) => (s.settings.sleepAfterSec, s.settings.powerSave)),
    );
    // 표에 없는 값(옛 세이브 180·0 등)은 가장 가까운 칸 — 동작도 같은 값(idle.dart sleepAfterOf).
    final selected = nearestSleepChoice(sec);
    return Opacity(
      opacity: powerSave ? 1 : 0.45,
      child: _ChoiceRow(
        icon: Icons.bedtime_rounded,
        title: l10n.uiSettingsSleepAfter,
        sub: l10n.uiSettingsSleepAfterSub,
        child: PixelSegmented<int>(
          key: const Key('settings.sleepAfter'),
          segments: [
            for (final c in sleepAfterChoices) (c, l10n.uiSettingsSleepMin(c ~/ 60)),
          ],
          selected: selected,
          onChanged: powerSave ? (v) => ref.read(commandSinkProvider).send(SetSetting('sleepAfterSec', v)) : null,
        ),
      ),
    );
  }
}

/// 아이콘 · 제목 · 작은 설명 + 아래 줄에 고르기.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.icon, required this.title, required this.sub, required this.child});

  final IconData icon;
  final String title;
  final String sub;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: Skin.primaryEdge),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(sub, style: Skin.text(12, color: Skin.sub)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}
