import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/top/top_sea_props.dart';

/// 탑다운 바다 (T2, S1 '단색에 점선뿐이라 밋밋'): 깊이 얼룩(느린 시차) · 물결 대시 · 햇빛 반짝임 · 파도 거품 · 배 항적(흰 V자).
/// 배는 가운데 고정, 바다가 뱃머리 반대쪽으로 흐른다(흐름 = 진행 방향 × 속도, 장면 시계 기준).
/// 절전·CPU(S1): 무늬는 타일 하나를 Path로 한 번 만들고, 보이는 영역을 덮는 큰 Path로 묶어 층마다 그리기 1번 + 옮기기만.
/// 반짝임·거품은 drawRawPoints/drawPath 몇 번. 좌표는 전장 단위(그리는 쪽이 dot배·카메라로 옮겨 둔다). 값은 fx_map `topSea`.
class TopSeaPainter {
  TopSeaPainter(this.cfg);

  final JsonReader cfg;
  int _c(String k) => parseArgb(cfg.str(k), 'topSea.$k');
  late ({Color base, Color deep, Color shallow, Color wave}) _pal = seaPalette(cfg, null);
  String? _region;
  late final TopSeaProps? _props = TopSeaProps.of(cfg); // 흘러가는 외곽선 소품(디자인 개편 ③), 피버엔 흐려짐

  late final Color _foam = Color(_c('foam'));
  late final Color _goldWave = Color(_c('goldWave'));
  late final Color _goldFoam = Color(_c('goldFoam'));
  late final Color _goldBase = Color(_c('goldBase'));

  /// 보물 바다(환생 v2 §4): 물결·거품·반짝임을 금빛으로, 반짝임 더 자주.
  bool gold = false;

  /// 피버 물들임 0~1 (TopFever.level × fever seaAlpha): 바다 색을 금빛 바다 쪽으로 섞는다(덮개 섞기는 기기마다 달라 색 자체를 바꾼다).
  double fever = 0;

  /// 피버 질주 0~1: 바다 흐름 ×4, 항적 2배 길게, 뱃머리 V자 물보라 크게(사용자 '배가 빠르게 나아가는 연출').
  double boost = 0;

  /// 지금 흐름 속도(단위/초) — 피버 S자 항적이 흐름을 따라 뒤로 흘러간다.
  double get flowSpeed => _speed * (1 + 7 * boost);
  Offset _dir = const Offset(0, 1);
  late final Color _feverBase = Color(_c('feverBase'));
  late final Color _feverDeep = Color(_c('feverDeep'));
  late final Color _feverShallow = Color(_c('feverShallow'));

  /// 파랑 → (금빛 바다 gold면) 금빛 → (피버면) 호박색.
  /// 파랑 ↔ 호박 중간은 밝은 크림 쪽으로 띄운다 — 그냥 섞으면 회색(꺼질 때 서서히 돌아올 때).
  Color _mix(Color blue, Color gold, Color fever) {
    final t = this.fever;
    final mid = Color.lerp(this.gold ? gold : blue, fever, t)!;
    return t <= 0 || t >= 1 ? mid : Color.lerp(mid, _cream.withValues(alpha: mid.a), 2.4 * t * (1 - t))!;
  }

