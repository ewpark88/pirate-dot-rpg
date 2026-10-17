import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';
import 'package:pirate_dot/render/scene/battle_scene.dart';

/// 갑판 위 선원 HD 미니 캐릭터(S1 '선원이 작은 머리 점이라 존재감이 없다'): 출전 선원마다 큰 머리(선원 HD 초상을 동그랗게)
/// + 짧은 몸(계열 색) + 계열 무기. 쏠 때(선원 칸 번쩍) 뒤로 반동·포구 연기, 돌격(근접)은 칼 휘두름, 필살기 1.2초는 두 손을
/// 들고 '!' 말풍선, 피버엔 통통 들썩. 배 위 맨 위 층(돛 위)이라 늘 보이고, 큰 배일수록 갑판이 넓어 더 크게 보인다.
class TopDeckCrew {
  final _k = HdKit();
  final _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// 갑판 자리(배 기준 — 폭 hw·길이 len 배수): 7자리까지, 앞(위)에서 뒤로 지그재그.
  static const List<(double, double)> _spots = [
    (-0.36, -0.22),
    (0.36, -0.18),
    (-0.38, 0.06),
    (0.38, 0.1),
    (0, -0.02),
    (-0.3, 0.3),
    (0.32, 0.32),
  ];

  static const _familyColor = {
    'lob': 0xFFE8503A,
    'ring': 0xFFFF9A3A,
    'cluster': 0xFFFFC23A,
    'direct': 0xFF3A5AA8,
    'pierce': 0xFFB8C4D8,
    'laser': 0xFFFF6FB5,
    'skip': 0xFF3AC8C0,
    'underwater': 0xFF3A8AE8,
    'air': 0xFFF4F8FF,
    'assault': 0xFFC83A4A,
    'shock': 0xFFFFE04A,
  };

  /// 배 칸 [size]·선체 단계 [hullSt] 기준으로 그린다(배 그림과 같은 좌표·같은 흔들림 안에서).
  void paint(Canvas c, SpriteDraw sprites, BattleScene scene, Size size, int hullSt, double now) {
    final fleet = scene.frame.fleet;
    if (fleet.isEmpty) return;
    final len = size.height * (0.78 + 0.18 * (hullSt - 1) / 6);
    final hw = size.width * (0.31 + 0.15 * (hullSt - 1) / 6);
    final r = hw * 0.2; // 머리 반지름
    _k.begin(r * 2.2);
    final fever = scene.frame.feverTicksLeft > 0;
    final ultAge = now - scene.topHits.feverStrike.startedAt;
    final ult = ultAge >= 0 && ultAge < 1200;
    for (var i = 0; i < fleet.length && i < _spots.length; i++) {
      final id = fleet[i].crewId;
      final fam = scene.tables.crews.crews.where((x) => x.id == id).firstOrNull?.family ?? 'lob';
      final (sx, sy) = _spots[i];
      final shot = i < scene.slotFlashMs.length ? scene.slotFlashMs[i] / 200 : 0.0; // 1 → 0
      final hop = fever ? -math.sin(now / 110 + i * 1.3).abs() * r * 0.5 : 0.0;
      final at = Offset(sx * hw, sy * len + hop + shot * r * 0.35); // 쏠 때 뒤(아래)로 반동
      _body(c, at, r, Color(_familyColor[fam] ?? 0xFFE8503A));
      _weapon(c, at, r, fam, shot, now, i);
      if (ult) _arms(c, at, r);
      _head(c, sprites, at - Offset(0, r * 0.9), r, id);
      if (ult && i == 0) _shout(c, at - Offset(-r * 1.1, r * 2.3), r, ultAge / 1200);
    }
  }

