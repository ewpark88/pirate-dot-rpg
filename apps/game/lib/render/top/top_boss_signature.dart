import 'dart:math' as math;
import 'dart:ui';

part 'top_boss_signature_shapes.dart';

/// 새 보스 18종의 '보이는 개성'(S1): 특성·패턴은 공용을 재사용하므로, 특성이 발동할 때(반사막·가속·분노·호위 발동,
/// 장갑 '팅', 회피, 재생) 그 보스만의 표식을 공용 특성 연출 위에 0.9초 얹는다. 전장 좌표, r = 보스 반지름.
/// 산호 골렘 갑옷판 빛 · 흰동가리 왕 호위 소용돌이 · 진주 조개 반사 진주 막 · 폭풍 독수리 깃털 회오리 · 구름 고래 비구름 ·
/// 천둥 게 번개 · 빙하 예티 서리 숨결 · 얼음 일각고래 얼음 조각 · 눈올빼미 배 눈송이 고리 · 마그마 골렘 용암 균열 ·
/// 불도롱뇽 불꽃 혀 · 잿빛 용 재 소용돌이 · 심연의 눈 동공 고리 · 초롱 장어 초롱불 · 뼈 상어 이빨 고리 ·
/// 밴시 여왕 비명 물결 · 저주받은 종 종소리 · 유령 크라켄 유령 촉수.
class TopBossSignature {
  static const ms = 900.0;

  /// 표식이 있는 보스인가.
  static bool has(String kind) => _of.containsKey(kind);

  static const Map<String, _Sig> _of = {
    'coral_golem': _Sig.plates,
    'clown_king': _Sig.vortex,
    'pearl_clam': _Sig.pearls,
    'storm_eagle': _Sig.feathers,
    'cloud_whale': _Sig.clouds,
    'thunder_crab': _Sig.bolts,
    'frost_yeti': _Sig.breath,
    'ice_narwhal': _Sig.shards,
    'snow_owl_ship': _Sig.flakes,
    'magma_golem': _Sig.cracks,
    'fire_salamander': _Sig.flames,
    'ash_dragon': _Sig.ash,
    'abyss_eye': _Sig.eye,
    'lantern_eel': _Sig.lanterns,
    'bone_shark': _Sig.teeth,
    'banshee_queen': _Sig.waves,
    'cursed_bell': _Sig.bell,
    'ghost_kraken': _Sig.tentacles,
  };

  final _fill = Paint()..isAntiAlias = true;
  final _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _path = Path();

