import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show LinearGradient;
import 'package:pirate_dot/render/paint/sprite_draw.dart';

/// 피버 첫 일격 (사용자 결정 2026-10-17 — 궁극기 대신 피버가 시작되는 순간의 한 방, UltimateCast):
/// 화면: 선장 초상이 금빛 비스듬한 띠와 함께 왼쪽에서 확 들어와 0.5초 머물고 오른쪽으로 빠진다.
/// 전장: 0.25초 뒤 배에서 거대한 금빛 충격파 + 가까운 적 최대 12마리에 금빛 번개가 차례로 내리꽂힌다(맞은 자리 불꽃).
class TopFeverStrike {
  double _at = -1000000000;
  String? _captain;
  Offset _ship = Offset.zero;
  final List<Offset> _targets = [];

  final _fill = Paint()..isAntiAlias = false;
  final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = false;
  final _bolt = Path();

  static const _cutInMs = 900.0;
  static const _strikeAtMs = 250.0;
  static const _gapMs = 35.0;
  static const _boltMs = 260.0;
  static const _maxTargets = 12;

  /// 첫 일격 시작: 선장 [captain], 배 [ship], 맞을 적 자리 [targets](가까운 순).
  void start(double now, String? captain, Offset ship, Iterable<Offset> targets) {
    _at = now;
    _captain = captain;
    _ship = ship;
    _targets
      ..clear()
      ..addAll(targets.take(_maxTargets));
  }

  bool active(double now) => now - _at < _strikeAtMs + _maxTargets * _gapMs + _boltMs + 400;

  void clear() {
    _at = -1000000000;
    _targets.clear();
  }

  /// 전장 좌표(적 위 층): 충격파·번개·불꽃.
  void paintWorld(Canvas c, double now, {required bool lite}) {
    final age = now - _at - _strikeAtMs;
    if (age < 0 || !active(now)) return;
    // 충격파: 두꺼운 금빛 고리 + 흰 안쪽 고리
    const ringMs = 560.0;
    if (age < ringMs) {
      final t = age / ringMs;
      final e = 1 - (1 - t) * (1 - t);
      _line
        ..strokeWidth = 7 * (1 - t) + 1
        ..color = Color.fromRGBO(255, 200, 60, 0.9 * (1 - t));
      c.drawCircle(_ship, 20 + 150 * e, _line);
      _line
        ..strokeWidth = 2
        ..color = Color.fromRGBO(255, 255, 230, 0.8 * (1 - t));
      c.drawCircle(_ship, 14 + 120 * e, _line);
    }
    for (var i = 0; i < _targets.length; i++) {
      if (lite && i.isOdd) continue;
      final t = (age - i * _gapMs) / _boltMs;
      if (t < 0 || t >= 1) continue;
      final to = _targets[i];
      // 번개: 위에서 적으로 지그재그(결정론 — 번호로 꺾임)
      final from = to + Offset(((i * 37) % 21 - 10).toDouble(), -70);
      _bolt
        ..reset()
        ..moveTo(from.dx, from.dy);
      for (var k = 1; k <= 5; k++) {
        final p = Offset.lerp(from, to, k / 5)!;
        _bolt.lineTo(p.dx + (k == 5 ? 0 : ((i * 13 + k * 7) % 9 - 4).toDouble()), p.dy);
      }
      final fade = 1 - t;
      _line
        ..strokeWidth = 6 * fade + 2
        ..color = Color.fromRGBO(255, 214, 70, fade);
      c.drawPath(_bolt, _line);
      _line
        ..strokeWidth = 2.5
        ..color = Color.fromRGBO(255, 255, 240, fade);
      c.drawPath(_bolt, _line);
      // 맞은 자리: 노란 불꽃 원 + 튀는 점
      _fill.color = Color.fromRGBO(255, 170, 40, 0.9 * fade);
      c.drawCircle(to, 9 * (0.5 + t), _fill);
      _fill.color = Color.fromRGBO(255, 245, 180, fade);
      c.drawCircle(to, 4 * (1 - t * 0.5), _fill);
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3 + i;
        final d = 6 + 14 * t;
        c.drawRect(Rect.fromLTWH(to.dx + math.cos(a) * d, to.dy + math.sin(a) * d, 2, 2), _fill);
      }
    }
  }

  /// 화면 좌표: 선장 초상 컷인(금빛 비스듬한 띠). 초상이 없으면 띠만.
  void paintScreen(Canvas c, Size box, double now, SpriteDraw? sprites) {
    final age = now - _at;
    if (age < 0 || age >= _cutInMs) return;
    final t = age / _cutInMs;
    // 들어옴 0~0.18 · 머묾 · 빠짐 0.8~1
    final slide = t < 0.18 ? 1 - _easeOut(t / 0.18) : (t > 0.8 ? -_easeIn((t - 0.8) / 0.2) : 0.0);
    final h = box.height * 0.2;
    final cy = box.height * 0.36;
    final dx = slide * box.width;
    c
      ..save()
      ..translate(dx, 0);
    final band = Path()
      ..moveTo(0, cy - h / 2 + 18)
      ..lineTo(box.width, cy - h / 2 - 18)
      ..lineTo(box.width, cy + h / 2 - 18)
      ..lineTo(0, cy + h / 2 + 18)
      ..close();
    _fill.color = const Color(0xE61B2A4A);
    c.drawPath(band, _fill);
    _line
      ..strokeWidth = 3
      ..color = const Color(0xFFFFC23A);
    c
      ..drawLine(Offset(0, cy - h / 2 + 18), Offset(box.width, cy - h / 2 - 18), _line)
      ..drawLine(Offset(0, cy + h / 2 + 18), Offset(box.width, cy + h / 2 - 18), _line);
    // 띠 안 속도선
    _fill.color = const Color(0x55FFE9A8);
    for (var k = 0; k < 7; k++) {
      final y = cy - h / 2 + 10 + k * h / 7;
      final x = ((age * 1.4 + k * 97) % (box.width + 80)) - 80;
      c.drawRect(Rect.fromLTWH(box.width - x, y, 60, 2), _fill);
    }
    final id = _captain;
    if (id != null && sprites != null) {
      // 띠 안으로만(초상 그림의 네모 바탕이 띠 밖으로 나오지 않게), 얼굴이 띠를 꽉 채우게 크게.
      final s = h * 1.35;
      c
        ..save()
        ..clipPath(band);
      final px = box.width * 0.28;
      sprites.drawSmooth(c, 'portrait:$id', px, cy + h * 0.1, s, s);
      // 초상 오른쪽 끝을 띠 색으로 녹인다(네모 경계가 보이지 않게).
      final fade = Rect.fromLTWH(px + s * 0.15, cy - h, s * 0.36, h * 2);
      _fill.shader = const LinearGradient(colors: [Color(0x001B2A4A), Color(0xFF1B2A4A)]).createShader(fade);
      c.drawRect(fade, _fill);
      _fill.shader = null;
      c.restore();
      _line
        ..strokeWidth = 3
        ..color = const Color(0xFFFFC23A);
      c
        ..drawLine(Offset(0, cy - h / 2 + 18), Offset(box.width, cy - h / 2 - 18), _line)
        ..drawLine(Offset(0, cy + h / 2 + 18), Offset(box.width, cy + h / 2 - 18), _line);
    }
    c.restore();
  }

  static double _easeOut(double t) => 1 - (1 - t) * (1 - t) * (1 - t);
  static double _easeIn(double t) => t * t * t;
}
