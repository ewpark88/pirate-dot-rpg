import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:game_data/game_data.dart';

/// 탑다운 바다 (T2, S1 '단색에 점선뿐이라 밋밋'): 깊이 얼룩(느린 시차) · 물결 대시 · 햇빛 반짝임 · 파도 거품 · 배 항적(흰 V자).
/// 배는 가운데 고정, 바다가 뱃머리 반대쪽으로 흐른다(흐름 = 진행 방향 × 속도, 장면 시계 기준).
/// 절전·CPU(S1): 무늬는 타일 하나를 Path로 한 번 만들고, 보이는 영역을 덮는 큰 Path로 묶어 층마다 그리기 1번 + 옮기기만.
/// 반짝임·거품은 drawRawPoints/drawPath 몇 번. 좌표는 전장 단위(그리는 쪽이 dot배·카메라로 옮겨 둔다). 값은 fx_map `topSea`.
class TopSeaPainter {
  TopSeaPainter(this.cfg);

  final JsonReader cfg;
  int _c(String k) => parseArgb(cfg.str(k), 'topSea.$k');
  late final Color _base = Color(_c('base'));
  late final Color _deep = Color(_c('deep'));
  late final Color _shallow = Color(_c('shallow'));
  late final Color _wave = Color(_c('wave'));
  late final Color _foam = Color(_c('foam'));
  late final Color _goldWave = Color(_c('goldWave'));
  late final Color _goldFoam = Color(_c('goldFoam'));
  late final Color _goldBase = Color(_c('goldBase'));

  /// 보물 바다(환생 v2 §4): 물결·거품·반짝임을 금빛으로, 반짝임 더 자주.
  bool gold = false;
  late final double _tile = cfg.number('tile');
  late final double _speed = cfg.number('flowSpeed');
  final _paint = Paint()..isAntiAlias = false;
  final _points = Paint()
    ..isAntiAlias = false
    ..strokeCap = StrokeCap.square;

  Size? _builtFor;
  late Path _deepPath;
  late Path _shallowPath;
  late Path _wavePath;
  late Float32List _glints;
  late List<double> _glintPhase;
  late Path _foamPath;

  /// 흐른 거리 (단위, 뱃머리 반대쪽으로 쌓임).
  Offset flow = Offset.zero;
  double _lastMs = 0;

  /// 장면 시계로 흐름을 쌓는다 ([heading] 0 = 위, 시계 방향).
  void advance(double clockMs, double heading) {
    final dt = (clockMs - _lastMs).clamp(0.0, 100.0) / 1000;
    _lastMs = clockMs;
    flow += Offset(-math.sin(heading), math.cos(heading)) * (_speed * dt);
  }

  static int _hash(int a, int b) {
    var h = a * 374761393 + b * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7FFFFFFF;
  }

  /// 보이는 크기 [view](단위)를 타일 한 칸 여유로 덮는 무늬를 만든다.
  void _build(Size view) {
    final t = _tile;
    final nx = (view.width / t).ceil() + 2;
    final ny = (view.height / t).ceil() + 2;
    _deepPath = Path();
    _shallowPath = Path();
    _wavePath = Path();
    _foamPath = Path();
    final glints = <double>[];
    _glintPhase = [];
    for (var j = 0; j < ny; j++) {
      for (var i = 0; i < nx; i++) {
        final ox = i * t;
        final oy = j * t;
        // 깊이 얼룩: 칸마다 크기·자리가 다른 픽셀 타원 몇 개(진한 것·밝은 것) — 칸 번호로 섞어 격자 티가 덜 나게.
        for (var b = 0; b < 5; b++) {
          final h = _hash(i * 7 + b, j * 13 + b * 3);
          final cx = ox + h % t.toInt();
          final cy = oy + (h >> 7) % t.toInt();
          final rx = 6.0 + (h >> 14) % 16;
          final ry = 3.0 + (h >> 18) % 7;
          final path = b.isEven ? _deepPath : _shallowPath;
          for (var y = -ry; y <= ry; y++) {
            final hw = rx * math.sqrt(math.max(0, 1 - (y * y) / (ry * ry)));
            path.addRect(Rect.fromLTWH((cx - hw).floorToDouble(), cy + y, (hw * 2).ceilToDouble(), 1));
          }
        }
        // 물결 대시
        for (var w = 0; w < 18; w++) {
          final hw = _hash(i * 3 + w, j * 5 + w * 11);
          final x = ox + hw % t.toInt();
          final y = oy + (hw >> 9) % t.toInt();
          _wavePath.addRect(Rect.fromLTWH(x, y, 4 + (w % 3).toDouble(), 1));
        }
        // 햇빛 반짝임 자리
        for (var g = 0; g < 9; g++) {
          final h = _hash(g * 31 + i * 5 + 1, j * 17 + 7);
          glints
            ..add(ox + h % t.toInt())
            ..add(oy + (h >> 8) % t.toInt());
          _glintPhase.add((h >> 16) % 628 / 100);
        }
        // 파도 거품: 작은 물결 모양
        final fx = ox + (23 * (i + 2) + 11 * j) % t;
        final fy = oy + (13 * (j + 3) + 7 * i) % t;
        _foamPath
          ..addRect(Rect.fromLTWH(fx, fy, 3, 1))
          ..addRect(Rect.fromLTWH(fx + 3, fy - 1, 2, 1))
          ..addRect(Rect.fromLTWH(fx - 1, fy + 1, 2, 1));
      }
    }
    _glints = Float32List.fromList(glints);
  }

