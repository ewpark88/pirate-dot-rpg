import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';

/// 바다 팔레트: 해역 [id]가 fx_map `topSea.regions`에 있으면 그 색, 없으면(또는 null) 기본 `topSea` 색.
({Color base, Color deep, Color shallow, Color wave}) seaPalette(JsonReader cfg, String? id) {
  final r = id != null && cfg.has('regions') && cfg.obj('regions').has(id) ? cfg.obj('regions').obj(id) : cfg;
  Color col(String k) => Color(parseArgb(r.has(k) ? r.str(k) : cfg.str(k), 'topSea.$id.$k'));
  return (base: col('base'), deep: col('deep'), shallow: col('shallow'), wave: col('wave'));
}

/// 바다 위를 흘러가는 소품(디자인 개편 ③ 배경 — 쿵푸할매 서바이버 톤: 굵은 검정 외곽선·광택, 어두운 바다 위에서 또렷하게).
/// 해역별 세트(fx_map `topSea.props.sets`)에서 고른 바위·산호·부표·해초·난파 판자·얼음·용암 바위·통이 바다 흐름과 같이
/// 뒤로 지나간다. 전투 시야를 덜 가리게 화면 가운데(배 길) 밖 양옆에만, 한 화면 3~6개(행 간격 `spacing`).
/// 자리·종류는 흐른 거리로 정해지는 결정론(같은 장면 시계면 같은 그림). 종류마다 Picture를 한 번 만들어 두고
/// 그 뒤로는 옮기기·돌리기·drawPicture만(소품 하나 = 그리기 1번, 상한 `maxOnScreen`).
/// 좌표: TopSeaPainter와 같은 보이는 영역 단위(배 화면 자리 원점).
class TopSeaProps {
  TopSeaProps(this.cfg);

  /// fx_map `topSea`에 `props`가 없으면 null(소품 없음).
  static TopSeaProps? of(JsonReader topSea) => topSea.has('props') ? TopSeaProps(topSea.obj('props')) : null;

  final JsonReader cfg;
  late final double _spacing = cfg.number('spacing');
  late final int _max = cfg.integer('maxOnScreen');
  late final double _lane = cfg.number('laneHalf');
  late final double _size = cfg.number('size');

  /// 소품이 바다 무늬보다 빨리 흐르는 배수(가까운 물체 — 배 속도감, S1).
  late final double _flowMul = cfg.numberOr('flowMul', 1);
  late final JsonReader _sets = cfg.obj('sets');
  final Map<String, Picture> _pictures = {};

  /// 이번 프레임에 그린 소품 수(테스트·측정).
  int drawn = 0;

  /// 해역 id(regions.json)의 세트. 없으면 coral 세트.
  List<String> _kinds(String region) => _sets.has(region) ? _sets.strs(region) : _sets.strs('coral');

  static int _hash(int a, int b) {
    var h = a * 374761393 + b * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7FFFFFFF;
  }

