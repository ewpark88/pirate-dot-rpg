import 'dart:math' as math;
import 'dart:ui';

/// 선원 발사체 몸통 HD v2 (S1 '탄이 작은 점·선이라 착탄만 화려하다'): 계열마다 다른 몸통을 벡터로, 등급이 높을수록 크고 빛 무리.
/// - lob 포탄: 둥근 폭탄 + 도화선 불꽃, 돌며 날고 연기 꼬리 · cluster 집속: 이음선 폭탄이 끝 30%에서 셋으로 갈라짐
/// - ring 고리: 가시 구슬 + 도는 빛 고리 · direct 직사: 길쭉한 탄 + 흰 줄기 · pierce 관통: 진행 방향 창(금속 날 + 빛)
/// - skip 물수제비: 납작 원반(튕김은 엔진 높이) · underwater 수중: 물방울 어뢰 + 거품 · air 공중: 깃털 다트
/// - assault 돌격: 도는 칼날 · shock 번개: 노란 구슬 + 튀는 전기 · laser: 빔은 TopFamilyV3, 탄이면 분홍 빛 창.
/// 그림자·높이·회전은 부르는 쪽(PbFxPainter)이 정하고, 여기선 원점 기준 [r](반지름, 전장 단위)로 그린다.
/// 그라디언트 셰이더 없이 단색 + 하이라이트 + 먹선 — 탄이 수십 개여도 가볍게. [lite](붐빔·절전)면 연기·빛 무리를 뺀다.
class TopShotBody {
  final _fill = Paint()..isAntiAlias = true;
  final _ink = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final _path = Path();
  static const _inkColor = Color(0xFF1A1424);

  /// 등급 색(빛 무리): 일반 없음 · 희귀 파랑 · 영웅 보라 · 전설 금 · 신화 분홍.
  static const _glow = [0x00000000, 0xFF5FB4FF, 0xFFB57AFF, 0xFFFFC23A, 0xFFFF6FD8];

  /// 등급별 크기 배수.
  static double scaleOf(int rarity) => 1 + 0.14 * rarity.clamp(0, 4);

  /// 몸통이 있는 계열인가(없으면 부르는 쪽이 기존 그림).
  static bool has(String family) => _families.contains(family);
  static const _families = {
    'lob',
    'cluster',
    'ring',
    'direct',
    'pierce',
    'laser',
    'skip',
    'underwater',
    'air',
    'assault',
    'shock',
  };

  /// [at] 자리에 [family] 몸통. [heading] = 진행 방향(라디안), [spin] = 회전(도는 계열), [t] = 비행 진행 0~1, [now] = 장면 ms.
  void paint(
    Canvas c,
    String family,
    Offset at,
    double r,
    double heading,
    double spin,
    double t,
    double now,
    int rarity, {
    required bool lite,
  }) {
    _ink.strokeWidth = math.max(0.6, r * 0.22);
    if (!lite && rarity > 0) {
      final g = Color(_glow[rarity.clamp(0, 4)]);
      _fill.color = g.withValues(alpha: 0.14 + 0.03 * rarity); // 바깥 옅은 빛 + 안쪽 진한 빛(두 겹 — 납작한 원판처럼 안 보이게)
      c.drawCircle(at, r * (1.5 + 0.15 * rarity), _fill);
      _fill.color = g.withValues(alpha: 0.3);
      c.drawCircle(at, r * 1.15, _fill);
    }
    c
      ..save()
      ..translate(at.dx, at.dy);
    switch (family) {
      case 'pierce' || 'laser':
        c.rotate(heading);
        _spear(c, r, laser: family == 'laser');
      case 'direct':
        c.rotate(heading);
        _slug(c, r);
      case 'air':
        c.rotate(heading);
        _dart(c, r);
      case 'underwater':
        c.rotate(heading);
        _torpedo(c, r, now);
      case 'skip':
        c.rotate(spin * 0.25);
        _disc(c, r);
      case 'assault':
        c.rotate(spin * 2);
        _blades(c, r);
      case 'shock':
        _orb(c, r, now);
      case 'ring':
        c.rotate(spin);
        _spiky(c, r, now);
      case 'cluster':
        if (t > 0.7) {
          final k = (t - 0.7) / 0.3; // 셋으로 갈라짐
          for (var i = 0; i < 3; i++) {
            final a = heading + (i - 1) * 0.9;
            c
              ..save()
              ..translate(math.cos(a) * r * 1.6 * k, math.sin(a) * r * 1.6 * k)
              ..rotate(spin);
            _bomb(c, r * 0.62, seams: false, fuse: false, now: now);
            c.restore();
          }
        } else {
          c.rotate(spin);
          _bomb(c, r, seams: true, fuse: true, now: now);
        }
      default: // lob
        c.rotate(spin);
        _bomb(c, r, seams: false, fuse: true, now: now);
    }
    c.restore();
  }

