import 'dart:math' as math;
import 'dart:ui';

import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/paint/sprite_draw.dart';

/// 바다 분위기 탑다운판 (docs/specs/platform-fun-atmosphere.md, S1 승인 — 보기만 바뀜, 엔진 무관). 값은 fx_map `atmosphere`.
///
/// - 시간대: 렌더 시계(장면 시계)로 12분 한 바퀴 낮 → 노을 → 밤 → 새벽, 바뀔 때 fadeSec 동안 서서히. 유령해는 늘 밤, 심연은 늘 어둡게.
///   색조·어둡게는 **바다(와 풍경)에만** — 적·발사체·숫자는 그 위에 그려서 밤에도 같은 색(가독성 규칙).
/// - 날씨(시간대마다 한 번 굴림, 해역별): 비(수면 동그라미 + 옅은 빗줄), 안개(흐르는 흰 막), 오로라(밤 빙하 — 수면에 비친 초록·보라 띠),
///   화산재(화산 늘). 밤에는 수면에 비친 별 반짝임.
/// - 지나가는 풍경: 해역별 섬·등대·고래·난파선·빙산·화산섬·유령선이 배 앞쪽 옆에서 나타나 바다 흐름과 함께 뒤로 지나간다(동시 2개).
/// - 절전: 파티클 ½, 풍경 멈춤(보이기만).
/// 좌표: 배 기준(배 중심 원점, 단위) — TopScenePainter가 옮겨 둔다.
class TopAtmosphere {
  TopAtmosphere(this.cfg, this.sprites);

  final JsonReader cfg;
  final SpriteDraw sprites;

  late final double _cycle = cfg.number('cycleSec') * 1000;
  late final double _fade = cfg.number('fadeSec') * 1000;
  late final List<_Phase> _phases = [
    for (final p in cfg.raw['phases'] as List)
      _Phase(
        (p as Map)['id'] as String,
        (p['sec'] as num) * 1000.0,
        Color(parseArgb((p['tint'] as String?) ?? '#000000', 'atmosphere.tint')),
        ((p['tintAlpha'] as num?) ?? 0).toDouble(),
        ((p['dim'] as num?) ?? 0).toDouble(),
        ((p['stars'] as num?) ?? 0).toDouble(),
      ),
  ];
  late final JsonReader _weather = cfg.obj('weather');
  late final JsonReader _land = cfg.obj('landmarks');

  final _paint = Paint()..isAntiAlias = false;
  final _soft = Paint()..isAntiAlias = true;

  /// 지금 보이는 상태 (테스트·운영자 확인용).
  String phaseId = 'day';
  double dim = 0;
  double stars = 0;
  Color tint = const Color(0x00000000);
  bool rain = false;
  bool fog = false;
  bool aurora = false;
  bool ash = false;
  final List<Landmark> landmarks = [];

  int _rolledFor = -1;
  double? _nextLandMs;

  /// 운영자·테스트용 시계 더하기 (ms) — 시간대 미리보기(예: 밤 = 낮 6분 + 노을 1.5분 뒤).
  double offsetMs = 0;

  /// 첫 풍경은 전투 시작 뒤 이만큼 지나서.
  static const _firstLandMs = 20000.0;
  int _landSeq = 0;

  static int _hash(int a, int b) {
    var h = a * 374761393 + b * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7FFFFFFF;
  }

