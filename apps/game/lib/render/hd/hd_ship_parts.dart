part of 'hd_ship.dart';

/// HD 플레이어 배 부위(화물·대포·선원·돛·망루) — hd_ship.dart 300줄 한도로 나눔.
extension _HdShipParts on HdShip {
  void _cargo(Canvas c, double len, double hw, int stage) {
    // 통·상자: 단계만큼(최대 7) 갑판 뒤쪽 양옆에
    for (var i = 0; i < stage; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final row = i ~/ 2;
      final at = Offset(side * hw * 0.42, len * (0.16 - row * 0.12));
      if (row.isEven) {
        _k.blob(
          c,
          Path()..addOval(Rect.fromCircle(center: at, radius: hw * 0.16)),
          const Color(0xFFD89A5A),
          const Color(0xFF8A5428),
          gloss: false,
          line: 0.5,
        );
        _k.fill.color = const Color(0xFF6A6A72);
        c.drawCircle(at, hw * 0.06, _k.fill);
      } else {
        _k.blob(
          c,
          Path()..addRect(Rect.fromCenter(center: at, width: hw * 0.3, height: hw * 0.3)),
          const Color(0xFFE8B070),
          const Color(0xFF9A6430),
          gloss: false,
          line: 0.5,
        );
      }
    }
  }

