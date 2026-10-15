import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pirate_dot/proto/proto_sim.dart';
import 'package:pirate_dot/proto/proto_sprites.dart';

abstract final class _Colors {
  static const sea = Color(0xFF2F8CD8);
  static const seaDeep = Color(0xFF2778BC);
  static const wave = Color(0xFF7EC4F0);
  static const foam = Color(0xFFE8F4FC);
  static const blast = Color(0xFFFF7A2F);
  static const blastCore = Color(0xFFFFE14D);
  static const beam = Color(0xFFC9F0FF);
  static const ring = Color(0xFFFFFFFF);
}

class ProtoPainter extends CustomPainter {
  ProtoPainter(this.sim, this.atlas, {required this.scale, required Listenable repaint}) : super(repaint: repaint);

  final ProtoSim sim;
  final ProtoAtlas atlas;

  /// 논리 도트 1개 = [scale] 논리 픽셀(물리 픽셀로는 정수).
  final double scale;

  final _pixel = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  /// 스프라이트 전용(불투명 고정) — drawAtlas는 paint 색의 알파를 그림에 곱하므로 색을 바꿔 쓰는 [_pixel]과 나눈다.
  final _sprite = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..color = const Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(scale);
    final vw = size.width / scale;
    final vh = size.height / scale;
    // 세계 → 화면: 카메라가 가운데. 정수 도트로 맞춰 도트가 흔들리지 않게.
    final ox = (vw / 2 - sim.camX).roundToDouble();
    final oy = (vh / 2 - sim.camY).roundToDouble();
    _sea(canvas, vw, vh, ox, oy);
    canvas.translate(ox, oy);
    _wake(canvas);
    _sprites(canvas);
    _effects(canvas);
    _numbers(canvas);
    canvas.restore();
  }

  void _sea(Canvas canvas, double vw, double vh, double ox, double oy) {
    canvas.drawRect(Rect.fromLTWH(0, 0, vw, vh), _pixel..color = _Colors.sea);
    // 깊은 물 얼룩과 물결 점선 — 세계 좌표 격자라 배가 나아가면 아래로 흘러간다.
    const cell = 24;
    final x0 = ((-ox) / cell).floor() - 1;
    final y0 = ((-oy) / cell).floor() - 1;
    for (var cy = y0; cy < y0 + vh / cell + 3; cy++) {
      for (var cx = x0; cx < x0 + vw / cell + 3; cx++) {
        final h = _hash(cx, cy);
        final px = cx * cell + (h % 17) + ox;
        final py = cy * cell + ((h >> 5) % 17) + oy;
        if (h % 5 == 0) {
          canvas.drawRect(Rect.fromLTWH(px.roundToDouble(), py.roundToDouble(), 9, 5), _pixel..color = _Colors.seaDeep);
        }
        final len = 3 + (h >> 9) % 4;
        canvas.drawRect(
          Rect.fromLTWH(px.roundToDouble(), (py + 8).roundToDouble(), len.toDouble(), 1),
          _pixel..color = _Colors.wave,
        );
      }
    }
  }

  static int _hash(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7FFFFFFF;
  }

  void _wake(Canvas canvas) {
    // 배 뒤 흰 물보라 몇 점(진행 반대 방향)
    final s = sim.ship;
    final back = s.angle + math.pi / 2;
    for (var i = 1; i <= 5; i++) {
      final d = 9.0 + i * 4;
      final wob = math.sin(sim.time * 8 + i) * i * 0.6;
      final x = s.x + math.cos(back) * d + math.cos(back + math.pi / 2) * wob;
      final y = s.y + math.sin(back) * d + math.sin(back + math.pi / 2) * wob;
      canvas.drawRect(
        Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), 2, 1),
        _pixel..color = _Colors.foam.withValues(alpha: 1 - i / 6),
      );
    }
  }

  void _sprites(Canvas canvas) {
    final xf = <RSTransform>[];
    final src = <Rect>[];
    final flashXf = <RSTransform>[];
    final flashSrc = <Rect>[];
    void add(String id, double x, double y, {double angle = 0, bool flash = false}) {
      final r = atlas.rect(flash ? '${id}_w' : id);
      final t = RSTransform.fromComponents(
        rotation: angle,
        scale: 1,
        anchorX: r.width / 2,
        anchorY: r.height / 2,
        translateX: x.roundToDouble(),
        translateY: y.roundToDouble(),
      );
      (flash ? flashXf : xf).add(t);
      (flash ? flashSrc : src).add(r);
    }

    for (final c in sim.coins) {
      add('coin', c.x, c.y);
    }
    for (final e in sim.enemies) {
      switch (e.kind) {
        case EnemyKind.crab:
          add('crab', e.x, e.y, flash: e.flash > 0);
        case EnemyKind.jelly:
          add('jelly', e.x, e.y, flash: e.flash > 0);
        case EnemyKind.fish:
          add('fish', e.x, e.y, angle: e.face + math.pi / 2, flash: e.flash > 0);
      }
    }
    add('ship', sim.ship.x, sim.ship.y, angle: sim.ship.angle, flash: sim.ship.flash > 0);
    canvas.drawAtlas(atlas.image, xf, src, null, null, null, _sprite);
    if (flashXf.isNotEmpty) canvas.drawAtlas(atlas.image, flashXf, flashSrc, null, null, null, _sprite);
    // 투척 포탄(그림자 + 포탄)
    for (final s in sim.shots) {
      final (x, y) = s.pos();
      final u = (s.t / s.flight).clamp(0.0, 1.0);
      final gx = s.sx + (s.tx - s.sx) * u;
      final gy = s.sy + (s.ty - s.sy) * u;
      canvas
        ..drawRect(
          Rect.fromLTWH(gx.roundToDouble() - 1, gy.roundToDouble(), 3, 1),
          _pixel..color = const Color(0x55000000),
        )
        ..drawRect(
          Rect.fromLTWH(x.roundToDouble() - 1, y.roundToDouble() - 1, 3, 3),
          _pixel..color = const Color(0xFF1B1726),
        );
    }
  }

  void _effects(Canvas canvas) {
    for (final f in sim.fx) {
      final u = f.u;
      switch (f.kind) {
        case FxKind.blast:
          // 0~15%: 흰 섬광 → 노랑 중심 + 주황 고리가 퍼지며 사라짐. 반지름은 도트 단위로 끊어서(부드러운 원 대신 계단).
          final r = (f.size * (0.35 + 0.65 * u)).roundToDouble();
          if (u < 0.15) {
            canvas.drawCircle(Offset(f.x, f.y), r, _pixel..color = const Color(0xFFFFFFFF));
          } else {
            final ring = Paint()
              ..isAntiAlias = false
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = _Colors.blast.withValues(alpha: 1 - u);
            canvas
              ..drawCircle(Offset(f.x, f.y), r, ring)
              ..drawCircle(Offset(f.x, f.y), (r * (1 - u) * 0.6).roundToDouble(), _pixel..color = _Colors.blastCore);
          }
        case FxKind.beam:
          canvas
            ..save()
            ..translate(f.x, f.y)
            ..rotate(f.angle)
            ..drawRect(Rect.fromLTWH(0, -2, f.size, 4), _pixel..color = _Colors.beam.withValues(alpha: 1 - u))
            ..drawRect(
              Rect.fromLTWH(0, -0.5, f.size, 1),
              _pixel..color = const Color(0xFFFFFFFF).withValues(alpha: 1 - u),
            )
            ..restore();
        case FxKind.ring:
          final p = Paint()
            ..isAntiAlias = false
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _Colors.ring.withValues(alpha: 1 - u);
          canvas.drawCircle(Offset(f.x, f.y), (f.size * (0.3 + 0.7 * u)).roundToDouble(), p);
        case FxKind.pop:
          final d = (f.size * u).roundToDouble();
          final c = _Colors.foam.withValues(alpha: 1 - u);
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3;
            canvas.drawRect(
              Rect.fromLTWH((f.x + math.cos(a) * d).roundToDouble(), (f.y + math.sin(a) * d).roundToDouble(), 1, 1),
              _pixel..color = c,
            );
          }
      }
    }
  }

  void _numbers(Canvas canvas) {
    final xf = <RSTransform>[];
    final src = <Rect>[];
    for (final n in sim.numbers) {
      final text = n.value.toString();
      var x = n.x - text.length * 2.5;
      for (final ch in text.codeUnits) {
        final r = atlas.rect('d${ch - 48}');
        xf.add(
          RSTransform.fromComponents(
            rotation: 0,
            scale: 1,
            anchorX: 0,
            anchorY: 0,
            translateX: x.roundToDouble(),
            translateY: n.y.roundToDouble(),
          ),
        );
        src.add(r);
        x += 4;
      }
    }
    if (xf.isNotEmpty) canvas.drawAtlas(atlas.image, xf, src, null, null, null, _sprite);
  }

  @override
  bool shouldRepaint(covariant ProtoPainter old) => false;
}