  static const _cream = Color(0xFFFFF4D6);
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
    _dir = Offset(-math.sin(heading), math.cos(heading));
    flow += _dir * (_speed * (1 + 7 * boost) * dt);
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
  /// [region]: 해역 팔레트(한 단계 깊은 진한 청록·남색, fx_map `topSea.regions`)·소품 세트 — 바뀔 때만 읽는다.
  void paint(Canvas c, Rect view, double clockMs, {String? region}) {
    if (region != null && region != _region) _pal = seaPalette(cfg, _region = region);
    // 시트를 여닫는 동안 보이는 높이가 매 프레임 바뀐다 — 길(Path)은 커질 때만 다시 만든다(64단위로 올림, 사용자 '시트 열면 버벅').
    final built = _builtFor;
    if (built == null || view.width > built.width + 0.5 || view.height > built.height) {
      final size = Size(view.width, (view.height / 64).ceil() * 64.0);
      _build(size);
      _builtFor = size;
    }
    _paint.color = _mix(_pal.base, _goldBase, _feverBase);
    c.drawRect(view.inflate(1), _paint);
    void layer(Path p, Color color, double parallax, {double back = 0}) {
      final o = flow * parallax - _dir * back;
      final dx = (o.dx % _tile) - _tile;
      final dy = (o.dy % _tile) - _tile;
      _paint.color = color;
      c
        ..save()
        ..translate((view.left + dx).roundToDouble(), (view.top + dy).roundToDouble())
        ..drawPath(p, _paint)
        ..restore();
    }

    layer(_deepPath, _mix(_pal.deep, _pal.deep, _feverDeep.withValues(alpha: _pal.deep.a)), 0.6);
    layer(_shallowPath, _mix(_pal.shallow, _pal.shallow, _feverShallow.withValues(alpha: _pal.shallow.a)), 0.6);
    final wave = _mix(_pal.wave, _goldWave, _goldWave);
    // 질주 모션 블러: 물결·얕은 곳을 흐름 반대쪽으로 흐린 잔상 2겹 — 세로로 늘어나 보인다.
    if (boost > 0.05) {
      for (final k in const [1.0, 2.0]) {
        final shallow = _mix(_pal.shallow, _pal.shallow, _feverShallow.withValues(alpha: _pal.shallow.a));
        layer(_shallowPath, shallow.withValues(alpha: _pal.shallow.a * 0.5 * boost), 0.6, back: 5 * k * boost);
        layer(_wavePath, wave.withValues(alpha: 0.45 * boost / k), 1, back: 6 * k * boost);
      }
    }
    layer(_wavePath, wave, 1);
    _props?.paint(c, view, flow.dy, _region ?? '', alpha: 1 - fever);
    // 거품: 천천히 숨 쉬듯 나타났다 사라짐
    final foamA = 0.35 + 0.35 * math.sin(clockMs / 900);
    layer(_foamPath, _mix(_foam, _goldFoam, _goldFoam).withValues(alpha: foamA.clamp(0.0, 1.0)), 1);
    // 햇빛 반짝임: 세 무리로 나눠 깜빡임(무리마다 알파 하나 → drawRawPoints 3번)
    final o = flow;
    final dx = (o.dx % _tile) - _tile + view.left;
    final dy = (o.dy % _tile) - _tile + view.top;
    c
      ..save()
      ..translate(dx.roundToDouble(), dy.roundToDouble());
    for (var g = 0; g < 3; g++) {
      final a = math.max<double>(0, math.sin(clockMs / (gold || fever > 0.5 ? 160 : 260) + g * 2.1));
      if (a < 0.05) continue;
      _points
        ..strokeWidth = fever > 0.5 ? 2 : 1
        // 피버: 반짝임을 거의 흰 금빛으로(빛나는 황금 바다, S1).
        ..color = Color.lerp(gold ? _goldWave : _foam, const Color(0xFFFFFBE0), fever)!.withValues(alpha: a);
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
    // 점들을 알파 4단계 묶음으로 모아 drawRawPoints 몇 번(S1 배터리 — 전에는 점마다 drawRect 약 90번).
    // 질주 때 길이·벌어짐을 줄였다(피드백 #20 — V자 두 줄이 화면 끝까지 그어져 조잡해 보였다).
    final length = (60 + 90 * boost).round();
    for (final b in _wakeBuckets) {
      b.n = 0;
    }
    _rainbowClock = clockMs;
    final phase = (clockMs / 50) % 6;
    for (var i = 0; i < length; i += 2) {
      final fade = 1 - i / length;
      final spread = halfWidth * 0.7 + i * (0.6 + 0.2 * boost);
      final y = stern + i + 1;
      if ((i + phase).floor() % 6 < 4) {
        _wakeBuckets[(fade * 3.99).floor()]
          ..add((-spread).floorToDouble(), y)
          ..add(spread.floorToDouble(), y);
      }
      if (i < 24) {
        // 가운데 소용돌이(고물 가까이 진하게)
        final wob = math.sin(clockMs / 140 + i * 0.7) * (2 + i * 0.15);
        final k = ((1 - i / 24) * 3.99).floor();
        _wakeBuckets[k].add(wob.roundToDouble(), y - 0.5);
        if (i < 8) _wakeBuckets[k].add(wob.roundToDouble() + 2, y - 0.5);
      }
    }
    // 뱃머리 물보라: 양옆 짧은 흰 줄
    final spray = 0.5 + 0.5 * math.sin(clockMs / 120);
    // 질주: 뱃머리 흰 파도 벽(물을 가르는 V자) — 두 줄로 두껍게. 바깥으로 갈수록 옅어지고 배 폭 3배쯤에서 끝난다
    // (피드백 #20 — 전에는 화면 끝까지 그어져 조잡해 보였다).
    final sprays = 5 + (14 * boost).round();
    for (var k = 0; k < sprays; k++) {
      final y = -bow + 10 + k * (2 + 2.2 * boost);
      final x = halfWidth * 0.55 + k * (1.2 + 2.6 * boost) + spray;
      final tone = (3.99 * (1 - k / (sprays + 2))).floor();
      if (boost > 0.5) {
        _wakeBuckets[math.max(0, tone - 1)]
          ..add(-x - 6, y + 2)
          ..add(x + 6, y + 2);
      }
      if (boost > 0.3) {
        _wakeBuckets[tone]
          ..add(-x - 3, y + 1)
          ..add(x + 3, y + 1);
      }
      _wakeBuckets[tone]
        ..add(-x - 1, y)
        ..add(x + 1, y);
    }
    // 질주: 고물 뒤 물방울 튐(양옆으로 흩어지며 뒤로).
    if (boost > 0.2) {
      for (var k = 0; k < 12; k++) {
        final t = ((clockMs / 500) + k / 12) % 1;
        final side = k.isEven ? 1 : -1;
        final x = side * (halfWidth * 0.5 + t * 14 + (k % 3) * 2);
        final y = stern + 4 + t * 26;
        _wakeBuckets[(3 - t * 3.99).floor().clamp(0, 3)].add(x.roundToDouble(), y.roundToDouble());
      }
    }
    _points.strokeWidth = 2 + boost;
    for (var k = 0; k < 4; k++) {
      final b = _wakeBuckets[k];
      if (b.n == 0) continue;
      // 피버 v2: 무지개 항적 — 거리 칸마다 색이 다르고 시간에 따라 흘러간다.
      _points.color = fever > 0.5
          ? HSVColor.fromAHSV(0.35 + 0.6 * (k + 1) / 4, (_rainbowClock / 4 + k * 70) % 360, 0.8, 1).toColor()
          : _foam.withValues(alpha: 0.2 + 0.7 * (k + 1) / 4);
      c.drawRawPoints(PointMode.points, Float32List.sublistView(b.xy, 0, b.n * 2), _points);
    }
  }

  final List<_Points> _wakeBuckets = List.generate(4, (_) => _Points(480));
  double _rainbowClock = 0;
}

/// 점 묶음(재사용 버퍼) — 프레임마다 할당 없이 채운다.
class _Points {
  _Points(int cap) : xy = Float32List(cap * 2);
  final Float32List xy;
  int n = 0;

  void add(double x, double y) {
    if (n * 2 >= xy.length) return;
    xy[n * 2] = x;
    xy[n * 2 + 1] = y;
    n++;
  }
}
