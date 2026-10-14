import 'dart:convert';

import 'package:game_data/game_data.dart';

/// 해역 배경 한 벌 (아트 전 플레이스홀더): 하늘·바다·깊은 바다 색 + 원경 장식.
class BackgroundPalette {
  BackgroundPalette.fromJson(JsonReader j)
    : sky = parseArgb(j.str('sky'), '${j.path}.sky'),
      sea = parseArgb(j.str('sea'), '${j.path}.sea'),
      deep = parseArgb(j.str('deep'), '${j.path}.deep'),
      decor = j.str('decor'),
      decorColor = parseArgb(j.str('decorColor'), '${j.path}.decorColor');

  final int sky;
  final int sea;
  final int deep;

  /// `islands` | `clouds` | `icebergs` | `smoke` | `none` | `fog`.
  final String decor;
  final int decorColor;
}

/// 스테이지 → 해역 배경, 해역이 바뀌면 `fx_map.backgroundFadeMs` 동안 색을 섞는다 (docs/specs/render-regions.md 규칙 1~3).
class Backdrop {
  Backdrop(this._fx, String regionsJson) : _regions = _parse(regionsJson) {
    _current = _prev = paletteOf(backgroundFor(1));
    _fadeAge = _fx.backgroundFadeMs;
  }

  final FxMapTable _fx;

  /// (fromStage, background, bgm) — fromStage 오름차순.
  final List<(int, String, String?)> _regions;
  final Map<String, BackgroundPalette> _palettes = {};
  late BackgroundPalette _current;
  late BackgroundPalette _prev;
  String _currentId = '';
  double _fadeAge = 0;

  static List<(int, String, String?)> _parse(String json) {
    final root = jsonDecode(json) as Map<String, dynamic>;
    final list = [
      for (final r in (root['regions'] as List? ?? const []).cast<Map<String, dynamic>>())
        ((r['fromStage'] as num).toInt(), r['background'] as String, r['bgm'] as String?),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return list;
  }

  String backgroundFor(int stage) {
    var id = _fx.backgroundDefault;
    for (final (from, bg, _) in _regions) {
      if (stage >= from) id = bg;
    }
    return id;
  }

  /// 해역 배경음 id (regions.json bgm). 없으면 null.
  String? bgmFor(int stage) {
    String? id;
    for (final (from, _, bgm) in _regions) {
      if (stage >= from) id = bgm;
    }
    return id;
  }

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

  int get sky => _mix(_prev.sky, _current.sky);
  int get sea => _mix(_prev.sea, _current.sea);
  int get deep => _mix(_prev.deep, _current.deep);
  int get decorColor => _mix(_prev.decorColor, _current.decorColor);

  /// 장식은 섞지 않고 절반에서 바꾼다.
  String get decor => _t < 0.5 ? _prev.decor : _current.decor;

  int _mix(int a, int b) {
    final t = _t;
    if (t >= 1) return b;
    int ch(int shift) => (((a >> shift) & 0xFF) + ((((b >> shift) & 0xFF) - ((a >> shift) & 0xFF)) * t)).round();
    return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }
}
