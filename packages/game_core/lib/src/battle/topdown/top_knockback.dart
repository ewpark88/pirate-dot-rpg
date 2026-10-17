import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/units.dart';

/// 넉백(#82 사용자 '공격 임팩트가 약하다', S1 승인 2026-10-17 — waves.top.knockback):
/// 맞고 살아남은 적을 배 → 적 방향(늘 배 바깥쪽 — 배 몸통 쪽으로는 안 밀림)으로 dist만큼 민다.
/// - 큰 적은 약하게: × (잡몹 반경 ÷ 그 적 반경)(1 이하), 보스·standoff 적은 × bossMul.
/// - 한 적은 everySec에 한 번만(연사에 화면 밖으로 날아가지 않게). 카메라 안에 있던 적은 카메라 안에 남긴다.
/// - 촉수·호위(ownerId)·스쳐 가는 배(passX)·돌격대·이벤트 적·등장 대기는 밀지 않는다(보스 브레이크 당김에도 안 셈).
/// 표에 knockback이 없으면 아무것도 하지 않는다.
extension HitKnockback on Round {
  void knockback(Iterable<Foe> foes) => foes.forEach(_knock);

  void _knock(Foe e) {
    final g = geo;
    final top = w.raw.obj('top');
    if (g is! TopGeometry || !e.alive || !top.has('knockback')) return;
    if (e.ownerId != null || e.passX != null || e.vanguard || e.eventKind != null || e.holdSec > 0) return;
    final k = top.obj('knockback');
    final until = e.traitTicks['knockUntil'] ?? -1;
    if (ctx.tick < until) return;
    e.traitTicks['knockUntil'] = ctx.tick + math.max(1, (k.number('everySec') / dt).round());
    final dx = e.x - g.top.shipX;
    final dy = e.y - g.top.shipY;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d == 0) return;
    final size = math.min(1, g.top.mobRadius / g.top.radiusOf(e));
    final dist = k.number('dist') * size * (e.standsOff ? k.number('bossMul') : 1);
    if (dist <= 0) return;
    final hw = g.top.viewWidth * half - g.top.radiusOf(e);
    final hh = g.top.viewHeight * half - g.top.radiusOf(e);
    final cx = g.base.shipX;
    final cy = g.base.shipY;
    final inside = (e.x - cx).abs() <= hw && (e.y - cy).abs() <= hh;
    var nx = e.x + dx / d * dist;
    var ny = e.y + dy / d * dist;
    if (inside) {
      nx = nx.clamp(cx - hw, cx + hw);
      ny = ny.clamp(cy - hh, cy + hh);
    }
    ctx.emit(Knockback(ctx.tick, enemyId: e.id, dx: nx - e.x, dy: ny - e.y));
    e
      ..x = nx
      ..y = ny;
  }
}
