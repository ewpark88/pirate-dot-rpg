import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 보스 브레이크 (사용자 결정 2026-10-17, specs/platform-fever-break.md 2): 기절·둔화·취약·밀림이 쌓이는 막대 +
// 가득 차 쓰러지는 순간 'BREAK!'. 쓰러짐 그림·큰 피해 숫자는 렌더(S3), 수치는 skills.json bossBreak(S2).

/// 'BREAK!' 글자가 떠 있는 시간.
const _burst = Duration(milliseconds: 1400);

/// 막대 두께(dp) — 사용자 폰 피드백 '브레이크 막대가 잘 안 보여' → 최소 10.
const _barHeight = 12.0;

/// 브레이크 색: 밝은 하늘 → 노랑 (보스 시간 막대의 주황·빨강과 확실히 다르게) + 어두운 외곽선.
const _breakFrom = Color(0xFF5FE1FF);
const _breakTo = Color(0xFFFFE14A);
const _outline = Color(0xFF0B1730);
const _locked = Color(0xFF8A93A6);

/// 반짝임이 남는 틱 수(오를 때마다) · 흔들림이 시작되는 비율.
const _shineTicks = 8;
const _hotRatio = 0.8;

/// 보스 시간 막대 아래 브레이크 막대 (사용자 결정 2026-10-17, 폰 피드백으로 v2): 왼쪽 ⚡BREAK 칩 + 두꺼운 막대.
/// 오르면 잠깐 반짝, 80% 넘으면 살짝 흔들림(전투 틱으로 — 반복 애니메이션 없음), 쓰러진 동안은 금빛 가득 + 'BREAK!'.
/// 일어난 뒤 게이지가 0인 동안은 회색 + 자물쇠(엔진 쿨다운 — 계약에 없어 '쓰러졌다 일어난 뒤 0'으로 본다, S1 2026-10-17.
/// S2 EnemyView.breakCooldown이 오면 그 값으로 차오르는 시계를 그린다).
/// 번쩍임 끔·동작 줄이기면 반짝·흔들림 없이 색만.
class BossBreakBar extends ConsumerStatefulWidget {
  const BossBreakBar({super.key});

  @override
  ConsumerState<BossBreakBar> createState() => _BossBreakBarState();
}

class _BossBreakBarState extends ConsumerState<BossBreakBar> {
  double _last = 0;
  int _rose = -_shineTicks;

  /// 쓰러졌다 일어난 뒤 아직 다시 오르지 않았다(쿨다운으로 보임).
  bool _cooling = false;

