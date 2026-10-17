import 'dart:math' as math;
import 'dart:ui';

part 'top_ultimate_shapes.dart';

/// 계열별 고유 필살기(S1 핵앤슬래시 — UltimateCast의 선원 계열): 화면 전체급 연출 1.1초, 배 기준 전장 좌표.
/// 관통 = 화면을 가로지르는 거대 창 광선 · 레이저 = 배에서 도는 빔 3줄 · 수중 = 물기둥 소용돌이 · 번개 = 낙뢰 연쇄 ·
/// 폭발 = 융단 폭격 줄 · 집속 = 폭탄 비 · 돌격 = 칼바람 회오리 · 직사 = 일제 사격 · 물수제비 = 튀는 원반 행렬 ·
/// 공중 = 급강하 폭격 · 고리 = 겹 충격파. 신화(등급 5↑)는 금·무지개 테가 더해진다. 배는 위 층이라 늘 또렷(배 반경 안은 옅게).
class TopUltimate {
  String _family = '';
  double _at = -1000000000;
  Offset _ship = Offset.zero;
  int _rarity = 0;

  static const lifeMs = 1100.0;

  /// 화면 전체급 크기(전장 단위) — 배 기준 위로 [reach], 좌우로 [half].
  static const reach = 300.0;
  static const half = 150.0;

  final _fill = Paint()..isAntiAlias = true;
  final _line = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final _path = Path();
  final _dim = Paint();

  /// 선 굵기 배율(빛 번짐 패스는 더 굵게) — 화면 전체급 굵기(S1 '선 1~2px로는 가늘다').
  double _k = 2.4;
  static const _blur = MaskFilter.blur(BlurStyle.normal, 7);

  void start(String family, Offset ship, double now, {int rarity = 0}) {
    _family = family;
    _ship = ship;
    _at = now;
    _rarity = rarity;
  }

  bool active(double now) => now >= _at && now - _at < lifeMs;

  void clear() => _at = -1000000000;

  void paint(Canvas c, double now, {required bool lite}) {
    if (!active(now)) return;
    final t = (now - _at) / lifeMs;
    final s = _ship;
    // ① 시작: 주변 25% 어둡게(필살기만 빛나게) + 흰 번쩍 — 화면 크기 레이어 없이 사각형 한 장
    final dim = t < 0.15 ? t / 0.15 : (t > 0.6 ? math.max(0, 1 - (t - 0.6) / 0.25) : 1.0);
    _dim.color = Color.fromRGBO(10, 14, 40, 0.25 * dim);
    c.drawRect(Rect.fromCenter(center: s + const Offset(0, -100), width: 900, height: 1200), _dim);
    if (t < 0.06) {
      _dim.color = Color.fromRGBO(255, 255, 255, 0.4 * (1 - t / 0.06));
      c.drawRect(Rect.fromCenter(center: s + const Offset(0, -100), width: 900, height: 1200), _dim);
    }
    // ② 빛 번짐 2겹: 굵고 흐린 패스(모양마다 블러 붓 — 오프스크린 레이어 없음) → 또렷한 패스
    if (!lite) {
      _k = 2.4 * 2.2;
      _line.maskFilter = _blur;
      _fill.maskFilter = _blur;
      _shape(c, s, t, lite: lite);
      _line.maskFilter = null;
      _fill.maskFilter = null;
    }
    _k = 2.4;
    _shape(c, s, t, lite: lite);
    if (_rarity >= 5) _mythic(c, s, t);
    // ⑤ 끝: 화면 전체 충격파 링
    if (t > 0.62) {
      final u = (t - 0.62) / 0.38;
      _line
        ..strokeWidth = 14 * (1 - u) + 2
        ..color = Color.fromRGBO(255, 245, 210, 0.85 * (1 - u));
      c.drawCircle(s, 40 + 420 * _ease(u), _line);
    }
  }

  void _shape(Canvas c, Offset s, double t, {required bool lite}) {
    switch (_family) {
      case 'pierce':
        _pierce(c, s, t);
      case 'laser':
        _laser(c, s, t, lite: lite);
      case 'underwater':
        _vortex(c, s, t, lite: lite);
      case 'shock':
        _thunder(c, s, t, lite: lite);
      case 'cluster':
        _bombRain(c, s, t, lite: lite);
      case 'assault':
        _whirl(c, s, t, lite: lite);
      case 'direct':
        _broadside(c, s, t, lite: lite);
      case 'skip':
        _skipRow(c, s, t, lite: lite);
      case 'air':
        _dive(c, s, t, lite: lite);
      case 'ring':
        _rings(c, s, t);
      default:
        _carpet(c, s, t, lite: lite);
    }
  }

  /// 0~1 사이 들어옴·사라짐(처음 [a]까지 차오르고 마지막 [b]부터 사라짐).
  static double _env(double t, {double a = 0.12, double b = 0.75}) =>
      t < a ? t / a : (t > b ? ((1 - t) / (1 - b)).clamp(0.0, 1.0) : 1.0);

  static double _ease(double t) => 1 - (1 - t) * (1 - t) * (1 - t);

  /// 신화: 배 둘레 금·무지개 테가 크게 퍼진다.
  void _mythic(Canvas c, Offset s, double t) {
    const colors = [0xFFFF5A5A, 0xFFFFB347, 0xFFFFF15A, 0xFF7CF06A, 0xFF5FD8FF, 0xFFB98CFF];
    final e = _env(t);
    for (var i = 0; i < colors.length; i++) {
      _line
        ..strokeWidth = 4
        ..color = Color(colors[i]).withValues(alpha: 0.7 * e);
      c.drawCircle(s, 40 + 200 * _ease(t) + i * 5, _line);
    }
    _line
      ..strokeWidth = 6
      ..color = Color.fromRGBO(255, 220, 90, 0.8 * e);
    c.drawCircle(s, 34 + 200 * _ease(t), _line);
  }
}
