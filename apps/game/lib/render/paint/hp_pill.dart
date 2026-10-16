import 'dart:ui';

import 'package:game_data/game_data.dart';

/// 둥근 알약형 체력 막대 (사용자 지시 2026-10-16 — 스킨 r1 귀여운 톤): 진한 남색 테두리 1, 안쪽 위 하이라이트 줄,
/// 10% 눈금, 깎인 만큼 늦게 줄어드는 흰 조각, 왼쪽 작은 도트 아이콘(하트=내 배, 해골=보스).
/// 색은 딱 끊는 3단계: [midBelow] 이상 초록 · 미만 노랑 · [lowBelow] 미만 빨강. 값은 fx_map `shipHp`.
class HpPill {
  HpPill(JsonReader cfg)
    : _full = _c(cfg, 'full'),
      _mid = _c(cfg, 'mid'),
      _low = _c(cfg, 'low'),
      _back = _c(cfg, 'back'),
      _edge = _c(cfg, 'edge'),
      _lagColor = _c(cfg, 'lag'),
      midBelow = cfg.number('midBelow'),
      lowBelow = cfg.number('lowBelow');

  static int _c(JsonReader cfg, String k) => parseArgb(cfg.str(k), 'shipHp.$k');

  final int _full;
  final int _mid;
  final int _low;
  final int _back;
  final int _edge;
  final int _lagColor;

  /// 이 비율 미만이면 노랑.
  final double midBelow;

  /// 이 비율 미만이면 빨강(깜빡임도 빨강일 때만).
  final double lowBelow;

  final _paint = Paint()..isAntiAlias = false;

  /// 비율 [r]의 막대 색 (3단계, 보간 없음).
  int colorFor(double r) => r < lowBelow ? _low : (r < midBelow ? _mid : _full);

  /// 빨강 단계인가 (깜빡임).
  bool isLow(double r) => r < lowBelow;

  static const _heart = ['.x.x.', 'xxxxx', 'xxxxx', '.xxx.', '..x..'];
  static const _skull = ['.xxx.', 'xxxxx', 'x.x.x', 'xxxxx', '.x.x.'];

  /// 막대 그리기. ([left],[top]) = 바깥 테두리 왼쪽 위, [w]×[h] = 테두리 포함 크기(단위).
  /// [fill]은 막대 색(깜빡임·회복 빛을 얹은 뒤), [edge]는 테두리 색(맞으면 흰빛 등, 없으면 남색).
  void paint(
    Canvas c, {
    required double left,
    required double top,
    required double w,
    required double h,
    required double ratio,
    required double lag,
    required int fill,
    int? edge,
    bool skull = false,
  }) {
    const iconW = 6.0;
    final bl = left + iconW;
    final bw = w - iconW;
    final e = edge ?? _edge;
    // 둥근 테두리: 모서리 1칸을 깎은 사각형 두 장.
    _rect(c, bl + 1, top, bw - 2, h, e);
    _rect(c, bl, top + 1, bw, h - 2, e);
    final il = bl + 1;
    final it = top + 1;
    final iw = bw - 2;
    final ih = h - 2;
    _rect(c, il, it, iw, ih, _back);
    final lw = (iw * lag.clamp(0.0, 1.0)).roundToDouble();
    final fw = (iw * ratio.clamp(0.0, 1.0)).roundToDouble();
    if (lw > fw) _rect(c, il + fw, it, lw - fw, ih, _lagColor);
    if (fw > 0) {
      _rect(c, il, it, fw, ih, fill);
      _rect(c, il, it, fw, 1, Color.lerp(Color(fill), const Color(0xFFFFFFFF), 0.55)!.toARGB32()); // 위 하이라이트
      _rect(c, il, it + ih - 1, fw, 1, Color.lerp(Color(fill), const Color(0xFF000000), 0.25)!.toARGB32()); // 아래 그늘
    }
    // 10% 눈금(작은 칸 구분) — 막대 안쪽 세로 줄.
    for (var i = 1; i < 10; i++) {
      final x = (il + iw * i / 10).roundToDouble();
      _rect(c, x, it + 1, 1, ih - 1, (0x40 << 24) | (_edge & 0xFFFFFF));
    }
    // 아이콘(하트·해골): 테두리 남색 1칸 + 안 색.
    final rows = skull ? _skull : _heart;
    final ic = skull ? 0xFFF4F1E8 : 0xFFFF5A6E;
    final iy = (top + (h - rows.length) / 2).roundToDouble();
    for (var y = -1; y <= rows.length; y++) {
      for (var x = -1; x <= 5; x++) {
        final on = y >= 0 && y < rows.length && x >= 0 && x < 5 && rows[y][x] == 'x';
        if (on) {
          _rect(c, left + x, iy + y, 1, 1, ic);
        } else if (_near(rows, x, y)) {
          _rect(c, left + x, iy + y, 1, 1, _edge);
        }
      }
    }
  }

  static bool _near(List<String> rows, int x, int y) {
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx;
      final ny = y + dy;
      if (ny >= 0 && ny < rows.length && nx >= 0 && nx < 5 && rows[ny][nx] == 'x') return true;
    }
    return false;
  }

  void _rect(Canvas c, double l, double t, double w, double h, int argb) {
    _paint.color = Color(argb);
    c.drawRect(Rect.fromLTWH(l, t, w, h), _paint);
  }
}
