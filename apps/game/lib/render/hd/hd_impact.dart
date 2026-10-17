import 'dart:math' as math;
import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_kit.dart';

part 'hd_impact_shapes.dart';

/// 계열별 HD 착탄(사용자 '폭탄 임팩트가 겹치는 것들이 많은데 연출을 다 다르게'): 계열 11종이 서로 다른 모양,
/// 등급(0~5)이 오를수록 크고 진하게(신화 = 무지개 테), 같은 화면에 겹치면 자리마다 회전·크기를 조금씩 흔든다.
/// HD 결 — 굵은 외곽선·광택 덩어리. 전장 좌표, 반지름 = 엔진 범위.
///   lob 폭발 링+불꽃 꽃잎+연기 · ring 회전 고리 2겹+룬 · cluster 작은 펑 여러 개 · direct 작은 별 연속 · pierce 창끝 섬광 줄
///   laser 지지는 열 원판+열기 · skip 물수제비 잔물결 · underwater 물기둥·거품 · air 지그재그 갈래 번개 · assault 베기 X
///   shock 두꺼운 충격파+땅 금
class HdImpact {
  final _k = HdKit();
  final List<_Hit> _hits = [];
  final _stroke = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static const _lifeMs = 520.0;
  static const _upright = {'underwater', 'laser', 'skip'};
  static const _max = 14;

  static const families = [
    'lob', 'ring', 'cluster', 'direct', 'pierce', 'laser', 'skip', 'underwater', 'air', 'assault', 'shock', //
  ];

  void add(String family, double x, double y, double radius, int color, int rarity, double atMs) {
    if (_hits.length >= _max) _hits.removeAt(0);
    // 같은 자리 겹침 흔들기: 자리 해시로 회전 0~2π·크기 0.85~1.15
    final h = ((x * 73.1).floor() ^ (y * 31.7).floor() ^ atMs.floor()) & 0xFFFF;
    _hits.add(
      _Hit(family, Offset(x, y), radius, Color(color), rarity, atMs, h / 0xFFFF * 2 * math.pi, 0.85 + (h % 31) / 100),
    );
  }

  bool get active => _hits.isNotEmpty;

  void clear() => _hits.clear();

  void paint(Canvas c, double now, {required bool lite}) {
    _hits.removeWhere((h) => now - h.at >= _lifeMs || now < h.at - 2000);
    for (final h in _hits) {
      final age = now - h.at;
      if (age < 0) continue;
      final t = age / _lifeMs;
      final r = h.radius * h.jitter * (0.8 + 0.08 * h.rarity);
      _k.ink.strokeWidth = math.max<double>(1, r * 0.07);
      c
        ..save()
        ..translate(h.pos.dx, h.pos.dy)
        ..rotate(_upright.contains(h.family) ? 0 : h.spin); // 물기둥·열기·물수제비는 늘 위로
      switch (h.family) {
        case 'ring':
          _ring(c, h, r, t);
        case 'cluster':
          _cluster(c, h, r, t);
        case 'direct':
          _direct(c, h, r, t);
        case 'pierce':
          _pierce(c, h, r, t);
        case 'laser':
          _laser(c, h, r, t);
        case 'skip':
          _skip(c, h, r, t);
        case 'underwater':
          _water(c, h, r, t, lite: lite);
        case 'air':
          _air(c, h, r, t);
        case 'assault':
          _assault(c, h, r, t);
        case 'shock':
          _shock(c, h, r, t);
        default:
          _lob(c, h, r, t, lite: lite);
      }
      if (h.rarity >= 5) _rainbowRim(c, r, t);
      c.restore();
    }
  }
}

class _Hit {
  _Hit(this.family, this.pos, this.radius, this.color, this.rarity, this.at, this.spin, this.jitter);
  final String family;
  final Offset pos;
  final double radius;
  final Color color;
  final int rarity;
  final double at;
  final double spin;
  final double jitter;
}
