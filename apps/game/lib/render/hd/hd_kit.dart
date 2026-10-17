import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show Alignment, LinearGradient;
import 'package:pirate_dot/render/hd/hd_kit_v2.dart';

/// 한 종 그리기(docs/specs/render-hd-style.md): 가운데 원점, 반지름 [r], 시각 [t](ms) — 정면 3/4·왼쪽 봄, 움직임은 [HdKit.wave]로.
typedef HdDraw = void Function(HdKit k, Canvas c, double r, double t);

/// HD 종 하나: 그리기 + 크기 규격.
class HdSpecies {
  const HdSpecies(this.draw, {this.extent = 1.4, this.ground = 0.75, this.muzzle});

  final HdDraw draw;

  /// 그림이 원점에서 r의 몇 배까지 뻗나 — 굽기 칸 한 변 = 2·extent·r.
  final double extent;

  /// 그림자 타원 중심 높이(r 배수, 아래가 +). 날짐승은 더 아래로(떠 있게).
  final double ground;

  /// 쏘는 부위 자리(r 배수, 왼쪽 보기 기준, null = 몸 가운데) — 쏘기 직전 TopEnemies가 번쩍인다(오른쪽 볼 땐 x 뒤집기).
  final Offset? muzzle;
}

/// HD 카툰 공용 부품(쿵푸할매 서바이버 스타일): 굵은 외곽선·그라데이션·광택·큰 눈 — 모든 종이 이것만 쓰면 같은 품질(붓 재사용).
class HdKit {
  HdMood mood = HdMood.idle; // 지금 굽는 표정(HD v2 보스) — 종 코드가 읽어 얼굴·자세를 바꾼다
  /// 애니메이션 고리 길이 — 0.1초 × 8장.
  static const loopMs = 800.0;
  static const frames = 8;

  /// 외곽선 색(순검정 대신 아주 어두운 보라 — 팔레트와 어울림).
  static const inkColor = Color(0xFF1A1424);

  final fill = Paint()..isAntiAlias = true;
  final ink = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = inkColor;
  final _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  /// 외곽선 두께 규칙: r의 11%, 최소 2.5px. 종을 그리기 전에 굽기가 부른다.
  void begin(double r) => ink.strokeWidth = math.max(2.5, r * 0.11);

  /// 고리 파동: 한 고리(800ms)에 [n]번 오르내림 — 8장째가 1장째로 이어진다. [off]는 부위마다 어긋나게.
  double wave(double t, int n, [double off = 0]) => math.sin(2 * math.pi * n * t / loopMs + off);

