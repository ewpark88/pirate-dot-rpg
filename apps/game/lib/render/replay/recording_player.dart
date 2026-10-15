import 'package:game_core/game_core.dart';

/// 보간된 적 한 마리. 매 프레임 다시 채우므로 객체를 재사용한다.
class EnemyPose {
  int id = 0;
  String kind = '';
  String layer = 'surface';
  bool boss = false;
  double hpRatio = 1;

  /// 기절 중 (머리 위 별).
  bool stunned = false;

  /// 보호막 (청록 테두리)과 무한 항해 테두리 단계 0~3.
  bool shielded = false;
  int tier = 0;

  /// 감속·화상·취약 (전설 능력).
  bool slowed = false;
  bool burning = false;
  bool vulnerable = false;
  double x = 0;
  double y = 0;

  /// 타격감 오프셋(넉백)을 더한 그리기 위치와 흰색 번쩍임. 장면이 채운다.
  double drawX = 0;
  double drawY = 0;
  bool flash = false;

  /// 이동 방향 atan2(dy, dx) (탑다운 도트를 돌릴 때).
  double heading = 0;

  void _set(EnemyView v, double nx, double ny) {
    id = v.id;
    kind = v.kind;
    layer = v.layer;
    boss = v.boss;
    hpRatio = v.hpRatio;
    stunned = v.stunned;
    shielded = v.shielded;
    tier = v.tier;
    slowed = v.slowed;
    burning = v.burning;
    vulnerable = v.vulnerable;
    heading = v.heading;
    x = nx;
    y = ny;
    drawX = nx;
    drawY = ny;
    flash = false;
  }
}

/// 재생기가 틱 경계를 지날 때 부른다.
abstract interface class ReplayListener {
  /// 표시 시각이 [index]보다 lookahead만큼 앞일 때 (발사체를 미리 띄운다).
  void onAhead(RecordedTick tick, int index);

  /// 표시 시각이 [index]에 닿았을 때 (피격·처치 연출).
  void onNow(RecordedTick tick, int index);

  /// 반복 재생에서 처음으로 돌아갈 때.
  void onLoop();
}

/// 전투 기록을 시간에 맞춰 재생한다. Flame을 모르는 순수 Dart.
///
/// 위치는 "가상 인덱스"로 센다.
/// - 기록 모드: 고정 목록을 재생. 반복 재생이면 n, n+1 …이 다시 0, 1 …번 틱을 가리킨다.
/// - 라이브 모드: 엔진이 매 틱 [push]. 표시는 최신 틱보다 lookahead 뒤에서 기다리고,
///   [maxLagTicks]보다 더 뒤처지면 따라잡는다(건너뛴 틱의 이벤트도 모두 알린다).
/// 표시 시각은 [position], 이벤트를 미리 아는 시각은 [position] + lookahead.
class RecordingPlayer {
  RecordingPlayer(
    List<RecordedTick> ticks, {
    required this.tickMs,
    required this.lookaheadTicks,
    this.loop = true,
    this.listener,
  }) : assert(ticks.isNotEmpty, 'empty recording'),
       _ticks = ticks,
       live = false,
       maxLagTicks = 0 {
    _updatePoses();
  }

  RecordingPlayer.live({
    required this.tickMs,
    required this.lookaheadTicks,
    required this.maxLagTicks,
    this.listener,
  }) : _ticks = [],
       live = true,
       loop = false;

  final List<RecordedTick> _ticks;
  final double tickMs;
  final int lookaheadTicks;
  final bool loop;
  final bool live;

  /// 라이브 모드에서 표시가 lookahead보다 더 뒤처져도 되는 틱 수.
  final int maxLagTicks;
  ReplayListener? listener;

  double _position = 0;
  int _nextNow = 0;
  int _nextAhead = 0;

  /// 라이브 버퍼 첫 틱의 가상 인덱스.
  int _base = 0;

  final List<EnemyPose> poses = [];
  int poseCount = 0;

  /// 표시 시각 (가상 인덱스, 소수).
  double get position => _position;

  /// 버퍼에 남아 있는 틱 수.
  int get bufferedTicks => _ticks.length;

  bool get isEmpty => _ticks.isEmpty;

  /// 마지막 틱의 가상 인덱스.
  int get _last => _base + _ticks.length - 1;

  RecordedTick entryAt(int virtualIndex) => live ? _ticks[virtualIndex - _base] : _ticks[virtualIndex % _ticks.length];

  bool _has(int v) => live ? v >= _base && v <= _last : loop || (v >= 0 && v <= _last);