  /// 시계 [clockMs](+ offsetMs)·해역 [region]으로 시간대·날씨를 정하고, 풍경을 [flow](바다 흐름, 단위)만큼 옮긴다.
  void update(double clockMs, String region, Offset flow, double heading, {required bool powerSave}) {
    final ms = clockMs + offsetMs;
    _nextLandMs ??= ms + _firstLandMs;
    final t = ms % _cycle;
    final lap = (ms / _cycle).floor();
    var start = 0.0;
    var i = 0;
    while (i < _phases.length - 1 && t >= start + _phases[i].ms) {
      start += _phases[i].ms;
      i++;
    }
    final cur = _phases[i];
    final next = _phases[(i + 1) % _phases.length];
    final into = t - start;
    final blend = into > cur.ms - _fade ? ((into - (cur.ms - _fade)) / _fade).clamp(0.0, 1.0) : 0.0;
    var a = cur;
    var b = next;
    var k = blend;
    if (region == 'phantom') {
      a = b = _phases.firstWhere((p) => p.id == 'night');
      k = 0;
    }
    phaseId = k < 0.5 ? a.id : b.id;
    tint = Color.lerp(a.tintColor, b.tintColor, k)!;
    dim = _lerp(a.dim, b.dim, k) + (region == 'abyss' ? 0.3 : 0);
    stars = _lerp(a.stars, b.stars, k);
    // 날씨: 시간대 하나에 한 번 굴림(같은 바퀴·같은 단계면 같은 결과).
    final roll = lap * 8 + i;
    if (roll != _rolledFor) {
      _rolledFor = roll;
      bool pick(String w, int salt) {
        if (!_weather.has(w)) return false;
        final o = _weather.obj(w);
        if (!o.strs('regions').contains(region)) return false;
        if (o.has('always') && o.raw['always'] == true) return true;
        if (o.has('phase') && o.str('phase') != cur.id) return false;
        return _hash(roll, salt) % 1000 < o.number('chance') * 1000;
      }

      rain = pick('rain', 1);
      fog = pick('fog', 2);
      aurora = pick('aurora', 3);
      ash = pick('ash', 4);
    }
    // 풍경: 간격마다 하나, 배 앞쪽 옆(보이는 영역 밖)에서 나타나 흐름과 함께 지나간다.
    if (!powerSave) {
      for (final l in landmarks) {
        l.pos = l.anchor + flow;
      }
    }
    landmarks.removeWhere((l) => l.pos.distance > _land.number('despawn'));
    if (ms >= _nextLandMs! && landmarks.length < _land.integer('maxOnScreen')) {
      final kinds = _land.obj('byRegion').strs(region);
      final iv = [for (final v in _land.raw['intervalSec'] as List) (v as num).toDouble()];
      final h = _hash(_landSeq++, 77);
      _nextLandMs = ms + (iv[0] + (iv[1] - iv[0]) * (h % 1000) / 1000) * 1000;
      if (kinds.isNotEmpty) {
        final ahead = _land.number('ahead');
        final side = (h >> 10).isEven ? 1 : -1;
        final lateral = _land.number('lateral') * (0.8 + (h >> 12) % 40 / 100);
        // 앞 = 진행 방향(heading 0 = 위), 옆 = 오른쪽 수직.
        final fwd = Offset(math.sin(heading), -math.cos(heading));
        final right = Offset(math.cos(heading), math.sin(heading));
        final at = fwd * ahead + right * (lateral * side);
        landmarks.add(Landmark(kinds[(h >> 4) % kinds.length], at - flow, h));
        landmarks.last.pos = at;
      }
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// 바다 위(적·배 아래): 풍경 → 색조·어둡게 → 수면 별 → 오로라 반사 → 안개 → 비 동그라미.
  void paintUnder(Canvas c, Rect view, double ms, {required bool powerSave}) {
    for (final l in landmarks) {
      final key = 'td_land:${l.kind}';
      final sheet = sprites.sheet(key);
      if (sheet == null) continue;
      final frame = ((ms / 600).floor() + l.seed) % sheet.frames;
      sprites.draw(c, key, l.pos.dx.roundToDouble(), l.pos.dy.roundToDouble(), frame: frame);
    }
    if (tint.a > 0) {
      _paint.color = tint;
      c.drawRect(view, _paint);
    }
    if (dim > 0) {
      _paint.color = Color.fromRGBO(12, 20, 48, dim.clamp(0.0, 0.8));
      c.drawRect(view, _paint);
    }
    final n = (stars * (powerSave ? 0.5 : 1)).round();
    for (var i = 0; i < n; i++) {
      final h = _hash(i, 9);
      final a = math.max<double>(0, math.sin(ms / 400 + i * 1.7));
      if (a < 0.1) continue;
      _paint.color = Color.fromRGBO(255, 250, 220, a * 0.9);
      c.drawRect(
        Rect.fromLTWH(view.left + h % view.width.toInt(), view.top + (h >> 9) % view.height.toInt(), 1, 1),
        _paint,
      );
    }
    if (aurora) {
      for (var band = 0; band < 3; band++) {
        final y0 = view.top + view.height * (0.18 + band * 0.12);
        final color = band.isEven ? const Color(0x3370FFB0) : const Color(0x33B080FF);
        _soft.color = color;
        final path = Path()..moveTo(view.left, y0);
        for (var x = 0.0; x <= view.width; x += 8) {
          path.lineTo(view.left + x, y0 + math.sin(x / 26 + ms / 1800 + band) * 6);
        }
        for (var x = view.width; x >= 0; x -= 8) {
          path.lineTo(view.left + x, y0 + 7 + math.sin(x / 26 + ms / 1800 + band + 0.6) * 6);
        }
        c.drawPath(path..close(), _soft);
      }
    }
    if (fog) {
      _soft.color = const Color(0x40F2F6FA);
      for (var i = 0; i < 4; i++) {
        final x = view.left + ((ms / 90 + i * 70) % (view.width + 120)) - 60;
        final y = view.top + view.height * (0.15 + i * 0.22);
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 120, height: 34), _soft);
      }
    }
    if (rain) {
      final drops = (_weather.obj('rain').integer('ripples') * (powerSave ? 0.5 : 1)).round();
      _soft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6;
      for (var i = 0; i < drops; i++) {
        final life = (ms / 700 + i * 0.37) % 1;
        final h = _hash(i, (ms / 700 + i * 0.37).floor());
        _soft.color = Color.fromRGBO(220, 240, 255, 0.5 * (1 - life));
        c.drawOval(
          Rect.fromCenter(
            center: Offset(view.left + h % view.width.toInt(), view.top + (h >> 9) % view.height.toInt()),
            width: 2 + life * 6,
            height: 1 + life * 3,
          ),
          _soft,
        );
      }
      _soft.style = PaintingStyle.fill;
    }
  }