  void _body(Canvas c, Offset at, double r, Color color) {
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: r * 1.4, height: r * 1.1), Radius.circular(r * 0.4)),
      );
    _k.blob(c, body, color, Color.lerp(color, const Color(0xFF1A1424), 0.5)!, gloss: false, line: 0.6);
  }

  void _head(Canvas c, SpriteDraw sprites, Offset at, double r, String id) {
    final circle = Path()..addOval(Rect.fromCircle(center: at, radius: r));
    _k.fill.color = const Color(0xFFFFF4E6);
    c
      ..drawPath(circle, _k.fill)
      ..save()
      ..clipPath(circle);
    sprites.drawSmooth(c, 'portrait:$id', at.dx, at.dy + r * 0.15, r * 2.6, r * 2.6);
    c
      ..restore()
      ..drawPath(circle, _k.ink);
  }

  /// 계열 무기: 대포류(투척·집속·직사·고리)는 짧은 포신, 관통은 창, 레이저·번개는 지팡이, 돌격은 칼(쏠 때 휘두름),
  /// 수중은 물방울 구슬, 물수제비는 원반, 공중은 깃발.
  void _weapon(Canvas c, Offset at, double r, String fam, double shot, double now, int i) {
    final hand = at + Offset(r * 0.8, -r * 0.1);
    _line
      ..strokeWidth = r * 0.35
      ..color = HdKit.inkColor;
    switch (fam) {
      case 'assault':
        final swing = shot > 0 ? (1 - shot) * 2.4 - 1.2 : -0.6;
        final tip = hand + Offset(math.sin(swing), -math.cos(swing)) * r * 1.6;
        c.drawLine(hand, tip, _line);
        _line
          ..strokeWidth = r * 0.2
          ..color = const Color(0xFFE8F0FA);
        c.drawLine(hand, tip, _line);
        if (shot > 0) {
          _line
            ..strokeWidth = r * 0.12
            ..color = Color.fromRGBO(255, 255, 255, shot);
          c.drawArc(Rect.fromCircle(center: hand, radius: r * 1.6), -math.pi / 2 - 1.2, 2.4, false, _line);
        }
      case 'pierce':
        final tip = hand + Offset(0, -r * 1.9);
        c.drawLine(hand + Offset(0, r * 0.4), tip, _line);
        _line
          ..strokeWidth = r * 0.16
          ..color = const Color(0xFFD8C090);
        c.drawLine(hand + Offset(0, r * 0.4), tip, _line);
        _k.fill.color = const Color(0xFFE8F0FA);
        c.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy - r * 0.45)
            ..lineTo(tip.dx + r * 0.2, tip.dy)
            ..lineTo(tip.dx - r * 0.2, tip.dy)
            ..close(),
          _k.fill,
        );
      case 'laser' || 'shock':
        final top = hand + Offset(0, -r * 1.4);
        c.drawLine(hand + Offset(0, r * 0.3), top, _line);
        _line
          ..strokeWidth = r * 0.15
          ..color = const Color(0xFF8A5A30);
        c.drawLine(hand + Offset(0, r * 0.3), top, _line);
        final glow = 0.5 + 0.5 * math.sin(now / 150 + i) + shot;
        _k.fill.color = Color(
          fam == 'shock' ? 0xFFFFE04A : 0xFFFF6FB5,
        ).withValues(alpha: (0.5 + 0.5 * glow).clamp(0, 1));
        c.drawCircle(top, r * 0.32, _k.fill);
      case 'underwater' || 'skip':
        _k.fill.color = Color(fam == 'skip' ? 0xFF8AE8E0 : 0xFF8AD0FF);
        final p = hand + Offset(0, -r * 0.3);
        if (fam == 'skip') {
          c.drawOval(Rect.fromCenter(center: p, width: r * 0.9, height: r * 0.45), _k.fill);
        } else {
          c.drawCircle(p, r * 0.35, _k.fill);
        }
        c.drawCircle(p, r * 0.35, _k.ink);
      case 'air':
        c.drawLine(hand + Offset(0, r * 0.3), hand + Offset(0, -r * 1.3), _line);
        _k.fill.color = const Color(0xFFFFFFFF);
        c.drawPath(
          Path()
            ..moveTo(hand.dx, hand.dy - r * 1.3)
            ..lineTo(hand.dx + r * 0.8, hand.dy - r * 1.05 + math.sin(now / 120 + i) * r * 0.1)
            ..lineTo(hand.dx, hand.dy - r * 0.8)
            ..close(),
          _k.fill,
        );
      default: // 대포류: 짧은 포신(쏠 때 포구 연기)
        final muzzle = hand + Offset(r * 0.2, -r * 0.9);
        c.drawLine(hand, muzzle, _line);
        _line
          ..strokeWidth = r * 0.22
          ..color = const Color(0xFF4A4458);
        c.drawLine(hand, muzzle, _line);
        if (shot > 0) {
          _k.fill.color = Color.fromRGBO(255, 230, 160, shot);
          c.drawCircle(muzzle + Offset(0, -r * 0.2), r * 0.45 * (1.4 - shot * 0.4), _k.fill);
        }
    }
  }

  /// 필살기: 두 팔을 번쩍.
  void _arms(Canvas c, Offset at, double r) {
    _line
      ..strokeWidth = r * 0.28
      ..color = HdKit.inkColor;
    for (final s in const [-1.0, 1.0]) {
      c.drawLine(at + Offset(s * r * 0.55, -r * 0.2), at + Offset(s * r * 0.9, -r * 1.3), _line);
    }
  }

  /// 외침 말풍선 '!'(필살기 선장) — 처음 튀어나오고 끝에 옅어짐.
  void _shout(Canvas c, Offset at, double r, double t) {
    final pop = t < 0.15 ? 0.6 + 0.4 * t / 0.15 : 1.0;
    final a = t > 0.8 ? (1 - t) / 0.2 : 1.0;
    final s = r * 0.9 * pop;
    final bubble = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: s * 1.6, height: s * 1.4), Radius.circular(s * 0.5)),
      )
      ..moveTo(at.dx - s * 0.4, at.dy + s * 0.6)
      ..lineTo(at.dx - s * 0.75, at.dy + s * 1.05)
      ..lineTo(at.dx - s * 0.05, at.dy + s * 0.65)
      ..close();
    _k.fill.color = Color.fromRGBO(255, 255, 255, a);
    c.drawPath(bubble, _k.fill);
    _line
      ..strokeWidth = r * 0.12
      ..color = HdKit.inkColor.withValues(alpha: a);
    c.drawPath(bubble, _line);
    _k.fill.color = Color.fromRGBO(232, 64, 58, a);
    c
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at - Offset(0, s * 0.12), width: s * 0.22, height: s * 0.6),
          Radius.circular(s * 0.1),
        ),
        _k.fill,
      )
      ..drawCircle(at + Offset(0, s * 0.38), s * 0.12, _k.fill);
  }
}
