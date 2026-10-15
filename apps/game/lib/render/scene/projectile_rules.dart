import 'package:game_data/game_data.dart';

/// 계열별 발사체 규칙 (fx_map projectiles.<계열>, 사용자 지시 '폭탄 퀄리티'). 한 번 읽어 캐시한다.
class ProjectileRules {
  ProjectileRules(this._fx, {required this.fallbackMs});

  final FxMapTable _fx;

  /// flightMs가 없는 계열의 비행 시간.
  final double fallbackMs;

  late final JsonReader _table = _fx.raw.obj('projectiles');
  final Map<String, double> _flight = {};
  final Map<String, bool> _single = {};

  JsonReader _of(String family) {
    final key = _fx.projectileAliases[family] ?? family;
    return _table.raw.containsKey(key) ? _table.obj(key) : _table.obj(_fx.projectileDefault);
  }

  /// 날아가는 시간(ms). 별칭(support → shock)을 풀고, 없으면 기본 계열.
  double flightMs(String family) => _flight[family] ??= _of(family).numberOr('flightMs', fallbackMs);

  /// 범위 계열(투척·수중)은 조준점에 한 발 — 대상마다 따로 날리면 같은 자리에 포탄이 겹친다.
  bool single(String family) => _single[family] ??= (_of(family).raw['single'] ?? false) == true;
}
