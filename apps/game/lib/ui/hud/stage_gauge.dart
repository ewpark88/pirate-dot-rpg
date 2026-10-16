import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/fun_strips.dart';
import 'package:pirate_dot/ui/hud/skull_painter.dart';
import 'package:pirate_dot/ui/meta/goal_bar.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 보스 직전 빨간 맥박: 이 시간 동안 3번 (끝이 있음 — 무한 반복 없음).
const _pulse = Duration(milliseconds: 1800);
const _pulses = 3;

/// 게이지 한 화면에 필요한 값 (20Hz 상태에서 이것만 골라 구독).
typedef _Gauge = ({int stage, int wave, int waves, bool boss, bool farming, int ticksLeft, int inRegion, int per});

/// 전장 위 스테이지 진행 게이지 (S1 지시): 파 1~3 칸 + 보스 해골, 아래 얇은 해역 진행.
/// 파를 다 깨면(보스 직전) 해골이 빨갛게 3번 뛴다. 보스 중에는 칸 대신 남은 시간 막대(줄어들수록 빨강).
class StageGauge extends ConsumerStatefulWidget {
  const StageGauge({super.key});

  @override
  ConsumerState<StageGauge> createState() => _StageGaugeState();
}

class _StageGaugeState extends ConsumerState<StageGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtl = AnimationController(vsync: this, duration: _pulse);

  /// 이번 보스의 처음 남은 시간 (상점 '모래시계'로 늘어날 수 있어 테이블 대신 처음 값을 쓴다).
  int _bossTotal = 1;

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
      ticksLeft: b?.bossTicksLeft ?? 0,
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
    if (g.boss && g.ticksLeft > _bossTotal) _bossTotal = g.ticksLeft;
    if (!g.boss) _bossTotal = 1;
    final l10n = AppLocalizations.of(context);
    final seconds = (g.ticksLeft * tables.waves.tickMs / Duration.millisecondsPerSecond).ceil();
    return _PulseOnEnter(
      active: preBoss,
      controller: _pulseCtl,
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
          child: Container(
            key: const Key('hud.gauge'),
            padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
            decoration: BoxDecoration(
              color: Skin.ink.withValues(alpha: 0.92),
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
                      style: Skin.text(14, color: Colors.white),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 12,
                            child: g.boss
                                ? _TimerBar(value: (g.ticksLeft / _bossTotal).clamp(0.0, 1.0))
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
                          const SizedBox(height: 3),
                          // 해역 진행 (얇게).
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              key: const Key('hud.gauge.region'),
                              value: g.inRegion / g.per,
                              minHeight: 3,
                              color: Skin.goldTop,
                              backgroundColor: Colors.white24,
                            ),
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
                    if (g.boss) ...[
                      const SizedBox(width: 4),
                      Text(
                        l10n.uiGaugeSeconds(seconds),
                        key: const Key('hud.gauge.seconds'),
                        style: Skin.text(14, color: const Color(0xFFFFB3BC)),
                      ),
                    ],
                  ],
                ),
                // 다음 목표 (얇은 한 줄 — 따로 띠를 두지 않는다).
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Expanded(child: GoalBar(compact: true)),
                      SizedBox(width: 8),
                      // 피버(10초 전체 강화) — 함성(궁극기 버튼 둘레)과 헷갈리지 않게 게이지 안에 따로.
                      FeverMeter(),
                    ],
                  ),
                ),
              ],
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
      decoration: BoxDecoration(
        color: state == 1 ? Colors.white24 : color,
        borderRadius: BorderRadius.circular(4),
        border: state == 1 ? Border.all(color: color, width: 1.5) : null,
      ),
    );
  }
}

/// 보스 남은 시간 막대: 많이 남으면 주황, 적게 남을수록 빨강.
class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: const Key('hud.gauge.timer'),
    borderRadius: BorderRadius.circular(4),
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.white24),
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value,
          child: ColoredBox(color: Color.lerp(Skin.danger, const Color(0xFFFFA24A), value)!),
        ),
      ],
    ),
  );
}
