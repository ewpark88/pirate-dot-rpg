import 'package:game_data/game_data.dart';

/// 해역 배경 팔레트 (기준 battle_ship.gif 구조): 하늘 띠 4단·구름·바다 띠 3단·물결 대시 2색.
class BackgroundPalette {
  BackgroundPalette.fromJson(JsonReader j)
    : sky = [for (final c in j.strs('sky')) parseArgb(c, '${j.path}.sky')],
      cloud = parseArgb(j.str('cloud'), '${j.path}.cloud'),
      sea = [for (final c in j.strs('sea')) parseArgb(c, '${j.path}.sea')],
      waves = [for (final c in j.strs('waves')) parseArgb(c, '${j.path}.waves')],
      underwaterAlpha = j.raw.containsKey('underwaterAlpha') ? j.number('underwaterAlpha') : defaultUnderwaterAlpha;

  /// 수중 적 색조 세기 기본값 (밝은 바다). 어두운 해역(심연)은 낮춰야 적이 묻히지 않는다.
  static const defaultUnderwaterAlpha = 0.45;

  final List<int> sky;
  final int cloud;
  final List<int> sea;
  final List<int> waves;
  final double underwaterAlpha;
}

/// 스테이지 → 해역 배경, 해역이 바뀌면 `fx_map.backgroundFadeMs` 동안 색을 섞는다 (render-regions 규칙 1~3).
/// 해역은 `regions.regionAt(stage)` — 무한 항해 반복(loopStages)까지 테이블이 정한다.
class Backdrop {
  Backdrop(this._fx, this._regions) {
    _current = _prev = paletteOf(backgroundFor(1));
    _fadeAge = _fx.backgroundFadeMs;
  }

  final FxMapTable _fx;
  final RegionsTable _regions;
  final Map<String, BackgroundPalette> _palettes = {};
  late BackgroundPalette _current;
  late BackgroundPalette _prev;
  String _currentId = '';
  double _fadeAge = 0;

  String backgroundFor(int stage) => _regions.regionAt(stage).background;

  /// 해역 배경음 id (regions.json bgm).
  String bgmFor(int stage) => _regions.regionAt(stage).bgm;

  BackgroundPalette paletteOf(String id) => _palettes[id] ??= BackgroundPalette.fromJson(
    _fx.backgrounds[id] ?? _fx.backgrounds[_fx.backgroundDefault]!,
  );

  /// 프레임의 스테이지를 알린다. 해역이 바뀌면 섞기를 시작하고 true.
  bool setStage(int stage) {
    final id = backgroundFor(stage);
    if (id == _currentId) return false;
    final first = _currentId.isEmpty;
    _currentId = id;
    _prev = _current;
    _current = paletteOf(id);
    _fadeAge = first ? _fx.backgroundFadeMs : 0;
    return true;
  }

  void update(double dtMs) {
    if (_fadeAge < _fx.backgroundFadeMs) _fadeAge += dtMs;
  }

  double get _t => _fx.backgroundFadeMs <= 0 ? 1 : (_fadeAge / _fx.backgroundFadeMs).clamp(0.0, 1.0);

  /// 하늘 띠 [i]번(0 = 맨 위).
  int sky(int i) => _mix(_prev.sky[i], _current.sky[i]);
  int sea(int i) => _mix(_prev.sea[i], _current.sea[i]);
  int wave(int i) => _mix(_prev.waves[i], _current.waves[i]);
  int get cloud => _mix(_prev.cloud, _current.cloud);

  /// 지금 해역의 수중 색조 세기 (fx_map `backgrounds.<id>.underwaterAlpha`, 없으면 0.45).
  double get underwaterAlpha => _current.underwaterAlpha;
  int get skyBands => _current.sky.length;
  int get seaBands => _current.sea.length;

  int _mix(int a, int b) {
    final t = _t;
    if (t >= 1) return b;
    int ch(int shift) => (((a >> shift) & 0xFF) + ((((b >> shift) & 0xFF) - ((a >> shift) & 0xFF)) * t)).round();
    return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }
}
