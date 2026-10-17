import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/hud/boss_break.dart';
import 'package:pirate_dot/ui/hud/boss_compare.dart';
import 'package:pirate_dot/ui/hud/fun_strips.dart';
import 'package:pirate_dot/ui/hud/hp_bars.dart';
import 'package:pirate_dot/ui/hud/sea_event_icon.dart';
import 'package:pirate_dot/ui/hud/skull_painter.dart';
import 'package:pirate_dot/ui/meta/goal_bar.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 보스 직전 빨간 맥박: 이 시간 동안 3번 (끝이 있음 — 무한 반복 없음).
const _pulse = Duration(milliseconds: 1800);
const _pulses = 3;

/// 게이지 한 화면에 필요한 값 (20Hz 상태에서 이것만 골라 구독).
typedef _Gauge = ({int stage, int wave, int waves, bool boss, bool farming, int inRegion, int per});

/// 전장 위 스테이지 진행 게이지 (S1 지시): 파 1~3 칸 + 보스 해골, 아래 얇은 해역 진행.
/// 파를 다 깨면(보스 직전) 해골이 빨갛게 3번 뛴다. 보스 중에는 칸 대신 보스 체력 막대(이름 · 남은 / 최대).
class StageGauge extends ConsumerStatefulWidget {
  const StageGauge({super.key});

  @override
  ConsumerState<StageGauge> createState() => _StageGaugeState();
}