  @override
  Widget build(BuildContext context) {
    final (ratio, broken, tick, flash) = ref.watch(
      gameStateProvider.select((s) {
        final t = s.battle?.tick ?? 0;
        for (final e in s.battle?.enemies ?? const <EnemyView>[]) {
          if (e.boss) return ((e.breakRatio * 50).round() / 50, e.broken, t, s.settings.flash);
        }
        return (0.0, false, t, s.settings.flash);
      }),
    );
    if (ratio > _last + 0.001) _rose = tick;
    _last = ratio;
    if (broken) _cooling = true;
    if (ratio > 0) _cooling = false;
    final locked = _cooling && !broken;
    final calm = !flash || MediaQuery.disableAnimationsOf(context);
    final shine = calm ? 0.0 : (1 - (tick - _rose) / _shineTicks).clamp(0.0, 1.0);
    final hot = broken || ratio >= _hotRatio;
    final shake = hot && !broken && !calm ? 1.5 * math.sin(tick * 2.1) : 0.0;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: broken ? l10n.uiBossBreak : l10n.uiBossBreakGauge((ratio * 100).round()),
      excludeSemantics: true,
      child: Transform.translate(
        offset: Offset(shake, 0),
        child: Row(
          key: Key(hot ? 'hud.break.hot' : 'hud.break'),
          children: [
            _Chip(label: broken ? l10n.uiBossBreak : l10n.uiBossBreakTag, locked: locked),
            const SizedBox(width: 5),
            Expanded(
              child: Container(
                height: _barHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF243552),
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                  border: Border.all(color: _outline, width: 2),
                  boxShadow: [
                    if (shine > 0 || hot)
                      BoxShadow(
                        color: _breakTo.withValues(alpha: 0.6 * (hot ? 1 : shine)),
                        blurRadius: 6 + 4 * shine,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_barHeight / 2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FractionallySizedBox(
                        key: Key(broken ? 'hud.break.full' : (locked ? 'hud.break.locked' : 'hud.break.fill')),
                        alignment: Alignment.centerLeft,
                        widthFactor: broken || locked ? 1 : ratio.clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: locked
                                ? null
                                : LinearGradient(
                                    colors: broken ? const [_breakTo, _breakTo] : const [_breakFrom, _breakTo],
                                  ),
                            color: locked ? _locked.withValues(alpha: 0.55) : null,
                          ),
                        ),
                      ),
                      // 오를 때 흰 빛이 잠깐 덮인다.
                      if (shine > 0) ColoredBox(color: Colors.white.withValues(alpha: 0.35 * shine)),
                      if (locked)
                        const Center(
                          child: Icon(Icons.lock_rounded, key: Key('hud.break.lock'), size: 9, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 막대 왼쪽 '⚡BREAK' 칩 (쓰러진 동안 'BREAK!', 쿨다운이면 회색 + 자물쇠).
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.locked});

  final String label;
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(3, 1, 6, 1),
    decoration: BoxDecoration(
      color: locked ? _locked : _breakTo,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _outline, width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(locked ? Icons.lock_rounded : Icons.bolt_rounded, size: 13, color: _outline),
        Text(label, style: Skin.text(11, color: _outline)),
      ],
    ),
  );
}

/// 보스가 쓰러지는 순간(BossBroken) 보스 자리에 'BREAK!' — 누름 통과. 전장 좌표는 ChestLayer와 같은 카메라로 dp에 놓는다.
class BossBreakBurst extends ConsumerStatefulWidget {
  const BossBreakBurst({super.key});

  @override
  ConsumerState<BossBreakBurst> createState() => _BossBreakBurstState();
}

class _BossBreakBurstState extends ConsumerState<BossBreakBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  StreamSubscription<RecordedTick>? _sub;
  Offset? _at;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: _burst);
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is BossBroken && mounted) show(Offset(e.x, e.y));
      }
    });
  }

  /// [world] = 쓰러진 보스의 전장 좌표 (테스트도 부른다).
  @visibleForTesting
  void show(Offset world) {
    setState(() => _at = world);
    unawaited(
      _ctl.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _at = null);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final world = _at;
    if (world == null) return const SizedBox.shrink();
    final shipY = ref.read(gameStateProvider).battle?.shipY ?? 240;
    final shipX = ref.read(tablesProvider).waves.top.shipX;
    final calm = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final game = ref.watch(hasBattleGameProvider) ? ref.read(battleGameProvider) : null;
          final at = game != null && game.hasLayout
              ? game.worldToDp(world)
              : topFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context)).worldToDp(world, Offset(shipX, shipY));
          // 글자가 상자 밖으로 나가지 않게 가로·세로를 안쪽으로 당긴다(360dp에서도 한 줄).
          final x = at.dx.clamp(64.0, (box.maxWidth - 64).clamp(64.0, double.infinity));
          final y = at.dy.clamp(40.0, (box.maxHeight - 40).clamp(40.0, double.infinity));
          return Stack(
            children: [
              Positioned(
                left: x - 80,
                top: y - 56,
                width: 160,
                child: AnimatedBuilder(
                  animation: _ctl,
                  builder: (context, child) {
                    final t = _ctl.value;
                    // 0~0.15 커지며 등장 → 머묾 → 0.75부터 위로 사라짐.
                    final pop = calm
                        ? 1.0
                        : (t < 0.15 ? 0.6 + 0.6 * (t / 0.15) : (t < 0.25 ? 1.2 - 2 * (t - 0.15) : 1.0));
                    final fade = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
                    return Opacity(
                      opacity: fade.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, calm ? 0 : -12 * (t > 0.75 ? (t - 0.75) / 0.25 : 0)),
                        child: Transform.scale(scale: pop, child: child),
                      ),
                    );
                  },
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppLocalizations.of(context).uiBossBreak,
                        key: const Key('hud.break.burst'),
                        maxLines: 1,
                        style: Skin.text(26, color: const Color(0xFFFFD84A)).copyWith(
                          shadows: const [
                            Shadow(color: Color(0xFF1B2A4A), offset: Offset(2, 2)),
                            Shadow(color: Color(0xFFD7263D), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