  void _outlined(Canvas c, Path p, Color color) {
    _fill.color = color;
    c
      ..drawPath(p, _fill)
      ..drawPath(p, _ink..color = _inkColor);
  }

  void _shine(Canvas c, Offset at, double r) {
    _fill.color = const Color(0xCCFFFFFF);
    c.drawCircle(at, r, _fill);
  }

  /// 둥근 폭탄(진한 남색) + 꼭지 + 도화선 불꽃.
  void _bomb(Canvas c, double r, {required bool seams, required bool fuse, required double now}) {
    _path
      ..reset()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
    _outlined(c, _path, const Color(0xFF2E2A44));
    if (seams) {
      _ink.color = const Color(0xFF6A6488);
      c
        ..drawLine(Offset(-r * 0.95, 0), Offset(r * 0.95, 0), _ink)
        ..drawLine(Offset(0, -r * 0.95), Offset(0, r * 0.95), _ink);
    }
    _shine(c, Offset(-r * 0.35, -r * 0.35), r * 0.26);
    if (!fuse) return;
    _fill.color = const Color(0xFF8A8098);
    c.drawRect(Rect.fromCenter(center: Offset(0, -r * 1.05), width: r * 0.6, height: r * 0.4), _fill);
    final flick = 0.75 + 0.25 * math.sin(now / 40);
    _fill.color = const Color(0xFFFFB33A);
    c.drawCircle(Offset(r * 0.25, -r * 1.45), r * 0.42 * flick, _fill);
    _fill.color = const Color(0xFFFFF4C0);
    c.drawCircle(Offset(r * 0.25, -r * 1.45), r * 0.2 * flick, _fill);
  }