  /// 바다 전체: [view] = 보이는 영역(단위, 왼쪽 위 기준), [clockMs] = 깜빡임용.
  void paint(Canvas c, Rect view, double clockMs) {
    if (_builtFor != view.size) {
      _build(view.size);
      _builtFor = view.size;
    }
    _paint.color = gold ? _goldBase : _base;
    c.drawRect(view.inflate(1), _paint);
    void layer(Path p, Color color, double parallax) {
      final o = flow * parallax;
      final dx = (o.dx % _tile) - _tile;
      final dy = (o.dy % _tile) - _tile;
      _paint.color = color;
      c
        ..save()
        ..translate((view.left + dx).roundToDouble(), (view.top + dy).roundToDouble())
        ..drawPath(p, _paint)
        ..restore();
    }

    layer(_deepPath, _deep, 0.6);
    layer(_shallowPath, _shallow, 0.6);
    layer(_wavePath, gold ? _goldWave : _wave, 1);
    // 거품: 천천히 숨 쉬듯 나타났다 사라짐
    final foamA = 0.35 + 0.35 * math.sin(clockMs / 900);
    layer(_foamPath, (gold ? _goldFoam : _foam).withValues(alpha: foamA.clamp(0.0, 1.0)), 1);
    // 햇빛 반짝임: 세 무리로 나눠 깜빡임(무리마다 알파 하나 → drawRawPoints 3번)
    final o = flow;
    final dx = (o.dx % _tile) - _tile + view.left;
    final dy = (o.dy % _tile) - _tile + view.top;
    c
      ..save()
      ..translate(dx.roundToDouble(), dy.roundToDouble());
    for (var g = 0; g < 3; g++) {
      final a = math.max<double>(0, math.sin(clockMs / (gold ? 160 : 260) + g * 2.1)) * (gold ? 1.0 : 1);
      if (a < 0.05) continue;
      _points
        ..strokeWidth = 1
        ..color = (gold ? _goldWave : _foam).withValues(alpha: a);
      c.drawRawPoints(PointMode.points, _groupOf(g), _points);
    }
    c.restore();
  }

  final Map<int, Float32List> _groups = {};
  Float32List _groupOf(int g) => _groups[g + _glints.length * 3] ??= () {
    final out = <double>[];
    for (var i = g; i < _glints.length ~/ 2; i += 3) {
      out
        ..add(_glints[i * 2])
        ..add(_glints[i * 2 + 1]);
    }
    return Float32List.fromList(out);
  }();

  /// 배 항적: 고물 뒤 흰 거품 소용돌이 + 뒤로 벌어지는 V자 두 줄(2단위 굵기, 끝으로 갈수록 흐림·끊김) + 뱃머리 양옆 물보라.
  /// 배 기준 좌표(뱃머리 위, 고물 = +[stern], 뱃머리 = −[bow])로 그린다.
  void wake(Canvas c, double stern, double bow, double halfWidth, double clockMs) {
    const length = 60;
    final phase = (clockMs / 50) % 6;
    for (var i = 0; i < length; i += 2) {
      final fade = 1 - i / length;
      final spread = halfWidth * 0.7 + i * 0.6;
      final y = stern + i;
      if ((i + phase).floor() % 6 < 4) {
        _paint.color = _foam.withValues(alpha: 0.9 * fade);
        c
          ..drawRect(Rect.fromLTWH((-spread - 1).floorToDouble(), y, 2, 2), _paint)
          ..drawRect(Rect.fromLTWH(spread.floorToDouble() - 1, y, 2, 2), _paint);
      }
      // 가운데 소용돌이(고물 가까이 진하게)
      if (i < 24) {
        final wob = math.sin(clockMs / 140 + i * 0.7) * (2 + i * 0.15);
        _paint.color = _foam.withValues(alpha: 0.75 * (1 - i / 24));
        c.drawRect(Rect.fromLTWH((wob - 1).roundToDouble(), y, 2 + (i < 8 ? 2 : 0), 1), _paint);
      }
    }
    // 뱃머리 물보라: 양옆 짧은 흰 줄
    final spray = 0.5 + 0.5 * math.sin(clockMs / 120);
    _paint.color = _foam.withValues(alpha: 0.5 + 0.4 * spray);
    for (var k = 0; k < 5; k++) {
      final y = -bow + 10 + k * 2;
      final x = halfWidth * 0.55 + k * 1.2 + spray;
      c
        ..drawRect(Rect.fromLTWH(-x - 2, y, 2, 1), _paint)
        ..drawRect(Rect.fromLTWH(x, y, 2, 1), _paint);
    }
  }
}