  void _cannons(Canvas c, double len, double hw, int stage, double recoil) {
    // 양옆 포: 단계에 따라 한쪽 1~4문, 6단계부터 뱃머리 포 하나. 반동이면 안쪽으로 밀림.
    final n = ((stage + 1) / 2).floor().clamp(1, 4);
    final push = hw * 0.18 * recoil;
    for (var i = 0; i < n; i++) {
      final y = len * (-0.12 + i * 0.16) - (n - 1) * len * 0.04;
      for (final s in const [-1.0, 1.0]) {
        final base = Offset(s * (hw * 0.82 - push), y);
        final barrel = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: base + Offset(s * hw * 0.2, 0), width: hw * 0.42, height: hw * 0.2),
              Radius.circular(hw * 0.08),
            ),
          );
        _k.blob(c, barrel, const Color(0xFF7A808C), const Color(0xFF2A2E38), line: 0.6);
        // v2 금속 반사: 포신 위쪽 가는 흰 줄
        _k.fill.color = const Color(0xAAFFFFFF);
        c.drawRect(
          Rect.fromCenter(center: base + Offset(s * hw * 0.22, -hw * 0.05), width: hw * 0.3, height: hw * 0.035),
          _k.fill,
        );
      }
    }
    if (stage >= 6) {
      final bow = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(0, -len * 0.4 + push), width: hw * 0.2, height: hw * 0.44),
            Radius.circular(hw * 0.08),
          ),
        );
      _k.blob(c, bow, const Color(0xFFFFD45A), const Color(0xFFB07A1A), line: 0.6);
    }
  }

  /// 갑판 위 선원 머리 셋(귀엽게 — 두건 색 다르게).
  void _crew(Canvas c, double len, double hw) {
    for (final (x, y, band) in const [
      (-0.32, 0.02, Color(0xFFE8403A)),
      (0.3, -0.06, Color(0xFF3A8AE8)),
      (0.05, 0.24, Color(0xFF4ACB6A)),
    ]) {
      final at = Offset(x * hw, y * len);
      _k.blob(
        c,
        Path()..addOval(Rect.fromCircle(center: at, radius: hw * 0.15)),
        const Color(0xFFFFE0C0),
        const Color(0xFFE0A880),
        gloss: false,
        line: 0.5,
      );
      _k.fill.color = band;
      c.drawArc(Rect.fromCircle(center: at, radius: hw * 0.15), math.pi, math.pi, true, _k.fill);
    }
  }

  void _sails(Canvas c, double len, double hw, int stage, double billow, HdShipColors col, bool rainbow) {
    // 돛대: 1~2단계 1개, 3~4단계 2개, 5단계 3개. 위에서 본 네모돛 = 배 폭보다 넓게 부푼 둥근 판(앞이 볼록·밝고 뒤가 그늘).
    final masts = stage >= 5 ? 3 : (stage >= 3 ? 2 : 1);
    final span = hw * (1.7 + 0.1 * stage) * (1 + 0.08 * billow);
    final depth = len * (masts == 1 ? 0.2 : (masts == 2 ? 0.16 : 0.13)) * (1 + 0.25 * billow);
    for (var m = 0; m < masts; m++) {
      final y = len * (masts == 1 ? -0.06 : (-0.26 + m * 0.44 / (masts - 1)));
      final s = m == 0 && masts > 1 ? span * 0.84 : span;
      final back = y + depth * 0.45;
      final front = y - depth * 0.55;
      final sail = Path()
        ..moveTo(-s / 2, back)
        ..quadraticBezierTo(-s * 0.56, front + depth * 0.25, -s * 0.32, front + depth * 0.05)
        ..quadraticBezierTo(0, front - depth * 0.25, s * 0.32, front + depth * 0.05)
        ..quadraticBezierTo(s * 0.56, front + depth * 0.25, s / 2, back)
        ..quadraticBezierTo(0, back - depth * 0.18, -s / 2, back)
        ..close();
      if (rainbow) {
        _k.fill
          ..color = const Color(0xFFFFFFFF)
          ..shader = Gradient.linear(
            Offset(-s / 2, 0),
            Offset(s / 2, 0),
            const [Color(0xFFFF5A5A), Color(0xFFFFC23A), Color(0xFF5AD86A), Color(0xFF4AA8FF), Color(0xFFB45AFF)],
            const [0, 0.25, 0.5, 0.75, 1],
          );
        c.drawPath(sail, _k.fill);
        _k.fill.shader = null;
        c.drawPath(sail, _k.ink);
        _k.shine(c, sail.getBounds());
      } else {
        _k.blob(c, sail, col.sail, col.sailD);
      }
      // 돛 솔기 두 줄 + 활대(뒤 가장자리) + 돛대 머리
      final iw = _k.ink.strokeWidth;
      _k.ink
        ..strokeWidth = iw * 0.3
        ..color = col.sailD;
      for (final x in const [-0.18, 0.18]) {
        c.drawLine(Offset(x * s, front + depth * 0.02), Offset(x * s * 1.1, back - depth * 0.08), _k.ink);
      }
      _k.ink
        ..strokeWidth = iw * 0.8
        ..color = col.rimD;
      c.drawLine(Offset(-s * 0.52, back), Offset(s * 0.52, back), _k.ink);
      _k.ink
        ..strokeWidth = iw
        ..color = HdKit.inkColor;
      _k.fill.color = col.rimD;
      c.drawCircle(Offset(0, back), hw * 0.1, _k.fill);
    }
  }

  void _nest(Canvas c, double len, int stage, HdShipColors col, double now) {
    // 망루(v2): 돛대 위 나무 고리 발판(가운데 구멍·난간 점) + 해골 깃발(단계마다 크게, 펄럭)
    final at = Offset(0, -len * (0.08 + (stage >= 3 ? 0.16 : 0)));
    final r = len * (0.04 + 0.006 * stage);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: at, radius: r))
      ..addOval(Rect.fromCircle(center: at, radius: r * 0.55));
    _k.blob(c, ring, Color.lerp(col.rim, const Color(0xFFFFFFFF), 0.2)!, col.rimD, gloss: false, line: 0.5);
    _k.fill.color = col.rimD;
    c.drawCircle(at, r * 0.3, _k.fill);
    _k.fill.color = const Color(0xFFFFE8B0);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      c.drawCircle(at + Offset(math.cos(a), math.sin(a)) * r * 0.78, r * 0.08, _k.fill);
    }
    final wave = now == 0 ? 0.0 : math.sin(now / 160) * r * 0.3;
    final tip = at + Offset(r * (2.2 + 0.12 * stage), wave);
    final flag = Path()
      ..moveTo(at.dx + r * 0.3, at.dy - r * 0.35)
      ..quadraticBezierTo(at.dx + r * 1.4, at.dy - r * 0.7 + wave, tip.dx, tip.dy - r * 0.1)
      ..quadraticBezierTo(at.dx + r * 1.4, at.dy + r * 0.5 + wave, at.dx + r * 0.3, at.dy + r * 0.35)
      ..close();
    _k.blob(c, flag, Color.lerp(col.flag, const Color(0xFFFFFFFF), 0.25)!, col.flag, gloss: false, line: 0.5);
    // 해골 문양(흰 점 + 눈)
    final mid = Offset(at.dx + r * 1.25, at.dy - r * 0.05 + wave * 0.6);
    _k.fill.color = const Color(0xFFF4F0E4);
    c.drawCircle(mid, r * 0.22, _k.fill);
    _k.fill.color = col.flag;
    for (final s in const [-1.0, 1.0]) {
      c.drawCircle(mid + Offset(s * r * 0.08, -r * 0.02), r * 0.05, _k.fill);
    }
  }
}