  /// [seaFlowY] = 바다가 흐른 거리(아래로 쌓임), [view] = 보이는 영역(단위), [region] = 해역 id.
  void paint(Canvas c, Rect view, double seaFlowY, String region, {double alpha = 1}) {
    drawn = 0;
    if (alpha <= 0.02) return;
    final flowY = seaFlowY * _flowMul;
    final kinds = _kinds(region);
    final margin = _size * 2;
    // 행 k의 바다 자리 y = -k·spacing, 화면 y = 바다 y + flowY.
    final first = ((flowY - view.bottom - margin) / _spacing).ceil();
    final last = ((flowY - view.top + margin) / _spacing).floor();
    final halfW = view.width / 2;
    for (var k = first; k <= last && drawn < _max; k++) {
      final h = _hash(k, 7);
      if (h % 5 == 0) continue; // 가끔 빈 행 — 줄 맞춘 티가 안 나게
      final side = h.isEven ? 1.0 : -1.0;
      // 배 길(가운데 ±laneHalf) 밖, 화면 가장자리 쪽으로.
      final reach = math.max(_lane + _size, halfW - _size * 0.6);
      final x = view.center.dx + side * (_lane + _size + ((h >> 3) % 1000) / 1000 * (reach - _lane - _size));
      final y = -k * _spacing + flowY + ((h >> 13) % 100 - 50) / 100 * _spacing * 0.4;
      final kind = kinds[(h >> 7) % kinds.length];
      // 크기 차이는 ±10%만 — 외곽선 두께가 소품마다 들쭉날쭉하지 않게(S1).
      final scale = 0.9 + ((h >> 17) % 20) / 100;
      final turn = ((h >> 11) % 628) / 100;
      c
        ..save()
        ..translate(x, y)
        ..rotate(kind == 'buoy' || kind == 'barrel' ? turn * 0.15 : turn)
        ..scale(scale * _size / _unit);
      if (alpha < 1) {
        c
          ..saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha))
          ..drawPicture(_picture(kind))
          ..restore();
      } else {
        c.drawPicture(_picture(kind));
      }
      c.restore();
      drawn++;
    }
  }

  /// 그림 한 변(그리기 단위) — [_size]로 줄여 쓴다.
  static const double _unit = 40;
  static const _ink = Color(0xFF1B1626);

  Picture _picture(String kind) => _pictures[kind] ??= () {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    _draw(c, kind);
    return rec.endRecording();
  }();

  /// 외곽선(굵은 검정) → 위 밝음/아래 진함 → 흰 광택 순서. 원점 가운데, 한 변 약 [_unit].
  static void _draw(Canvas c, String kind) {
    final ol = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = _ink;
    Paint fill(Color top, Color bottom, Rect r) =>
        Paint()..shader = Gradient.linear(r.topCenter, r.bottomCenter, [top, bottom]);
    void shine(Offset at, double rx, double ry) => c.drawOval(
      Rect.fromCenter(center: at, width: rx * 2, height: ry * 2),
      Paint()..color = const Color(0xA0FFFFFF),
    );
    void body(Path p, Color top, Color bottom) {
      c
        ..drawPath(p, fill(top, bottom, p.getBounds()))
        ..drawPath(p, ol);
    }

    switch (kind) {
      case 'rock' || 'lavaRock' || 'ice':
        final p = Path()
          ..moveTo(-16, 6)
          ..lineTo(-12, -8)
          ..lineTo(-2, -15)
          ..lineTo(11, -11)
          ..lineTo(17, 2)
          ..lineTo(10, 13)
          ..lineTo(-6, 15)
          ..close();
        final (top, bottom) = switch (kind) {
          'ice' => (const Color(0xFFF2FBFF), const Color(0xFF8CC8EE)),
          'lavaRock' => (const Color(0xFF5A4A5E), const Color(0xFF231A2A)),
          _ => (const Color(0xFFA8B0C2), const Color(0xFF4E566A)),
        };
        body(p, top, bottom);
        if (kind == 'lavaRock') {
          c.drawPath(
            Path()
              ..moveTo(-8, -4)
              ..lineTo(-1, 2)
              ..lineTo(6, -2)
              ..moveTo(-1, 2)
              ..lineTo(1, 10),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFFFF8A2A),
          );
        }
        shine(const Offset(-6, -8), 4, 2);
      case 'coral':
        final branch = Path()
          ..moveTo(0, 14)
          ..lineTo(0, -2)
          ..moveTo(0, 4)
          ..quadraticBezierTo(-10, 2, -11, -10)
          ..moveTo(0, 0)
          ..quadraticBezierTo(9, -2, 10, -13)
          ..moveTo(0, -2)
          ..lineTo(-1, -14)
          ..moveTo(-6, -1)
          ..lineTo(-15, -4)
          ..moveTo(6, -6)
          ..lineTo(14, -3);
        c
          ..drawPath(branch, ol..strokeWidth = 8)
          ..drawPath(
            branch,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.2
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFFFF6F91),
          )
          ..drawPath(
            branch,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFFFFC2D2),
          );
        ol.strokeWidth = 3.2;
      case 'seaweed':
        final strand = Path();
        for (final dx in const [-8.0, 0.0, 8.0]) {
          strand
            ..moveTo(dx, 15)
            ..cubicTo(dx - 7, 6, dx + 7, -4, dx - 2, -15);
        }
        c
          ..drawPath(strand, ol..strokeWidth = 7.5)
          ..drawPath(
            strand,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.8
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFF3FC46A),
          );
        ol.strokeWidth = 3.2;
      case 'buoy':
        const r = Rect.fromLTRB(-11, -11, 11, 11);
        c
          ..drawOval(r, fill(const Color(0xFFFF6B5A), const Color(0xFFC0182E), r))
          ..drawArc(r, -math.pi / 4, math.pi / 2, true, Paint()..color = const Color(0xFFF7F3EA))
          ..drawArc(r, math.pi * 3 / 4, math.pi / 2, true, Paint()..color = const Color(0xFFF7F3EA))
          ..drawOval(r, ol)
          ..drawCircle(Offset.zero, 4, Paint()..color = const Color(0xFFFFD34A))
          ..drawCircle(Offset.zero, 4, ol..strokeWidth = 2.4);
        ol.strokeWidth = 3.2;
        shine(const Offset(-5, -6), 3.5, 2);
      case 'barrel':
        const r = Rect.fromLTRB(-9, -13, 9, 13);
        final p = Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)));
        body(p, const Color(0xFFD9A35A), const Color(0xFF7A4318));
        final hoop = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFF3A2A20);
        c
          ..drawLine(const Offset(-9, -5), const Offset(9, -5), hoop)
          ..drawLine(const Offset(-9, 5), const Offset(9, 5), hoop);
        shine(const Offset(-4, -9), 2.5, 1.6);
      default: // plank — 난파 판자
        final p = Path()
          ..moveTo(-17, -6)
          ..lineTo(15, -9)
          ..lineTo(18, -1)
          ..lineTo(14, 7)
          ..lineTo(-16, 8)
          ..close();
        body(p, const Color(0xFFC9843F), const Color(0xFF6E3B14));
        final seam = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF4A2810);
        c
          ..drawLine(const Offset(-16, 1), const Offset(16, -1), seam)
          ..drawCircle(const Offset(-11, -3), 1.3, Paint()..color = _ink)
          ..drawCircle(const Offset(10, 4), 1.3, Paint()..color = _ink);
        shine(const Offset(-6, -5), 5, 1.4);
    }
  }
}
