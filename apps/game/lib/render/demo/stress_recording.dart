import 'package:game_core/game_core.dart';

/// 실기기 성능 측정용 부하 장면 (docs/specs/render-perf.md 규칙 2). 무작위 없이 코드로 만들어 기기마다 같은 장면이다.
///
/// - 적 27마리(물위 18·공중 6·물속 3)가 항상 화면 안(x 72~300)에서 왼쪽으로 흐른다.
/// - 10틱(0.5초)마다 투척 범위 공격이 4마리를 잡는다(치명타·동시 처치·히트스톱 2틱). 처치된 자리는 새 id로 다시 채운다.
/// - 4틱마다 직사, 6틱마다 관통 피격. 105틱에 궁극기(히트스톱 3틱). 200틱(10초) 뒤 반복.
List<RecordedTick> stressRecording() => _StressBuilder().build();

class _Slot {
  _Slot(this.id, this.index);

  int id;
  final int index;
  int phase = 0;

  String get layer => switch (index % _perGroup) {
    < 6 => 'surface',
    < 8 => 'air',
    _ => 'underwater',
  };

  static const _perGroup = 9;
}

class _StressBuilder {
  static const _ticks = 200;
  static const _enemies = 27;
  static const _laneLeft = 72;
  static const _laneWidth = 228;
  static const _aoeEvery = 10;
  static const _aoeOffset = 5;
  static const _aoeTargets = 4;
  static const _ultimateTick = 105;
  static const _multiKillStop = 2;
  static const _ultimateStop = 3;
  static const _kinds = ['crab', 'jelly', 'fish', 'puffer', 'urchin'];
  static final _shipHp = BigNum.from(10000);

  final List<_Slot> _slots = [for (var i = 0; i < _enemies; i++) _Slot(i + 1, i)..phase = i * 17 % _laneWidth];
  late int _nextId = _enemies + 1;
  final _out = <RecordedTick>[];

  double _x(_Slot s, int t) => (_laneLeft + (s.phase - t) % _laneWidth).toDouble();

  double _y(_Slot s) => switch (s.layer) {
    'air' => 44.0 + s.index % 3 * 4,
    'underwater' => 124.0 + s.index % 3 * 3,
    _ => 100.0 + (s.index * 5 % 15 - 7),
  };

  List<EnemyView> _enemyViews(int t) => [
    for (final s in _slots)
      EnemyView(
        id: s.id,
        kind: s.layer == 'air' ? 'gull' : _kinds[s.index % _kinds.length],
        x: _x(s, t),
        y: _y(s),
        hpRatio: 1 - (t + s.index * 3) % 20 / 25,
        layer: s.layer,
      ),
  ];

  List<FleetSlot> _fleet(int t) => [
    FleetSlot(crewId: 'octo', cooldown: (_aoeEvery - (t - _aoeOffset) % _aoeEvery) / _aoeEvery),
    FleetSlot(crewId: 'pang', cooldown: (4 - t % 4) / 4),
    FleetSlot(crewId: 'starry', cooldown: (6 - t % 6) / 6),
    const FleetSlot(crewId: 'crabs', cooldown: 0.5),
  ];

  RecordedTick _frame(int t, List<GameEvent> events, {int hitStop = 0, List<EnemyView>? enemies}) => RecordedTick(
    BattleView(
      tick: t,
      shipHp: _shipHp,
      shipHpMax: _shipHp,
      enemies: enemies ?? _enemyViews(t),
      fleet: _fleet(t),
      captainId: 'octo',
      hitStopTicks: hitStop,
    ),
    events,
  );

  List<RecordedTick> build() {
    for (var t = 0; t < _ticks; t++) {
      final events = <GameEvent>[];
      var stop = 0;
      if (t % 4 == 0) _single(events, t, 'direct', 'pang', t * 7 % _enemies);
      if (t % 6 == 3) _single(events, t, 'pierce', 'starry', t * 11 % _enemies);
      if (t % _aoeEvery == _aoeOffset) {
        _aoe(events, t);
        events.add(HitStop(t, ticks: _multiKillStop, reason: 'multiKill4'));
        stop = _multiKillStop;
      }
      if (t == _ultimateTick) {
        events
          ..add(const UltimateCast(_ultimateTick, crewId: 'octo', ultimateId: 'ult_cannon_rain'))
          ..add(const HitStop(_ultimateTick, ticks: _ultimateStop, reason: 'ultimate'));
        stop = _ultimateStop;
      }
      final frame = _frame(t, events);
      _out.add(frame);
      // 히트스톱: 엔진처럼 같은 위치 프레임을 hitStopTicks를 줄여 가며 낸다.
      for (var k = stop; k > 0; k--) {
        _out.add(_frame(t, const [], hitStop: k, enemies: frame.frame.enemies));
      }
    }
    return _out;
  }

  void _single(List<GameEvent> events, int t, String family, String crew, int slot) {
    final s = _slots[slot];
    final x = _x(s, t);
    events
      ..add(AttackFired(t, crewId: crew, family: family, targetIds: [s.id], x: x, y: _y(s)))
      ..add(Damage(t, targetId: s.id, amount: BigNum.from(40 + slot), crewId: crew));
  }

  void _aoe(List<GameEvent> events, int t) {
    final wave = t ~/ _aoeEvery;
    final targets = [for (var k = 0; k < _aoeTargets; k++) _slots[(wave * _aoeTargets + k) % _enemies]];
    var cx = 0.0;
    var cy = 0.0;
    for (final s in targets) {
      cx += _x(s, t) / _aoeTargets;
      cy += _y(s) / _aoeTargets;
    }
    events.add(AttackFired(t, crewId: 'octo', family: 'lob', targetIds: [for (final s in targets) s.id], x: cx, y: cy));
    var total = BigNum.zero;
    for (var k = 0; k < targets.length; k++) {
      final amount = BigNum.from(120 + 15 * k);
      total = total + amount;
      events.add(Damage(t, targetId: targets[k].id, amount: amount, crit: k == 0 && wave.isEven, crewId: 'octo'));
    }
    events.add(AoeDamageSum(t, total: total, x: cx, y: cy));
    for (final s in targets) {
      events.add(Kill(t, targetId: s.id, gold: BigNum.from(12), x: _x(s, t), y: _y(s)));
      // 같은 칸을 반대편에서 새 적으로 채운다 → 화면 안 적 수가 줄지 않는다.
      s
        ..id = _nextId++
        ..phase = (s.phase + _laneWidth ~/ 2) % _laneWidth;
    }
    events.add(MultiKill(t, count: _aoeTargets));
  }
}
