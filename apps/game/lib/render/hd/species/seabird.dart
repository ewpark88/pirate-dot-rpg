import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/hd/hd_kit_parts.dart';

/// 바닷새 3종(갈매기·폭풍갈매기·눈갈매기)이 같이 쓰는 몸 — 같은 공중 실루엣, 해역 색·날개 꺾임·볏·둥글기로 구분
/// (docs/specs/platform-hd-monsters-a.md). 옆모습·왼쪽을 본다. 원거리(깃털)라 쏘는 부위 = 부리를 크게·강조색.
typedef SeabirdLook = ({
  Color body,
  Color bodyD,
  Color wingTip,
  Color wingTipD,
  bool angry,
  bool crest,
  double bend,
  double round,
});

void drawSeabird(HdKit k, Canvas c, double r, double t, SeabirdLook look) {
  final flap = k.wave(t, 2); // 고리에 날갯짓 두 번
  final bob = k.wave(t, 2, 1.2) * r * 0.05;
  c
    ..save()
    ..translate(0, bob);
  // 뒤 날개(조금 어둡게, 반 박자 늦게) → 꼬리(오른쪽 뒤).
  k
    ..wing(
      c,
      Offset(r * 0.15, -r * 0.1),
      r * 1.25,
      -flap * 0.5 + 0.1,
      look.bodyD,
      look.bodyD,
      tip: look.wingTipD,
      tipDark: look.wingTipD,
      bend: look.bend,
    )
    ..tail(c, Offset(r * 0.6, r * 0.1), r * 0.45, -0.15, look.body, look.bodyD);
  // 몸통(옆으로 긴 타원 — round가 크면 통통).
  final body = Path()
    ..addOval(
      Rect.fromCenter(center: Offset(r * 0.05, r * 0.12), width: r * 1.45, height: r * (0.85 + look.round * 0.25)),
    );
  k.blob(c, body, look.body, look.bodyD);
  // 머리(왼쪽 앞).
  final head = Path()
    ..addOval(Rect.fromCenter(center: Offset(-r * 0.62, -r * 0.18), width: r * 0.78, height: r * 0.72));
  k.blob(c, head, look.body, look.bodyD);
  if (look.crest) {
    // 볏: 머리 뒤로 뻗친 깃 세 가닥.
    for (final (dx, dy) in const [(-0.45, -0.5), (-0.35, -0.52), (-0.25, -0.48)]) {
      k.limb(
        c,
        Path()
          ..moveTo(r * dx, r * dy)
          ..quadraticBezierTo(r * (dx + 0.15), r * (dy - 0.22), r * (dx + 0.35), r * (dy - 0.18)),
        look.wingTip,
        r * 0.07,
      );
    }
  }
  // 부리(쏘는 부위): 크게, 노랑 + 빨간 점. 고리에 한 번 벌렸다 닫음.
  final open = (k.wave(t, 1) + 1) * 0.5 * r * 0.06;
  final beak = Path()
    ..moveTo(-r * 0.92, -r * 0.3)
    ..lineTo(-r * 1.42, -r * 0.12 - open)
    ..lineTo(-r * 0.92, -r * 0.02)
    ..close();
  k.blob(c, beak, const Color(0xFFFFE04A), const Color(0xFFE39A00), gloss: false, line: 0.6);
  k.fill.color = const Color(0xFFE5322A);
  c.drawCircle(Offset(-r * 1.18, -r * 0.1), r * 0.06, k.fill);
  // 앞 날개(크게, 날갯짓) → 눈.
  k
    ..wing(
      c,
      Offset(-r * 0.05, -r * 0.02),
      r * 1.35,
      -flap * 0.5,
      look.body,
      look.bodyD,
      tip: look.wingTip,
      tipDark: look.wingTipD,
      bend: look.bend,
    )
    ..eye(c, Offset(-r * 0.72, -r * 0.28), r * 0.3, angry: look.angry, look: -1);
  if (!look.angry) k.cheeks(c, Offset(-r * 0.62, -r * 0.05), 0, r * 0.18);
  c.restore();
}