  /// [kind] 보스의 표식. [age] = 발동 뒤 ms(0~[ms]).
  void paint(Canvas c, String kind, Offset at, double r, double age, double now) {
    final sig = _of[kind];
    if (sig == null || age < 0 || age > ms) return;
    final t = age / ms;
    final a = t < 0.15 ? t / 0.15 : (t > 0.7 ? (1 - t) / 0.3 : 1.0); // 빠르게 켜지고 천천히 꺼짐
    double ang(int i, int n) => i * 2 * math.pi / n;
    Offset dir(double a) => Offset(math.cos(a), math.sin(a));
    switch (sig) {
      case _Sig.plates: // 갑옷판 6장이 몸 둘레에서 산호빛으로 빛남
        for (var i = 0; i < 6; i++) {
          final p = at + dir(ang(i, 6) + 0.3) * r * 0.95;
          _hex(p, r * 0.24, ang(i, 6));
          _fill.color = Color.fromRGBO(255, 140, 150, 0.55 * a);
          c.drawPath(_path, _fill);
          _line
            ..strokeWidth = r * 0.05
            ..color = Color.fromRGBO(255, 230, 220, 0.9 * a);
          c.drawPath(_path, _line);
        }
      case _Sig.vortex: // 주황·흰 줄무늬 소용돌이(호위 물고기 소환)
        _spiral(c, at, r * 1.4, now / 300, 3, const Color(0xFFFF8A2A), a, r * 0.12);
        _spiral(c, at, r * 1.4, now / 300 + 0.5, 3, const Color(0xFFFFFFFF), a, r * 0.07);
      case _Sig.pearls: // 진주 8알이 도는 무지개 막
        _line
          ..strokeWidth = r * 0.06
          ..color = Color.fromRGBO(220, 200, 255, 0.6 * a);
        c.drawCircle(at, r * 1.25, _line);
        for (var i = 0; i < 8; i++) {
          final p = at + dir(ang(i, 8) + now / 500) * r * 1.25;
          _fill.color = Color.fromRGBO(255, 250, 240, a);
          c.drawCircle(p, r * 0.13, _fill);
          _fill.color = Color.fromRGBO(255, 190, 230, 0.8 * a);
          c.drawCircle(p + Offset(-r * 0.04, -r * 0.04), r * 0.05, _fill);
        }
      case _Sig.feathers: // 깃털 회오리
        for (var i = 0; i < 8; i++) {
          final aa = ang(i, 8) + t * 5;
          _leaf(c, at + dir(aa) * r * (0.6 + 0.9 * t), aa + 1.2, r * 0.32, const Color(0xFFE8F0FF), a);
        }
      case _Sig.clouds: // 비구름 셋 + 초록 빗방울(재생)
        for (var i = 0; i < 3; i++) {
          final p = at + Offset((i - 1) * r * 0.6, -r * 1.3);
          _fill.color = Color.fromRGBO(240, 248, 255, 0.85 * a);
          c
            ..drawCircle(p, r * 0.3, _fill)
            ..drawCircle(p + Offset(r * 0.22, r * 0.05), r * 0.22, _fill);
          final dy = (now / 4 + i * 13) % (r * 0.9);
          _fill.color = Color.fromRGBO(120, 240, 150, 0.9 * a);
          c.drawOval(Rect.fromCenter(center: p + Offset(0, r * 0.3 + dy), width: r * 0.08, height: r * 0.18), _fill);
        }
      case _Sig.bolts: // 둘레에 내리꽂는 번개 셋
        final k = (now / 90).floor();
        for (var i = 0; i < 3; i++) {
          final p = at + dir(ang(i, 3) + k * 0.7) * r * 1.2;
          _zig(c, p - Offset(0, r * 1.1), p, r * 0.14, const Color(0xFFFFE04A), a);
        }
      case _Sig.breath: // 서리 숨결: 아래(배 쪽) 부채꼴 서리 입자
        for (var i = 0; i < 14; i++) {
          final u = (t * 1.6 + i / 14) % 1;
          final spread = (i % 5 - 2) * 0.18;
          final p = at + dir(math.pi / 2 + spread) * r * (0.6 + 1.6 * u);
          _fill.color = Color.fromRGBO(210, 240, 255, a * (1 - u));
          c.drawCircle(p, r * (0.08 + 0.14 * u), _fill);
        }
      case _Sig.shards: // 얼음 조각이 뒤로 흩어짐
        for (var i = 0; i < 6; i++) {
          final aa = -math.pi / 2 + (i - 2.5) * 0.35;
          final p = at + dir(aa) * r * (0.8 + 1.0 * t);
          _hex(p, r * 0.14, aa);
          _fill.color = Color.fromRGBO(190, 235, 255, 0.85 * a);
          c.drawPath(_path, _fill);
        }
      case _Sig.flakes: // 도는 눈송이 고리
        _line
          ..strokeWidth = r * 0.05
          ..color = Color.fromRGBO(255, 255, 255, 0.9 * a);
        for (var i = 0; i < 6; i++) {
          final p = at + dir(ang(i, 6) + now / 700) * r * 1.3;
          for (var j = 0; j < 3; j++) {
            final d = dir(j * math.pi / 3) * r * 0.14;
            c.drawLine(p - d, p + d, _line);
          }
        }
      case _Sig.cracks: // 용암 균열이 몸에서 뻗음
        _line.strokeWidth = r * 0.09;
        for (var i = 0; i < 7; i++) {
          final aa = ang(i, 7) + 0.2;
          final mid = at + dir(aa + 0.25) * r * 0.75;
          _line.color = Color.fromRGBO(255, 120 + i * 15, 30, a);
          c
            ..drawLine(at + dir(aa) * r * 0.4, mid, _line)
            ..drawLine(mid, at + dir(aa - 0.2) * r * (1.0 + 0.3 * t), _line);
        }
      case _Sig.flames: // 불꽃 혀 고리
        for (var i = 0; i < 8; i++) {
          final aa = ang(i, 8) + now / 600;
          final h = r * (0.35 + 0.15 * math.sin(now / 60 + i));
          final base = at + dir(aa) * r * 1.0;
          _path
            ..reset()
            ..moveTo(base.dx - r * 0.12, base.dy)
            ..quadraticBezierTo(base.dx, base.dy - h * 1.4, base.dx + r * 0.12, base.dy)
            ..close();
          _fill.color = Color.fromRGBO(255, 150, 40, 0.85 * a);
          c.drawPath(_path, _fill);
        }
      case _Sig.ash: // 재 소용돌이
        for (var i = 0; i < 10; i++) {
          final aa = ang(i, 10) + t * 4;
          _fill.color = Color.fromRGBO(110, 100, 110, 0.55 * a);
          c.drawCircle(at + dir(aa) * r * (0.8 + 0.6 * t), r * (0.16 + 0.1 * (i % 3)), _fill);
        }
      case _Sig.eye: // 커다란 보라 동공 고리 + 세로 동공
        for (var i = 0; i < 3; i++) {
          _line
            ..strokeWidth = r * 0.06
            ..color = Color.fromRGBO(190, 90, 255, a * (0.8 - i * 0.2));
          c.drawCircle(at, r * (1.15 + 0.2 * i + 0.15 * t), _line);
        }
        _fill.color = Color.fromRGBO(255, 230, 120, 0.6 * a);
        c.drawOval(Rect.fromCenter(center: at - Offset(0, r * 1.5), width: r * 0.25, height: r * 0.6), _fill);
      case _Sig.lanterns: // 춤추는 초롱불 넷
        for (var i = 0; i < 4; i++) {
          final aa = ang(i, 4) + now / 400;
          final p = at + Offset(math.cos(aa) * r * 1.3, math.sin(aa * 2) * r * 0.5 - r * 0.6);
          _fill.color = Color.fromRGBO(255, 230, 120, 0.35 * a);
          c.drawCircle(p, r * 0.3, _fill);
          _fill.color = Color.fromRGBO(255, 250, 200, a);
          c.drawCircle(p, r * 0.12, _fill);
        }
      case _Sig.teeth: // 뼈 이빨 고리
        for (var i = 0; i < 10; i++) {
          final aa = ang(i, 10) - now / 900;
          final p = at + dir(aa) * r * 1.2;
          final o = dir(aa) * r * 0.25;
          final n = Offset(-o.dy, o.dx) * 0.5;
          _path
            ..reset()
            ..moveTo(p.dx + n.dx, p.dy + n.dy)
            ..lineTo(p.dx - o.dx, p.dy - o.dy)
            ..lineTo(p.dx - n.dx, p.dy - n.dy)
            ..close();
          _fill.color = Color.fromRGBO(245, 240, 225, a);
          c.drawPath(_path, _fill);
        }
      case _Sig.waves: // 비명 물결: 퍼지는 물결 고리 셋
        for (var i = 0; i < 3; i++) {
          final u = (t * 1.5 + i / 3) % 1;
          _path.reset();
          for (var k = 0; k <= 36; k++) {
            final aa = k * math.pi / 18;
            final rr = r * (0.9 + 1.0 * u) + math.sin(aa * 8 + now / 50) * r * 0.06;
            final p = at + dir(aa) * rr;
            k == 0 ? _path.moveTo(p.dx, p.dy) : _path.lineTo(p.dx, p.dy);
          }
          _line
            ..strokeWidth = r * 0.05
            ..color = Color.fromRGBO(230, 240, 255, a * (1 - u));
          c.drawPath(_path, _line);
        }
      case _Sig.bell: // 종소리 호 + 음표 점
        for (var i = 0; i < 3; i++) {
          final u = (t * 2 + i / 3) % 1;
          _line
            ..strokeWidth = r * 0.07
            ..color = Color.fromRGBO(255, 215, 120, a * (1 - u));
          for (final s in const [-1.0, 1.0]) {
            c.drawArc(
              Rect.fromCircle(center: at, radius: r * (1 + 0.8 * u)),
              s > 0 ? -0.6 : math.pi - 0.6,
              1.2,
              false,
              _line,
            );
          }
        }
      case _Sig.tentacles: // 유령 촉수 넷이 솟음
        for (var i = 0; i < 4; i++) {
          final base = at + dir(ang(i, 4) + 0.4) * r * 1.1;
          _path
            ..reset()
            ..moveTo(base.dx, base.dy);
          for (var k = 1; k <= 6; k++) {
            final y = -k * r * 0.18 * (0.5 + t);
            _path.lineTo(base.dx + math.sin(now / 120 + k + i) * r * 0.15, base.dy + y);
          }
          _line
            ..strokeWidth = r * 0.12
            ..color = Color.fromRGBO(170, 230, 210, 0.6 * a);
          c.drawPath(_path, _line);
        }
    }
  }
}

enum _Sig {
  plates,
  vortex,
  pearls,
  feathers,
  clouds,
  bolts,
  breath,
  shards,
  flakes,
  cracks,
  flames,
  ash,
  eye,
  lanterns,
  teeth,
  waves,
  bell,
  tentacles,
}