class _StageGaugeState extends ConsumerState<StageGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtl = AnimationController(vsync: this, duration: _pulse);

  @override
  void dispose() {
    _pulseCtl.dispose();
    super.dispose();
  }

  _Gauge _select(GameState s, int waves, int per) {
    final p = s.progress;
    final b = s.battle;
    return (
      stage: p.stage,
      wave: p.wave,
      waves: waves,
      boss: b?.bossActive ?? false,
      farming: p.farming,
      inRegion: (p.stage - 1) % per + 1,
      per: per,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(tablesProvider);
    final waves = tables.waves.wavesPerStage;
    final per = tables.regions.stagesPerRegion;
    final g = ref.watch(gameStateProvider.select((s) => _select(s, waves, per)));
    final preBoss = !g.boss && !g.farming && g.wave >= g.waves;
    final l10n = AppLocalizations.of(context);
    return _PulseOnEnter(
      active: preBoss,
      controller: _pulseCtl,
      // 게이지(스테이지 '37-2')를 누르면 항해 지도(도크 항해 패널)가 열린다(사용자 피드백 #9 A — 항해는 도크 끝으로 옮김).
      // 안의 글(스테이지·보스 막대 등)은 따로 읽히게 explicitChildNodes, 누름은 이 노드 하나가 맡는다.
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: l10n.uiGaugeOpenVoyage,
        onTap: () => ref.read(dockTabRequestProvider.notifier).open(voyageTab),
        child: GestureDetector(
          key: const Key('hud.gauge.tap'),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: () => ref.read(dockTabRequestProvider.notifier).open(voyageTab),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
            child: Container(
              key: const Key('hud.gauge'),
              padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
              // 떠 있는 띠(사용자 2026-10-17 배치 확정): 판 없이 글자·막대만(외곽선이 읽히게) — 전장을 덜 가린다.
              decoration: BoxDecoration(
                // 밝은 바다 위에서도 글자 대비(WCAG 4.5)가 나오게 반투명 — 판보다 가볍게.
                color: Skin.navyPanel.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.uiGaugeStage(g.stage, math.min(g.wave + 1, g.waves)),
                        key: const Key('hud.gauge.stage'),
                        style: Skin.outlined(14),
                      ),
                      // 파밍 중 (보스 재도전 가능) — 따로 띠를 두지 않고 게이지 안 작은 꼬리표.
                      if (g.farming && !g.boss) ...[
                        const SizedBox(width: 6),
                        Container(
                          key: const Key('hud.farming'),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8C766),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(l10n.uiFarming, style: Skin.text(11, color: Skin.goldInk)),
                        ),
                      ],
                      // 돌발 이벤트(폭풍 등)는 띠 안 작은 아이콘(실기기 ④).
                      const SeaEventIcon(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              // 보스전: 보스 타이머 대신 굵은 보스 체력 막대(사용자 2026-10-17 — 타이머는 엔진에서 없어짐).
                              height: g.boss ? 20 : 16, // k2: 배 HP 막대와 같은 굵기
                              child: g.boss
                                  ? const TutorialSpot(id: 'boss.hp', child: BossHpBar())
                                  : Row(
                                      children: [
                                        for (var i = 0; i < g.waves; i++) ...[
                                          if (i > 0) const SizedBox(width: 3),
                                          Expanded(
                                            child: _Segment(
                                              key: Key('hud.gauge.wave.$i'),
                                              state: i < g.wave ? 2 : (i == g.wave && !g.farming ? 1 : 0),
                                              farming: g.farming,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            ),
                            // 보스전: 브레이크 막대(기절·둔화·취약·밀림이 쌓임 — 가득이면 쓰러짐).
                            if (g.boss) ...[
                              const SizedBox(height: 4),
                              const TutorialSpot(id: 'boss.gauge', child: BossBreakBar()),
                            ],
                            const SizedBox(height: 3),
                            // 해역 진행 (k2: 외곽선 막대).
                            SkinBar(
                              key: const Key('hud.gauge.region'),
                              value: g.inRegion / g.per,
                              color: Skin.goldTop,
                              height: 7,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedBuilder(
                        animation: _pulseCtl,
                        builder: (context, _) {
                          final t = _pulseCtl.isAnimating ? math.sin(_pulseCtl.value * math.pi * _pulses).abs() : 0.0;
                          return Transform.scale(
                            scale: 1 + 0.25 * t,
                            child: CustomPaint(
                              key: Key(preBoss ? 'hud.gauge.skull.hot' : 'hud.gauge.skull'),
                              size: const Size(22, 22),
                              painter: SkullPainter(
                                color: g.boss || preBoss
                                    ? Color.lerp(const Color(0xFFFFD6DB), Skin.danger, preBoss ? 0.4 + 0.6 * t : 1)!
                                    : Colors.white70,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  // 다음 목표 (얇은 한 줄 — 따로 띠를 두지 않는다). 보스전·파밍 중엔 그 자리에 '보스 vs 나'(피드백 #5).
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        Expanded(child: BossCompare(fallback: GoalBar(compact: true))),
                        SizedBox(width: 8),
                        // 피버(10초 전체 강화) — 게이지 안에 따로(켜지는 순간 선장 첫 일격).
                        TutorialSpot(id: 'fever.meter', child: FeverMeter()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [active]가 꺼짐 → 켜짐으로 바뀔 때 맥박을 한 번(3번 뛰기) 시작한다.
class _PulseOnEnter extends StatefulWidget {
  const _PulseOnEnter({required this.active, required this.controller, required this.child});

  final bool active;
  final AnimationController controller;
  final Widget child;

  @override
  State<_PulseOnEnter> createState() => _PulseOnEnterState();
}

class _PulseOnEnterState extends State<_PulseOnEnter> {
  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(widget.controller.forward(from: 0));
  }

  @override
  void didUpdateWidget(_PulseOnEnter old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) unawaited(widget.controller.forward(from: 0));
    if (!widget.active && old.active) widget.controller.reset();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 파 한 칸: 0 남음 · 1 지금 · 2 깸. 파밍 중에는 모두 은은한 금색.
class _Segment extends StatelessWidget {
  const _Segment({required this.state, required this.farming, super.key});

  final int state;
  final bool farming;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      2 => farming ? const Color(0xFFE8C766) : Skin.mint,
      1 => Colors.white,
      _ => Colors.white24,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      // k2: 굵은 외곽선 + 채운 칸은 위가 밝은 광택.
      decoration: BoxDecoration(
        color: state == 2 ? null : const Color(0xFF3B3F74),
        gradient: state == 2
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.4)!, color],
              )
            : null,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: state == 1 ? Colors.white : Skin.outline, width: 2),
      ),
    );
  }
}