  /// 맨 위(옅게): 빗줄·화산재. 파티클 상한 fx_map, 절전이면 ½.
  void paintOver(Canvas c, Rect view, double ms, {required bool powerSave}) {
    if (rain) {
      final n = (_weather.obj('rain').integer('streaks') * (powerSave ? 0.5 : 1)).round();
      _paint.color = const Color(0x55DCEBFF);
      for (var i = 0; i < n; i++) {
        final h = _hash(i, 3);
        final x = view.left + (h % view.width.toInt() + ms / 12) % view.width;
        final y = view.top + ((h >> 9) % view.height.toInt() + ms / 4) % view.height;
        c.drawRect(Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 1, 4), _paint);
      }
    }
    if (ash) {
      final n = (_weather.obj('ash').integer('flakes') * (powerSave ? 0.5 : 1)).round();
      for (var i = 0; i < n; i++) {
        final h = _hash(i, 5);
        final x = view.left + (h % view.width.toInt() + math.sin(ms / 900 + i) * 6) % view.width;
        final y = view.top + ((h >> 9) % view.height.toInt() + ms / 60) % view.height;
        _paint.color = i % 4 == 0 ? const Color(0x99FF9A40) : const Color(0x88A8A0A0);
        c.drawRect(Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 1, 1), _paint);
      }
    }
  }
}

class _Phase {
  _Phase(this.id, this.ms, Color tint, double tintAlpha, this.dim, this.stars)
    : tintColor = tint.withValues(alpha: tintAlpha);
  final String id;
  final double ms;
  final Color tintColor;
  final double dim;
  final double stars;
}

/// 지나가는 풍경 하나 — [anchor] + 바다 흐름 = 배 기준 자리.
class Landmark {
  Landmark(this.kind, this.anchor, this.seed);
  final String kind;
  final Offset anchor;
  final int seed;
  Offset pos = Offset.zero;
}