  /// 창(관통) · 빛 창(레이저): 진행 방향 +x.
  void _spear(Canvas c, double r, {required bool laser}) {
    final glow = laser ? const Color(0xFFFF6FB5) : const Color(0xFFBFE8FF);
    _fill.color = glow.withValues(alpha: 0.45);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(-r * 2.4, -r * 0.45, r * 0.8, r * 0.45), Radius.circular(r * 0.45)),
      _fill,
    );
    _path
      ..reset()
      ..moveTo(r * 2.0, 0)
      ..lineTo(r * 0.6, -r * 0.62)
      ..lineTo(r * 0.75, 0)
      ..lineTo(r * 0.6, r * 0.62)
      ..close();
    _ink.color = _inkColor;
    c.drawLine(Offset(-r * 2.0, 0), Offset(r * 0.7, 0), _ink..strokeWidth = r * 0.5);
    _ink.strokeWidth = math.max(0.6, r * 0.22);
    _fill.color = laser ? const Color(0xFFFFB8DC) : const Color(0xFF9A6A3A);
    c.drawLine(Offset(-r * 2.0, 0), Offset(r * 0.7, 0), _fill..strokeWidth = r * 0.28);
    _outlined(c, _path, laser ? const Color(0xFFFFE6F4) : const Color(0xFFE8F0FA));
  }

  /// 직사 탄: 길쭉한 금빛 탄두 + 뒤 흰 줄기.
  void _slug(Canvas c, double r) {
    _fill.color = const Color(0x88FFFFFF);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(-r * 2.6, -r * 0.35, 0, r * 0.35), Radius.circular(r * 0.35)),
      _fill,
    );
    _path
      ..reset()
      ..addRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(-r * 0.9, -r * 0.6, r * 1.1, r * 0.6), Radius.circular(r * 0.6)),
      );
    _outlined(c, _path, const Color(0xFFFFC23A));
    _shine(c, Offset(r * 0.3, -r * 0.22), r * 0.2);
  }

  /// 깃털 다트(공중).
  void _dart(Canvas c, double r) {
    _path
      ..reset()
      ..moveTo(r * 1.6, 0)
      ..quadraticBezierTo(0, -r * 0.9, -r * 1.4, -r * 0.5)
      ..lineTo(-r * 0.9, 0)
      ..lineTo(-r * 1.4, r * 0.5)
      ..quadraticBezierTo(0, r * 0.9, r * 1.6, 0)
      ..close();
    _outlined(c, _path, const Color(0xFFF4F8FF));
    _ink.color = const Color(0xFF8AB0D8);
    c.drawLine(Offset(-r * 0.9, 0), Offset(r * 1.2, 0), _ink);
  }

  /// 물방울 어뢰 + 뒤 거품.
  void _torpedo(Canvas c, double r, double now) {
    for (var i = 1; i <= 3; i++) {
      _fill.color = Color.fromRGBO(220, 245, 255, 0.7 - i * 0.18);
      c.drawCircle(Offset(-r * (1.2 + i * 0.7), math.sin(now / 90 + i) * r * 0.3), r * (0.38 - i * 0.07), _fill);
    }
    _path
      ..reset()
      ..addOval(Rect.fromLTRB(-r * 1.2, -r * 0.7, r * 1.2, r * 0.7));
    _outlined(c, _path, const Color(0xFF3A8AE8));
    _shine(c, Offset(r * 0.3, -r * 0.28), r * 0.22);
  }

  /// 물수제비 원반(위에서 본 납작 원 + 테).
  void _disc(Canvas c, double r) {
    _path
      ..reset()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * 1.05));
    _outlined(c, _path, const Color(0xFF3AC8C0));
    _ink.color = const Color(0xFFBFF4EE);
    c.drawCircle(Offset.zero, r * 0.55, _ink);
    _shine(c, Offset(-r * 0.4, -r * 0.4), r * 0.22);
  }

  /// 도는 칼날 셋.
  void _blades(Canvas c, double r) {
    for (var i = 0; i < 3; i++) {
      final a = i * 2 * math.pi / 3;
      final u = Offset(math.cos(a), math.sin(a));
      final n = Offset(-u.dy, u.dx);
      _path
        ..reset()
        ..moveTo(u.dx * r * 0.3, u.dy * r * 0.3)
        ..quadraticBezierTo(
          u.dx * r * 1.1 + n.dx * r * 0.8,
          u.dy * r * 1.1 + n.dy * r * 0.8,
          u.dx * r * 1.6,
          u.dy * r * 1.6,
        )
        ..lineTo(u.dx * r * 0.7 - n.dx * r * 0.3, u.dy * r * 0.7 - n.dy * r * 0.3)
        ..close();
      _outlined(c, _path, const Color(0xFFE8F0FA));
    }
    _fill.color = const Color(0xFFC83A4A);
    c.drawCircle(Offset.zero, r * 0.38, _fill);
  }

  /// 번개 구슬: 노란 구슬 + 튀는 전기 세 줄.
  void _orb(Canvas c, double r, double now) {
    _ink
      ..color = const Color(0xFFFFF4A0)
      ..strokeWidth = math.max(0.5, r * 0.16);
    final k = (now / 60).floor();
    for (var i = 0; i < 3; i++) {
      final a = (k * 2.3 + i * 2.1) % (2 * math.pi);
      final u = Offset(math.cos(a), math.sin(a));
      final n = Offset(-u.dy, u.dx);
      c
        ..drawLine(u * r * 0.8, u * r * 1.3 + n * r * 0.3, _ink)
        ..drawLine(u * r * 1.3 + n * r * 0.3, u * r * 1.8 - n * r * 0.2, _ink);
    }
    _ink.strokeWidth = math.max(0.6, r * 0.22);
    _path
      ..reset()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
    _outlined(c, _path, const Color(0xFFFFE04A));
    _fill.color = const Color(0xFFFFFFF0);
    c.drawCircle(Offset.zero, r * 0.45, _fill);
  }

  /// 가시 구슬 + 빛 고리(고리 계열).
  void _spiky(Canvas c, double r, double now) {
    _path.reset();
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      final rr = i.isEven ? r * 1.25 : r * 0.85;
      final p = Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        _path.moveTo(p.dx, p.dy);
      } else {
        _path.lineTo(p.dx, p.dy);
      }
    }
    _path.close();
    _outlined(c, _path, const Color(0xFFFF9A3A));
    _shine(c, Offset(-r * 0.3, -r * 0.3), r * 0.22);
    _ink.color = Color.fromRGBO(255, 230, 160, 0.6 + 0.3 * math.sin(now / 80));
    c.drawCircle(Offset.zero, r * 1.6, _ink);
  }
}
