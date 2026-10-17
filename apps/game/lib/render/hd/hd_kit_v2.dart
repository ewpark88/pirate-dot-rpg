import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

/// HD v2 부품(사용자 '보스 캐릭터 퀄리티를 한 단계 더'): 림 라이트(가장자리 빛)·이중 광택·그림자 2단·몸 무늬(비늘)·쓰러짐 눈.
/// v1 부품(HdKit) 위에 얹는다 — v1 종은 그대로.
extension HdKitV2 on HdKit {
  /// 림 라이트: 덩어리 [p] 안쪽 오른쪽 아래 가장자리를 따라 [color] 빛 띠(역광 — 몸이 바다에서 떠 보인다).
  void rim(Canvas c, Path p, Color color, {double width = 1}) {
    final w = ink.strokeWidth * 0.8 * width;
    // 원래 모양 − 왼쪽 위로 민 모양 = 오른쪽 아래 가장자리 띠.
    final band = Path.combine(PathOperation.difference, p, p.shift(Offset(-w, -w)));
    fill.color = color;
    c
      ..drawPath(band, fill)
      ..drawPath(p, ink); // 띠가 덮은 외곽선 안쪽 반을 다시
  }

  /// 이중 광택: 왼쪽 위 큰 타원 + 작은 반짝 점 + 오른쪽 위 가는 둘째 광택(젤리·도자기처럼).
  void shine2(Canvas c, Rect b) {
    shine(c, b);
    fill.color = const Color(0x66FFFFFF);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(b.left + b.width * 0.7, b.top + b.height * 0.2),
        width: b.width * 0.12,
        height: b.height * 0.06,
      ),
      fill,
    );
  }

  /// 그림자 2단: 넓고 옅은 바깥 + 좁고 짙은 안쪽(붙어 있는 느낌).
  void shadow2(Canvas c, double r, double ground) {
    fill.color = const Color(0x26061A30);
    c.drawOval(Rect.fromCenter(center: Offset(0, r * ground), width: r * 2.2, height: r * 0.7), fill);
    fill.color = const Color(0x4D061A30);
    c.drawOval(Rect.fromCenter(center: Offset(0, r * ground), width: r * 1.4, height: r * 0.38), fill);
  }

  /// 비늘 무늬: 사각 [area] 안에 반달 줄을 엇갈려(색 [color], 크기 [s]).
  void scales(Canvas c, Rect area, double s, Color color) {
    final p = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = ink.strokeWidth * 0.35
      ..color = color;
    var row = 0;
    for (var y = area.top; y < area.bottom; y += s * 0.7, row++) {
      for (var x = area.left + (row.isOdd ? s / 2 : 0); x < area.right; x += s) {
        c.drawArc(Rect.fromCenter(center: Offset(x, y), width: s, height: s * 0.8), 0.2, math.pi - 0.4, false, p);
      }
    }
  }

  /// 쓰러짐 눈: 소용돌이(어지러움) — 가운데 [at], 크기 [s].
  void dizzyEye(Canvas c, Offset at, double s, double t) {
    final white = Rect.fromCenter(center: at, width: s, height: s * 1.15);
    final w0 = ink.strokeWidth;
    ink.strokeWidth = math.min(w0, s * 0.16); // 작은 눈은 선을 얇게(HdKit.eye와 같은 규칙)
    fill.color = const Color(0xFFFFFFFF);
    c
      ..drawOval(white, fill)
      ..drawOval(white, ink);
    final sp = Path();
    for (var i = 0; i <= 24; i++) {
      final a = i / 24 * math.pi * 3.5 + t / 120;
      final rr = s * 0.38 * i / 24;
      final q = at + Offset(math.cos(a) * rr, math.sin(a) * rr * 1.1);
      i == 0 ? sp.moveTo(q.dx, q.dy) : sp.lineTo(q.dx, q.dy);
    }
    ink.strokeWidth = math.min(w0, s * 0.16) * 0.8;
    c.drawPath(sp, ink);
    ink.strokeWidth = w0;
  }
}