  /// 라이브 모드 입력: 엔진이 매 틱 frame=state.battle, events=이번 틱 이벤트로 부른다.
  void push(RecordedTick tick) {
    assert(live, 'push() is only for live mode');
    _ticks.add(tick);
    // 표시보다 충분히 뒤(발사체 진행률 계산 여유)는 버린다.
    final keepFrom = _position.floor() - _trimMargin;
    if (keepFrom - _base >= _trimBatch) {
      _ticks.removeRange(0, keepFrom - _base);
      _base = keepFrom;
    }
    if (_ticks.length == 1) _updatePoses();
  }

  static const _trimMargin = 8;
  static const _trimBatch = 16;

  /// 지금 구간이 히트스톱이면 true (다음 프레임이 멈춘 프레임).
  bool get inHitStop => _frozen(_position.floor());

  /// 구간 [i, i+1)이 멈춤인가. 엔진은 히트스톱 동안 같은 위치 프레임을 hitStopTicks>0으로 낸다.
  bool _frozen(int i) => _hasNext(i) && entryAt(i + 1).frame.hitStopTicks > 0;

  bool _hasNext(int i) => _has(i) && _has(i + 1);

  /// [a]~[b] 사이에서 멈추지 않은 구간 길이 (발사체 진행률 계산용).
  double motionBetween(double a, double b) {
    var sum = 0.0;
    var i = a.floor();
    while (i < b) {
      final lo = a > i ? a : i.toDouble();
      final hi = b < i + 1 ? b : (i + 1).toDouble();
      if (!_frozen(i)) sum += hi - lo;
      i++;
    }
    return sum;
  }

  /// 표시가 갈 수 있는 끝. 반복 재생이면 끝이 없다.
  double? get _limit {
    if (live) return (_last - lookaheadTicks).toDouble();
    return loop ? null : _last.toDouble();
  }

  /// [dtMs]만큼 재생한다. 배속은 지금 프레임의 `speed`.
  /// 처음 부르면 시작 시각(0과 lookahead까지)의 경계도 알린다.
  void advance(double dtMs) {
    if (_ticks.isEmpty) return;
    if (live) _catchUp();
    _fireCrossings();
    var remaining = dtMs;
    while (remaining > 0) {
      final limit = _limit;
      if (limit != null && _position >= limit) break;
      final i = _position.floor();
      final speed = entryAt(i).frame.speed;
      final msPerEntry = tickMs / (speed < 1 ? 1 : speed);
      var boundary = (i + 1).toDouble();
      if (limit != null && limit < boundary) boundary = limit;
      final toBoundary = (boundary - _position) * msPerEntry;
      if (remaining < toBoundary) {
        _position += remaining / msPerEntry;
        remaining = 0;
      } else {
        _position = boundary;
        remaining -= toBoundary;
        if (!live && loop && (i + 1) % _ticks.length == 0) listener?.onLoop();
      }
      _fireCrossings();
    }
    _updatePoses();
  }

  void _catchUp() {
    final target = (_last - lookaheadTicks - maxLagTicks).toDouble();
    if (_position < target) _position = target;
    if (_position < _base) _position = _base.toDouble();
  }

  void _fireCrossings() {
    final maxIndex = loop && !live ? null : _last;
    if (_nextNow < _base) _nextNow = _base;
    if (_nextAhead < _base) _nextAhead = _base;
    while (_nextNow <= _position && (maxIndex == null || _nextNow <= maxIndex)) {
      listener?.onNow(entryAt(_nextNow), _nextNow);
      _nextNow++;
    }
    final head = _position + lookaheadTicks;
    while (_nextAhead <= head && (maxIndex == null || _nextAhead <= maxIndex)) {
      listener?.onAhead(entryAt(_nextAhead), _nextAhead);
      _nextAhead++;
    }
  }

  void _updatePoses() {
    poseCount = 0;
    if (_ticks.isEmpty) return;
    final i = _position.floor();
    final t = _position - i;
    final a = entryAt(i).frame.enemies;
    final wraps = !live && loop && (i + 1) % _ticks.length == 0;
    final b = _hasNext(i) && !wraps ? entryAt(i + 1).frame.enemies : a;
    for (final e in a) {
      final n = _find(b, e.id) ?? e;
      if (poses.length <= poseCount) poses.add(EnemyPose());
      poses[poseCount++]._set(e, e.x + (n.x - e.x) * t, e.y + (n.y - e.y) * t);
    }
  }

  static EnemyView? _find(List<EnemyView> list, int id) {
    for (final e in list) {
      if (e.id == id) return e;
    }
    return null;
  }

  EnemyPose? poseOf(int id) {
    for (var k = 0; k < poseCount; k++) {
      if (poses[k].id == id) return poses[k];
    }
    return null;
  }

  /// 틱 [index] 프레임에서 적 [id]의 위치 (발사체 목표·숫자 위치). 범위 밖이면 null.
  EnemyView? enemyAt(int index, int id) => _has(index) ? _find(entryAt(index).frame.enemies, id) : null;
}
