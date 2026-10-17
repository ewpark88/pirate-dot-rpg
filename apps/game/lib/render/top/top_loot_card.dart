import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/top/top_label.dart';
import 'package:pirate_dot/render/top/top_loot_bits.dart';

/// 날아가는 카드 한 장: 선원·등급 색·등급 칸(0 일반…)·크기(0 보통·1 새 동료·2 환영)·앞면 연출 여부·묶인 장수.
class LootCard {
  LootCard(this.crewId, this.color, this.big, {this.stars = 0, this.reveal = false});
  final String crewId;
  final int color;
  final int big;
  final int stars;

  /// 앞면 공개 연출(피드백 #22): 뒷면으로 날아와 멈춰 뒤집히며 크게 + 이름·등급 띠. 기준 등급(fx_map cardFx.minRarity) 이상·새 동료.
  final bool reveal;
  int count = 1;
}

/// 카드 그리기(TopBossLoot 조각): 뒷면 → 뒤집기 → 앞면 크게·이름·등급 별·후광, 기준 미만은 작게 빠르게.
class LootCardPainter {
  LootCardPainter(this._bits, this._label);
  final LootBits _bits;
  final TopLabel _label;

  static const _flipMs = 260.0;

  /// [pop] = 튀어나온 뒤 ms, [flyT] < 0이면 아직 떠 있음(0~1 배로 날아가는 중). [popMs] = 튀어나오는 시간.
  void draw(
    Canvas c,
    LootCard card,
    Offset p,
    double age,
    double pop,
    double flyT,
    double popMs,
    SpriteDraw? sprites, {
    required String name,
    required String newCrew,
    String? extra,
  }) {
    final big = card.big;
    final shrink = flyT > 0 ? 1 - flyT * 0.6 : 1.0;
    final base = big > 0 ? 1 + 0.8 * big : (card.reveal ? 1.6 : 0.85);
    final flipT = card.reveal ? ((pop - popMs) / _flipMs).clamp(0.0, 1.0) : 1.0;
    final facing = flyT >= 0 || flipT >= 0.5;
    final grow = base * shrink * (card.reveal && flyT < 0 ? 0.7 + 0.3 * flipT : 1);
    if ((big > 0 || card.reveal) && flyT < 0 && facing) _bits.halo(c, p, age, math.max(1, big), card.color);
    c
      ..save()
      ..translate(p.dx, p.dy)
      ..scale(grow);
    _bits.card(
      c,
      Offset.zero,
      (card.crewId, card.color),
      age,
      sprites,
      spin: !card.reveal && big == 0,
      back: !facing,
      scaleX: flyT >= 0 ? 1 : math.cos(math.pi * flipT).abs(),
      stars: card.reveal || big > 0 ? card.stars : 0,
    );
    c.restore();
    if (flyT >= 0 || pop < popMs * 0.6) return;
    if (card.count > 1) _label.draw(c, '×${card.count}', p + const Offset(7, 9), 7);
    if (extra != null) _label.draw(c, extra, p + const Offset(16, 0), 8);
    var y = 13 * grow + 5;
    if ((card.reveal || big > 0) && flipT >= 1 && name.isNotEmpty) {
      _label.draw(c, name, p + Offset(0, y), 8 + 1.5 * math.max(1, big), color: Color(card.color));
      y += 12 + 2.0 * big;
    }
    if (big > 0) {
      _label.draw(c, newCrew, p + Offset(0, y), 9 + 2.0 * big, alpha: math.min(1, (pop - popMs * 0.6) / 200));
    }
  }
}
