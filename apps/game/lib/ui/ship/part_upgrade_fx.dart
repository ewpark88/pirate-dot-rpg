import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart' show audioPortProvider;
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 배 부위 강화 손맛 (사용자 2026-10-18 '업그레이드 슬롯 클릭 연출이 밋밋 — 세진다는 느낌'): 그 부위가 오르면(PartUpgraded)
// 줄이 눌렸다 통통 · 금빛 테 번쩍 · '+n%'(효과 증가, 초록) 떠오름 · 연타(1초 안)는 콤보로 빛이 점점 커지고 소리 음이 오르며
// 5연타면 '연속 강화!' · 외형이 바뀌는 레벨이면 '외형 변경!'. Lv 배지·효과 숫자는 줄이 이미 굴린다(RollingText).

const _comboWindow = Duration(seconds: 1);

class PartUpgradeFx extends ConsumerStatefulWidget {
  const PartUpgradeFx({required this.def, required this.child, super.key});

  final ShipPartDef def;
  final Widget child;

  @override
  ConsumerState<PartUpgradeFx> createState() => _PartUpgradeFxState();
}

class _PartUpgradeFxState extends ConsumerState<PartUpgradeFx> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  StreamSubscription<RecordedTick>? _sub;
  int? _last;
  int _combo = 0;
  int _gain = 0;
  bool _look = false;
  bool _milestone = false;

  /// 이번 강화에 쓴 골드(작게 날아가 사라짐).
  BigNum? _spent;

  /// 마지막으로 본 레벨(강화 전 값 — 효과 증가 %·외형 변화 계산).
  late int _before = ref.read(gameStateProvider).ship.level(widget.def.id);

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      if (!mounted) return;
      final id = widget.def.id;
      final up = tick.events.whereType<PartUpgraded>().where((e) => e.part == id).lastOrNull;
      // 8레벨 마일스톤(엔진 PartMilestone — 전장 '×2!'는 렌더): 이 줄에 금빛 '×2!' 도장 + 큰 반짝. 같은 틱 순서와 상관없게 모아 본다.
      final milestone = tick.events.any((e) => e is PartMilestone && e.part == id);
      if (up != null) _hit(up.level, up.tick);
      if (milestone) {
        setState(() => _milestone = true);
        if (!MediaQuery.disableAnimationsOf(context)) unawaited(_c.forward(from: 0));
      }
    });
  }

  void _hit(int level, int tick) {
    // 연타 판정은 엔진 틱 간격으로(실제 시계 대신 — 시험·느린 기기에서도 같게).
    final ms = ref.read(tablesProvider).waves.tickMs;
    final last = _last;
    _combo = last != null && (tick - last) * ms < _comboWindow.inMilliseconds ? _combo + 1 : 1;
    _last = tick;
    final before = _before;
    final a = partEffect(widget.def, math.max(0, before)).toDouble();
    final b = partEffect(widget.def, level).toDouble();
    setState(() {
      _milestone = false;
      _spent = partCostSum(widget.def, math.max(0, before), math.max(1, level - before));
      _gain = a > 0 ? ((b / a - 1) * 100).round() : 0;
      _look = partLookStage(widget.def, level) > partLookStage(widget.def, math.max(0, before));
    });
    _before = level;
    // 강화음: 연타일수록 음이 조금씩 오른다(최대 1.5배).
    ref.read(audioPortProvider)?.playSfx('combo', pitch: math.min(1.5, 1 + 0.06 * (_combo - 1)));
    if (!MediaQuery.disableAnimationsOf(context)) unawaited(_c.forward(from: 0));
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = _c.value;
        final on = _c.isAnimating;
        // 0~0.25 눌림(0.96) → 0.25~0.6 통통(1.03) → 제자리.
        final scale = !on
            ? 1.0
            : (v < 0.25 ? 1 - 0.04 * (v / 0.25) : 0.96 + 0.07 * math.sin((v - 0.25) / 0.75 * math.pi));
        final glow = on ? (1 - v) * (_milestone ? 1.0 : math.min(1, 0.4 + 0.15 * _combo)) : 0.0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.scale(
              scale: scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: glow > 0
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD84A).withValues(alpha: glow),
                            blurRadius: 8 + 3.0 * _combo,
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            ),
            if (on && _gain > 0)
              Positioned(
                right: 96,
                top: 4 - 20 * v,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - v * v).clamp(0, 1).toDouble(),
                    child: OutlineText(
                      l10n.uiUpgradeGain(_gain),
                      key: Key('ship.gain.${widget.def.id}'),
                      size: 15,
                      tone: OutlineTone.green,
                    ),
                  ),
                ),
              ),
            // 골드 차감: 강화 버튼 위에서 작게 위로 빠짐.
            if (on && _spent != null && !_milestone)
              Positioned(
                right: 8,
                top: -4 - 16 * v,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - v).clamp(0, 1).toDouble(),
                    child: OutlineText(
                      l10n.uiUpgradeSpent(_spent!.format()),
                      key: Key('ship.spent.${widget.def.id}'),
                      size: 11,
                      tone: OutlineTone.red,
                    ),
                  ),
                ),
              ),
            if (on && _milestone)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.15,
                      child: Transform.scale(
                        scale: 1.6 - 0.6 * Curves.easeOutBack.transform(math.min(1, v * 3)),
                        child: OutlineText(
                          l10n.uiUpgradeMilestone,
                          key: Key('ship.milestone.${widget.def.id}'),
                          size: 28,
                          tone: OutlineTone.gold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (on && !_milestone && (_combo >= 5 || _look))
              Positioned(
                left: 60,
                top: -10 - 8 * v,
                child: IgnorePointer(
                  child: OutlineText(
                    _look ? l10n.uiUpgradeLook : l10n.uiUpgradeCombo,
                    key: Key('ship.combo.${widget.def.id}'),
                    size: 14,
                    tone: OutlineTone.gold,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
