import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

/// 이벤트 → 효과음·배경음 (docs/specs/render-audio.md). 소리는 연출일 뿐이라 결과를 바꾸지 않는다.
///
/// - sfx id는 `fx_map.json events[].sfx`. 타격음(damage·critHit)은 변형 `juice.sound.hitVariants`개와 피치 ±`pitchJitter`,
///   고르는 값은 (틱, 대상 id)에서 계산 — 같은 기록이면 같은 소리 순서.
/// - 같은 id는 `fx_map.audio.sfxMinGapMs` 안에 다시 부르지 않고, 한 화면 프레임에 `sfxMaxPerFrame`개까지.
/// - 초당 `sfxMaxPerSec`개 예산(S24 실측 오디오 CPU 56% — 신화 여럿이면 초당 수백 번 재생을 요청했다). 방치 중엔 [budgetScale]로 줄인다.
class SoundDirector {
  SoundDirector(this._fx, JuiceTable juice)
    : _minGapMs = _fx.audio.number('sfxMinGapMs'),
      _maxPerFrame = _fx.audio.integer('sfxMaxPerFrame'),
      _maxPerSec = _fx.audio.number('sfxMaxPerSec'),
      _variants = juice.raw.obj('sound').integer('hitVariants'),
      _jitter = juice.raw.obj('sound').number('pitchJitter');

  final FxMapTable _fx;
  final double _minGapMs;
  final int _maxPerFrame;
  final double _maxPerSec;

  /// 초당 예산 배율 — BattleGame 방치(0.5)·어두운 화면(0.15).
  double budgetScale = 1;
  double _tokens = 4;
  double _tokenClock = 0;
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
    if (clockMs < _lastThud) _lastThud = -1000000000; // 장면 시계가 뒤로 갔다(S3 제안)
    if (a == null || clockMs - _lastThud < 120) return;
    _lastThud = clockMs;
    a.playSfx('hit_crit', pitch: big ? 0.42 : 0.55);
  }

  /// [event](fx_map events 키)의 효과음. [clockMs]는 장면 시계, [tick]·[salt]는 변형·피치를 고르는 값.
  void sfx(String event, {required double clockMs, int tick = 0, int salt = 0}) {
    final a = audio;
    if (a == null) return;
    final ev = _fx.events[event];
    final id = ev?.strOrNull('sfx');
    if (id == null) return;
    if (clockMs < _tokenClock) {
      // 장면 시계가 뒤로 갔다(장면을 새로 만들거나 기록을 처음부터) — 예전 '마지막 재생 시각'이 미래로 남아 효과음이 막히지 않게.
      _lastMs.clear();
      _lastThud = -1000000000;
      _tokenClock = clockMs;
      _tokens = 1;
    }
    if (clockMs != _frameClock) {
      _frameClock = clockMs;
      _thisFrame = 0;
    }
    if (_thisFrame >= _maxPerFrame) return;
    // 초당 예산: 시계만큼 채우고(최대 1/4초 분량 몰아치기), 한 번에 하나씩 쓴다.
    final rate = _maxPerSec * budgetScale / 1000;
    _tokens = (_tokens + (clockMs - _tokenClock).clamp(0, 1000) * rate).clamp(0, 1 + rate * 250);
    _tokenClock = clockMs;
    if (_tokens < 1) return;
    final last = _lastMs[id];
    if (last != null && clockMs - last < _minGapMs) return;
    var variant = 0;
    // 같은 음원을 음높이로 구분(사운드 점검 2026-10-17 — 새 이벤트는 자작 음원 재사용): events[].pitch, 기본 1.
    var pitch = ev != null && ev.has('pitch') ? ev.number('pitch') : 1.0;
    if (_hitEvents.contains(event)) {
      final h = ((tick * _primeTick) ^ (salt * _primeSalt)) & 0x7FFFFFFF;
      variant = h % _variants;
      pitch = 1 + _jitter * ((h ~/ _variants % (_pitchSteps + 1)) / (_pitchSteps / 2) - 1);
    }
    a.playSfx(id, variant: variant, pitch: pitch);
    _lastMs[id] = clockMs;
    _thisFrame++;
    _tokens -= 1;
    log.add(id);
    if (log.length > _logMax) log.removeAt(0);
  }

  double _lastTing = -1000000000;

  /// 치명 '쨍': 치명 타격음을 높게(1.7) 겹친다 — 90ms에 한 번.
  void ting(double clockMs) {
    if (clockMs < _lastTing) _lastTing = -1000000000;
    if (audio == null || clockMs - _lastTing < 90) return;
    _lastTing = clockMs;
    audio!.playSfx('hit_crit', pitch: 1.7);
  }

  /// 무리 처치 연쇄 '퍼퍼펑': pop을 [n]번 45ms 간격으로 음높이를 올리며(예산과 별개, 한 번에 최대 6).
  void chain(int n, double clockMs) {
    if (_chain.isNotEmpty) return; // 앞 연쇄가 끝나기 전엔 겹치지 않게
    for (var i = 0; i < n.clamp(0, 6); i++) {
      _chain.add((clockMs + i * 45, 0.9 + i * 0.09));
    }
  }

  final List<(double, double)> _chain = [];

  /// 장면 시계마다(BattleScene.update) — 때가 된 연쇄 소리를 낸다.
  void pump(double clockMs) {
    if (_chain.isNotEmpty && clockMs < _chain.first.$1 - 1000) _chain.clear(); // 시계가 뒤로
    while (_chain.isNotEmpty && _chain.first.$1 <= clockMs) {
      final (_, pitch) = _chain.removeAt(0);
      audio?.playSfx('pop', pitch: pitch);
      log.add('pop');
    }
  }

  /// 해역 배경음. 같은 곡이면 그대로. 피버 중이면 기억만 했다가 피버가 끝나면 튼다.
  void bgm(String? id) {
    _region = id;
    if (!_fever) _play(id);
  }

  /// 피버 전용 곡(사용자 피드백 #23): 켜면 [id](fx_map topEvents.fever.bgm), 끄면 해역 곡으로. 바꿀 때 어댑터가 페이드한다.
  void fever({required bool on, String? id}) {
    _fever = on && id != null;
    _play(_fever ? id : _region);
  }

  String? _region;
  bool _fever = false;

  void _play(String? id) {
    final a = audio;
    if (a == null || id == null || id == _bgm) return;
    _bgm = id;
    a.playBgm(id);
  }
}
