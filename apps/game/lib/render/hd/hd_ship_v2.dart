part of 'hd_ship.dart';

/// HD v2 플레이어 배(사용자 '배도 퀄리티'): 갑판 나무결·옹이, 밧줄(돛대 → 뱃전), 돛이 갑판에 드리운 그림자, 대포 금속 반사,
/// 뱃전 림 라이트, 등급 장식(슬루프 뱃머리 조각·군함 금빛 선수상과 고물 등불·유령선 초록 혼불과 해골 선수상).
extension _HdShipV2 on HdShip {
  /// 갑판 나무결: 판자마다 엇갈린 이음매 + 물결 결 + 옹이.
  void _grain(Canvas c, double len, double hw, double rimW, HdShipColors col) {
    final k = _k;
    final iw = k.ink.strokeWidth;
    final grain = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = iw * 0.22
      ..color = col.deckD.withValues(alpha: 0.55);
    final inner = hw - rimW;
    for (var i = -2; i < 2; i++) {
      final x = (i + 0.5) * inner * 0.36;
      // 판자 이음매(엇갈림)
      final seam = len * (i.isEven ? -0.1 : 0.12);
      c.drawLine(Offset(x - inner * 0.17, seam), Offset(x + inner * 0.17, seam), grain);
      // 물결 결
      final p = Path()..moveTo(x - inner * 0.05, -len * 0.28);
      for (var j = 1; j <= 6; j++) {
        p.lineTo(x - inner * 0.05 + math.sin(j * 1.7 + i) * inner * 0.025, -len * 0.28 + j * len * 0.11);
      }
      c.drawPath(p, grain);
    }
    // 옹이 둘
    k.fill.color = col.deckD.withValues(alpha: 0.5);
    for (final (x, y) in const [(-0.3, 0.05), (0.25, -0.2)]) {
      c.drawOval(Rect.fromCenter(center: Offset(x * inner, y * len), width: inner * 0.09, height: len * 0.03), k.fill);
    }
  }

  /// 밧줄: 돛대 머리에서 양 뱃전으로(돛 아래로 지나가게 돛보다 먼저).
  void _rigging(Canvas c, double len, double hw, int sailStage, HdShipColors col) {
    final masts = sailStage >= 5 ? 3 : (sailStage >= 3 ? 2 : 1);
    final rope = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = _k.ink.strokeWidth * 0.32
      ..color = const Color(0xCC5A3A22);
    for (var m = 0; m < masts; m++) {
      final y = len * (masts == 1 ? -0.06 : (-0.26 + m * 0.44 / (masts - 1)));
      for (final s in const [-1.0, 1.0]) {
        for (final dy in const [-0.06, 0.08]) {
          c.drawLine(Offset(0, y), Offset(s * hw * 0.92, y + len * dy), rope);
        }
      }
    }
  }

  /// 돛 그림자: 돛마다 뒤쪽 갑판에 비스듬한 어두운 띠.
  void _sailShadows(Canvas c, double len, double hw, int sailStage) {
    final masts = sailStage >= 5 ? 3 : (sailStage >= 3 ? 2 : 1);
    _k.fill.color = const Color(0x332A1A10);
    for (var m = 0; m < masts; m++) {
      final y = len * (masts == 1 ? -0.06 : (-0.26 + m * 0.44 / (masts - 1)));
      c.drawOval(
        Rect.fromCenter(center: Offset(hw * 0.12, y + len * 0.1), width: hw * 1.5, height: len * 0.07),
        _k.fill,
      );
    }
  }

  /// 등급 장식: 뱃머리 선수상·고물 등불.
  void _tierDecor(Canvas c, double len, double hw, String tier, double now) {
    final k = _k;
    final bow = Offset(0, -len / 2);
    switch (tier) {
      case 'sloop':
        k.blob(
          c,
          Path()..addOval(Rect.fromCircle(center: bow + Offset(0, len * 0.03), radius: hw * 0.12)),
          const Color(0xFFD8A060),
          const Color(0xFF7A4A22),
          gloss: false,
          line: 0.5,
        );
      case 'warship':
        // 금빛 선수상(뿔 달린 머리) + 뱃머리 기움 돛대
        k.limb(
          c,
          Path()
            ..moveTo(bow.dx, bow.dy + len * 0.04)
            ..lineTo(bow.dx, bow.dy - len * 0.08),
          const Color(0xFF8A5A30),
          hw * 0.08,
        );
        k.blob(
          c,
          Path()
            ..moveTo(bow.dx - hw * 0.14, bow.dy + len * 0.05)
            ..lineTo(bow.dx, bow.dy - len * 0.03)
            ..lineTo(bow.dx + hw * 0.14, bow.dy + len * 0.05)
            ..close(),
          const Color(0xFFFFE27A),
          const Color(0xFFD8901A),
          gloss: false,
          line: 0.5,
        );
        _lanterns(c, len, hw, const Color(0xFFFFD45A), now);
      case 'ghost':
        // 해골 선수상 + 초록 혼불 등
        k.blob(
          c,
          Path()..addOval(Rect.fromCircle(center: bow + Offset(0, len * 0.03), radius: hw * 0.14)),
          const Color(0xFFF4F0E4),
          const Color(0xFFA89E88),
          gloss: false,
          line: 0.5,
        );
        k.fill.color = HdKit.inkColor;
        for (final s in const [-1.0, 1.0]) {
          c.drawCircle(bow + Offset(s * hw * 0.05, len * 0.025), hw * 0.035, k.fill);
        }
        _lanterns(c, len, hw, const Color(0xFF7AFFB0), now);
    }
  }

  /// 고물 양쪽 등불(빛 번짐 + 깜빡임).
  void _lanterns(Canvas c, double len, double hw, Color color, double now) {
    final flick = now == 0 ? 1.0 : 0.8 + 0.2 * math.sin(now / 90);
    for (final s in const [-1.0, 1.0]) {
      final at = Offset(s * hw * 0.62, len * 0.47);
      _k.fill.color = color.withValues(alpha: 0.3 * flick);
      c.drawCircle(at, hw * 0.2, _k.fill);
      _k.fill.color = color;
      c.drawCircle(at, hw * 0.07, _k.fill);
    }
  }
}
