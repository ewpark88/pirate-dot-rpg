import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 이벤트 → 효과음·배경음 (docs/specs/render-audio.md). 소리는 연출일 뿐이라 결과를 바꾸지 않는다.
///
/// - sfx id는 `fx_map.json events[].sfx`. 타격음(damage·critHit)은 변형 `juice.sound.hitVariants`개와 피치 ±`pitchJitter`,
///   고르는 값은 (틱, 대상 id)에서 계산 — 같은 기록이면 같은 소리 순서.
/// - 같은 id는 `fx_map.audio.sfxMinGapMs` 안에 다시 부르지 않고, 한 화면 프레임에 `sfxMaxPerFrame`개까지.
class SoundDirector {
  SoundDirector(this._fx, JuiceTable juice)
    : _minGapMs = _fx.audio.number('sfxMinGapMs'),
      _maxPerFrame = _fx.audio.integer('sfxMaxPerFrame'),
      _variants = juice.raw.obj('sound').integer('hitVariants'),
      _jitter = juice.raw.obj('sound').number('pitchJitter');

  final FxMapTable _fx;
  final double _minGapMs;
  final int _maxPerFrame;
  final int _variants;
  final double _jitter;

  /// null이면 무음 (테스트·골든).
  AudioPort? audio;

  /// 운영자 패널용: 최근 효과음 id (오래된 것이 앞).
  final List<String> log = [];
  static const _logMax = 20;

  final Map<String, double> _lastMs = {};
  double _frameClock = -1;
  int _thisFrame = 0;
  String? _bgm;

  static const _hitEvents = {'damage', 'critHit'};

  // 결정론적 흩뿌림용 소수.
  static const _primeTick = 73856093;
  static const _primeSalt = 19349663;
  static const _pitchSteps = 200;

  double _lastThud = -1000000000;

  /// 타격감 v3 저음 '쿵' 층: 치명 타격음을 피치를 낮춰(0.55, 큰 것 0.42) 겹친다 — 무료 효과음 그대로. 120ms에 한 번.
  void thud(double clockMs, {required bool big}) {
    final a = audio;
    if (a == null || clockMs - _lastThud < 120) return;
    _lastThud = clockMs;
    a.playSfx('hit_crit', pitch: big ? 0.42 : 0.55);
  }

  /// [event](fx_map events 키)의 효과음. [clockMs]는 장면 시계, [tick]·[salt]는 변형·피치를 고르는 값.
  void sfx(String event, {required double clockMs, int tick = 0, int salt = 0}) {
    final a = audio;
    if (a == null) return;
    final id = _fx.events[event]?.strOrNull('sfx');
    if (id == null) return;
    if (clockMs != _frameClock) {
      _frameClock = clockMs;
      _thisFrame = 0;
    }
    if (_thisFrame >= _maxPerFrame) return;
    final last = _lastMs[id];
    if (last != null && clockMs - last < _minGapMs) return;
    var variant = 0;
    var pitch = 1.0;
    if (_hitEvents.contains(event)) {
      final h = ((tick * _primeTick) ^ (salt * _primeSalt)) & 0x7FFFFFFF;
      variant = h % _variants;
      pitch = 1 + _jitter * ((h ~/ _variants % (_pitchSteps + 1)) / (_pitchSteps / 2) - 1);
    }
    a.playSfx(id, variant: variant, pitch: pitch);
    _lastMs[id] = clockMs;
    _thisFrame++;
    log.add(id);
    if (log.length > _logMax) log.removeAt(0);
  }

  /// 해역 배경음. 같은 곡이면 그대로.
  void bgm(String? id) {
    final a = audio;
    if (a == null || id == null || id == _bgm) return;
    _bgm = id;
    a.playBgm(id);
  }
}
