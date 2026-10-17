import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/boss_bars.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 체력 수치 (사용자 2026-10-17 '내 배 체력이 아직도 안 보인다. 보스 체력도 안 보인다. 수치로 예쁘게'):
// 보스전 = 상단 게이지의 굵은 보스 체력 막대(이름 · 남은 / 최대), 늘 = 선원 줄 바로 위 전폭 배 체력(♥ 남은 / 최대).
// 보스 최대 체력은 경제 bossPreview(전투 startBoss와 같은 공식) × 남은 비율 — UI가 공식을 베끼지 않는다.

/// 남은 비율 → 색: 40% 아래 노랑, 15% 아래 빨강 (렌더 배 막대와 같은 3단계).
Color hpColor(double ratio, {required Color full}) =>
    ratio < 0.15 ? Skin.danger : (ratio < 0.4 ? const Color(0xFFFFC53D) : full);

/// 배 체력 막대 자리 — 가이드 말풍선이 이 위에 앉는다(선원 줄·하단 글자를 가리지 않게).
final GlobalKey shipHpAnchor = GlobalKey(debugLabel: 'shipHp');

/// 맞은 뒤 흔들림·빨강 깜빡임이 남는 틱 수.
const _hitTicks = 8;

/// 보스 체력 막대 (상단 게이지, 보스전 중): 굵은 빨간 막대 + '보스 이름 · 1.2M / 3.4M'.
class BossHpBar extends ConsumerWidget {
  const BossHpBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tablesProvider);
    final v = ref.watch(
      gameStateProvider.select((s) {
        for (final e in s.battle?.enemies ?? const <EnemyView>[]) {
          if (!e.boss) continue;
          final max = bossPreview(s, t).maxHp;
          final ratio = (e.hpRatio * 100).round() / 100;
          return (kind: e.kind, ratio: ratio, now: max.times(ratio).format(), max: max.format());
        }
        return null;
      }),
    );
    final l10n = AppLocalizations.of(context);
    // 여러 줄 보스: 이번 줄 비율·색, 바탕은 다음 줄 색(깎이면 드러난다), 오른쪽 '×남은 줄'.
    final bars = ref.watch(bossBarsProvider);
    final ratio = bars?.ratio ?? v?.ratio ?? 1.0;
    final boss = v == null ? null : t.regions.bosses[v.kind];
    final name = boss == null ? '' : tableText(l10n, boss.nameKey);
    return Container(
      key: const Key('hud.bossHp'),
      decoration: BoxDecoration(
        color: bars != null && bars.left > 1 ? bossBarColor(bars.left - 1) : const Color(0xFF3A1A24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0B1730), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: bars != null && bars.left > 1
                        ? [bossBarColor(bars.left), bossBarColor(bars.left)]
                        : [hpColor(ratio, full: const Color(0xFFFF5A6E)), const Color(0xFFE8443A)],
                  ),
                ),
              ),
            ),
            if (v != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    bars != null && bars.left > 1
                        ? l10n.uiBossHpBars(name, v.now, v.max, bars.left)
                        : l10n.uiBossHpLine(name, v.now, v.max),
                    key: const Key('hud.bossHp.text'),
                    maxLines: 1,
                    style: Skin.outlined(13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 배 체력 (선원 줄 바로 위 전폭, 늘): ♥ + 막대 + '820 / 1.5K'. 맞으면 잠깐 흔들리고 빨갛게 깜빡(번쩍임 끔이면 색만).
class ShipHpBar extends ConsumerStatefulWidget {
  const ShipHpBar({super.key});

  @override
  ConsumerState<ShipHpBar> createState() => _ShipHpBarState();
}

class _ShipHpBarState extends ConsumerState<ShipHpBar> {
  double _last = 1;
  int _hitAt = -_hitTicks;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(
      gameStateProvider.select((s) {
        final b = s.battle;
        if (b == null || b.shipHpMax.isZero) return null;
        final ratio = ((b.shipHp / b.shipHpMax).toDouble() * 100).round() / 100;
        return (ratio: ratio, now: b.shipHp.format(), max: b.shipHpMax.format(), tick: b.tick, flash: s.settings.flash);
      }),
    );
    if (v == null) return const SizedBox.shrink();
    if (v.ratio < _last - 0.001) _hitAt = v.tick;
    _last = v.ratio;
    final calm = !v.flash || MediaQuery.disableAnimationsOf(context);
    final hit = (1 - (v.tick - _hitAt) / _hitTicks).clamp(0.0, 1.0);
    final shake = calm || hit == 0 ? 0.0 : 2 * math.sin(v.tick * 2.3) * hit;
    final color = hpColor(v.ratio, full: Skin.mint);
    final low = v.ratio < 0.15 && !calm && (v.tick ~/ 5).isOdd;
    return IgnorePointer(
      key: shipHpAnchor,
      child: Transform.translate(
        offset: Offset(shake, 0),
        child: Container(
          key: const Key('hud.shipHp'),
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xE6262A52), const Color(0xCCB3122E), calm ? 0 : hit),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Skin.outline, width: 2),
          ),
          child: Row(
            children: [
              Icon(Icons.favorite_rounded, size: 14, color: low ? Colors.white : const Color(0xFFFF5A6E)),
              const SizedBox(width: 4),
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      key: const Key('hud.shipHp.bar'),
                      value: v.ratio.clamp(0.0, 1.0),
                      color: color,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 좁으면(보스 도전 버튼 옆) 숫자를 줄여 맞춘다.
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${v.now} / ${v.max}',
                    key: const Key('hud.shipHp.text'),
                    style: Skin.outlined(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