  /// 몸 덩어리: [light]→[dark] 그라데이션 + 외곽선 + 광택·림 라이트. 작은 부품은 [line] 0.5~0.7로 선을 얇게.
  void blob(Canvas c, Path p, Color light, Color dark, {bool gloss = true, double line = 1}) {
    final b = p.getBounds();
    fill // 셰이더 출력은 붓 색 알파를 곱한다 — 앞에서 남은 반투명 색을 지운다.
      ..color = const Color(0xFFFFFFFF)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light, dark],
      ).createShader(b);
    c.drawPath(p, fill);
    fill.shader = null;
    final w = ink.strokeWidth;
    ink.strokeWidth = w * line;
    c.drawPath(p, ink);
    ink.strokeWidth = w;
    if (!gloss) return;
    rim(c, p, Color.lerp(light, const Color(0xFFFFFFFF), 0.55)!.withValues(alpha: 0.55), width: 0.7); // v2 림 라이트
    shine(c, b);
  }

  /// 광택: 덩어리 [b]의 왼쪽 위 흰 타원 + 반짝 점.
  void shine(Canvas c, Rect b) {
    fill.color = const Color(0x99FFFFFF);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(b.left + b.width * 0.32, b.top + b.height * 0.24),
        width: b.width * 0.28,
        height: b.height * 0.14,
      ),
      fill,
    );
    fill.color = const Color(0xCCFFFFFF);
    c.drawCircle(Offset(b.left + b.width * 0.2, b.top + b.height * 0.3), b.width * 0.035, fill);
  }

  /// 큰 카툰 눈: 흰자 + 검은 눈동자 + 반짝 두 점 + 외곽선. [angry]면 눈썹, [look](-1 왼쪽 ~ 1 오른쪽)은 눈동자 방향.
  void eye(Canvas c, Offset at, double s, {bool angry = false, double look = 0}) {
    if (mood == HdMood.down) return dizzyEye(c, at, s, 0); // v2 표정: 쓰러짐 = 소용돌이 눈, 예고 = 붉은 눈(아래)
    final white = Rect.fromCenter(center: at, width: s, height: s * 1.15);
    // 작은 눈은 선을 눈 크기에 맞춰 얇게(굵은 선에 흰자가 묻히지 않게) — 끝에 되돌린다.
    final w = ink.strokeWidth;
    ink.strokeWidth = math.min(w, s * 0.16);
    fill.color = const Color(0xFFFFFFFF);
    c
      ..drawOval(white, fill)
      ..drawOval(white, ink);
    fill.color = inkColor;
    c.drawOval(
      Rect.fromCenter(center: at + Offset(look * s * 0.15, s * 0.08), width: s * 0.55, height: s * 0.68),
      fill,
    );
    fill.color = const Color(0xFFFFFFFF);
    c
      ..drawCircle(at + Offset(-s * 0.08 + look * s * 0.15, -s * 0.08), s * 0.14, fill)
      ..drawCircle(at + Offset(s * 0.12 + look * s * 0.15, s * 0.2), s * 0.06, fill);
    if (angry) c.drawLine(at + Offset(-s * 0.55, -s * 0.85), at + Offset(s * 0.45, -s * 0.55), ink);
    ink.strokeWidth = w;
    if (mood == HdMood.windup) angerEye(c, at, s);
  }

  /// 웃는 입(아래로 휜 선) — 가운데 [at], 폭 [w].
  void smile(Canvas c, Offset at, double w) {
    c.drawPath(
      Path()
        ..moveTo(at.dx - w / 2, at.dy)
        ..quadraticBezierTo(at.dx, at.dy + w * 0.55, at.dx + w / 2, at.dy),
      ink,
    );
  }

  /// 벌린 입(검붉은 속 + 외곽선) — [p]는 닫힌 입 모양.
  void mouth(Canvas c, Path p) {
    fill.color = const Color(0xFF6A1424);
    c
      ..drawPath(p, fill)
      ..drawPath(p, ink);
  }

  /// 흰 이빨 하나: 윗변 왼쪽 [a]에서 폭 [w], 아래로 [h](음수면 위로).
  void tooth(Canvas c, Offset a, double w, double h) {
    fill.color = const Color(0xFFFFFFFF);
    c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(a.dx + w / 2, a.dy + h)
        ..lineTo(a.dx + w, a.dy)
        ..close(),
      fill,
    );
  }

  /// 분홍 볼(양쪽) — 가운데 [at]에서 좌우 [dx], 크기 [s].
  void cheeks(Canvas c, Offset at, double dx, double s) {
    fill.color = const Color(0x88FFB0C0);
    for (final k in const [-1.0, 1.0]) {
      c.drawOval(Rect.fromCenter(center: at + Offset(k * dx, 0), width: s, height: s * 0.55), fill);
    }
  }

  /// 외곽선 두른 색 줄(다리·촉수·더듬이): 굵기 [w], 색 [color].
  void limb(Canvas c, Path p, Color color, double w) {
    _stroke
      ..strokeWidth = w + ink.strokeWidth * 2
      ..color = inkColor;
    c.drawPath(p, _stroke);
    _stroke
      ..strokeWidth = w
      ..color = color;
    c.drawPath(p, _stroke);
  }

  /// 꿈틀 촉수: [from]에서 방향 [angle](라디안, 0 = 오른쪽·π/2 = 아래)으로 길이 [len], [n]마디가 [phase]로 흔들린다.
  void tentacle(Canvas c, Offset from, double angle, double len, double phase, Color color, double w, {int n = 4}) {
    final p = Path()..moveTo(from.dx, from.dy);
    final d = Offset(math.cos(angle), math.sin(angle));
    final side = Offset(-d.dy, d.dx);
    for (var k = 1; k <= n; k++) {
      final q = from + d * (len * k / n) + side * (math.sin(phase + k) * len * 0.24 * k / n);
      p.lineTo(q.dx, q.dy);
    }
    limb(c, p, color, w);
  }

  /// 집게(번쩍 든): 뿌리 [at], 각도 [angle], 크기 [r], [open](0~1) 벌림.
  void pincer(Canvas c, Offset at, double r, double angle, Color light, Color dark, {double open = 0}) {
    c
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle);
    final arm = Path()..addOval(Rect.fromCenter(center: Offset(0, r * 0.28), width: r * 0.3, height: r * 0.5));
    blob(c, arm, light, dark, gloss: false);
    final g = r * 0.1 * open;
    final claw = Path()
      ..moveTo(-r * 0.32, 0)
      ..cubicTo(-r * 0.4, -r * 0.5 - g, r * 0.05, -r * 0.62 - g, r * 0.12, -r * 0.3)
      ..lineTo(0, -r * 0.18)
      ..lineTo(r * 0.3, -r * 0.42 - g)
      ..cubicTo(r * 0.42, -r * 0.1, r * 0.25, r * 0.15, 0, r * 0.12)
      ..close();
    blob(c, claw, light, dark);
    c.restore();
  }

  /// 물고기 꼬리(오목 삼각): 뿌리 [at], 길이 [r], 각도 [angle](0 = 오른쪽으로 뻗음).
  void tail(Canvas c, Offset at, double r, double angle, Color light, Color dark) {
    c
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(angle);
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(r, -r * 0.8)
      ..quadraticBezierTo(r * 0.72, 0, r, r * 0.8)
      ..close();
    blob(c, p, light, dark, gloss: false);
    c.restore();
  }

  /// 금관(보스 표시): 아랫변 가운데 [at], 폭 [w].
  void crown(Canvas c, Offset at, double w) {
    final h = w * 0.62;
    final p = Path()
      ..moveTo(at.dx - w / 2, at.dy)
      ..lineTo(at.dx - w * 0.43, at.dy - h * 0.73)
      ..lineTo(at.dx - w * 0.17, at.dy - h * 0.3)
      ..lineTo(at.dx, at.dy - h)
      ..lineTo(at.dx + w * 0.17, at.dy - h * 0.3)
      ..lineTo(at.dx + w * 0.43, at.dy - h * 0.73)
      ..lineTo(at.dx + w / 2, at.dy)
      ..close();
    blob(c, p, const Color(0xFFFFE27A), const Color(0xFFE0A020));
  }

  /// 무늬 점들(외곽선 없음): (x, y, 반지름) 모두 r 배수.
  void spots(Canvas c, double r, List<(double, double, double)> at, Color color) {
    fill.color = color;
    for (final (x, y, s) in at) {
      c.drawCircle(Offset(x * r, y * r), s * r, fill);
    }
  }

  /// 수중 종(regions layer underwater): 몸 [body] 모양 안에서만 아래 30%가 물빛으로 옅어진다 — 외곽선은 다시 그어 또렷하게.
  void underwater(Canvas c, Path body) {
    final box = body.getBounds();
    c
      ..save()
      ..clipPath(body);
    fill
      ..color = const Color(0xFFFFFFFF)
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x002F9FD4), Color(0x002F9FD4), Color(0x662F9FD4)],
        stops: [0, 0.7, 1],
      ).createShader(box);
    c.drawRect(box, fill);
    fill.shader = null;
    c
      ..restore()
      ..drawPath(body, ink);
  }

  /// 오르는 거품 3개(수중 종) — [at] 오른쪽 위로, 한 고리에 한 번 올라가 이어진다.
  void bubbles(Canvas c, double r, double t, {Offset at = Offset.zero}) {
    _stroke
      ..strokeWidth = math.max(1.5, r * 0.04)
      ..color = const Color(0xCCFFFFFF);
    for (var i = 0; i < 3; i++) {
      final u = (t / loopMs + i / 3) % 1;
      c.drawCircle(
        at + Offset(r * (0.55 + i * 0.18), -r * (0.3 + u * 0.9)),
        r * (0.06 + i * 0.025) * (1 - u * 0.4),
        _stroke,
      );
    }
  }

  /// 펼친 날개(공중 종): 뿌리 [root]에서 방향 [angle](0 = 오른쪽)으로 길이 [len], 깃 끝 3갈래. [flap] 0~1 = 접힘~펼침(k.wave로).
  void wing(Canvas c, Offset root, double len, double angle, double flap, Color light, Color dark) {
    c
      ..save()
      ..translate(root.dx, root.dy)
      ..rotate(angle - (1 - flap) * 0.6);
    final h = len * (0.3 + 0.25 * flap);
    final p = Path()
      ..moveTo(0, -h * 0.35)
      ..quadraticBezierTo(len * 0.55, -h * 1.1, len, -h * 0.45)
      ..quadraticBezierTo(len * 0.9, -h * 0.05, len * 0.82, h * 0.05)
      ..quadraticBezierTo(len * 0.74, h * 0.35, len * 0.6, h * 0.25)
      ..quadraticBezierTo(len * 0.5, h * 0.55, len * 0.36, h * 0.38)
      ..quadraticBezierTo(len * 0.18, h * 0.5, 0, h * 0.3)
      ..close();
    blob(c, p, light, dark, gloss: false);
    c.restore();
  }

  /// 바다 위 그림자 — 굽기가 종마다 자동으로 깐다.
  void shadow(Canvas c, double r, double ground) {
    fill.color = const Color(0x40061A30);
    c.drawOval(Rect.fromCenter(center: Offset(0, r * ground), width: r * 1.7, height: r * 0.5), fill);
  }
}

/// HD v2 보스 표정 — 굽기가 줄마다 바꿔 넣는다.
enum HdMood { idle, windup, down }
