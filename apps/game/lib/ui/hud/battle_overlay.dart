import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/flags.dart';
import 'package:pirate_dot/operator/operator_gate.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/hud/boss_challenge.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/hud/tailwind_badge.dart';
import 'package:pirate_dot/ui/meta/daily_sheet.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/settings/settings_screen.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 캔버스 HUD(골드·스테이지·함성 게이지, y 6~12) 아래에서 오버레이가 시작하는 논리 y.
const _belowHud = 15.0;

/// 오버레이 바깥 여백(논리 픽셀).
const _margin = 4.0;

/// 운영자 탭 영역의 논리 크기 — 캔버스 스테이지 글자(x 150, y 6) 위.
const _operatorX = 140.0;
const _operatorW = 40.0;

/// 전장 위 도트 오버레이 — 누르는 것만 (render-quality 캔버스 HUD가 골드·스테이지·게이지를 그린다).
/// 전장 상자(`battle.area`, 320×180 비율) 안에 깔려 논리 좌표 × 배율로 놓는다.
/// 왼쪽 위: 퀘스트·설정, 순풍·순풍 광고 / 가운데 위: 보스 타이머 / 오른쪽 위: 보스 도전·약점 / 오른쪽 아래(슬롯 위): 궁극기.
/// 전장 높이가 400dp 폭에서 225dp라 오른쪽 위 줄과 궁극기가 겹치지 않게 설정은 왼쪽에 둔다.
class BattleOverlay extends StatelessWidget {
  const BattleOverlay({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final k = box.maxWidth / kLogicalWidth;
      final top = _belowHud * k;
      final m = _margin * k;
      return Stack(
        children: [
          Positioned(
            top: top,
            left: m,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [DailyIcon(), SizedBox(width: 4), _SettingsButton()]),
                SizedBox(height: 4),
                TailwindBadge(),
                TailwindAdButton(),
              ],
            ),
          ),
          Positioned(
            top: top,
            left: 0,
            right: 0,
            child: const Center(child: _BossTimer()),
          ),
          Positioned(
            top: top,
            right: m,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [BossChallenge(), BossWeakness()],
            ),
          ),
          Positioned(
            right: m,
            bottom: (kLogicalHeight - kFieldBottom) * k + m,
            child: const _UltimateButton(),
          ),
          // 운영자 빌드에서만 캔버스 스테이지 글자를 5번 → 운영자 패널. 배포 빌드에는 제스처가 없다.
          if (kOperator)
            Positioned(
              top: 0,
              left: _operatorX * k,
              width: _operatorW * k,
              height: _belowHud * k,
              child: const OperatorTapGate(child: SizedBox.expand()),
            ),
        ],
      );
    },
  );
}

/// 보스전 남은 초 (캔버스 HUD에 없는 값).
class _BossTimer extends ConsumerWidget {
  const _BossTimer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickMs = ref.watch(tablesProvider).waves.tickMs;
    final seconds = ref.watch(
      gameStateProvider.select((s) {
        final battle = s.battle;
        if (battle == null || !battle.bossActive) return null;
        return (battle.bossTicksLeft * tickMs / Duration.millisecondsPerSecond).ceil();
      }),
    );
    if (seconds == null) return const SizedBox.shrink();
    return ColoredBox(
      color: PixelPalette.outline,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          AppLocalizations.of(context).uiHudBossTimer(seconds),
          key: const Key('hud.bossTimer'),
          style: const TextStyle(color: PixelPalette.danger, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).uiSettingsTitle;
    return Tooltip(
      message: label,
      child: PixelButton(
        key: const Key('hud.settings'),
        semanticLabel: label,
        onPressed: () => unawaited(
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
        ),
        child: const PixelSprite(UiSprites.gear, dots: 16, scale: 1),
      ),
    );
  }
}

/// 궁극기: 함성이 가득일 때만 누를 수 있다 (게이지는 캔버스).
class _UltimateButton extends ConsumerWidget {
  const _UltimateButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rageMax = ref.watch(tablesProvider).skills.rageMax;
    final full = ref.watch(gameStateProvider.select((s) => s.progress.rage >= rageMax));
    return PixelButton(
      key: const Key('hud.ultimate'),
      primary: true,
      onPressed: full ? () => ref.read(commandSinkProvider).send(const TriggerUltimate()) : null,
      child: Text(AppLocalizations.of(context).uiHudUltimate),
    );
  }
}
