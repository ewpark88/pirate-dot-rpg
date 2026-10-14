import 'dart:convert';

import 'package:game_data/game_data.dart';

/// 적 종류 → 역할 → 플레이스홀더 색·크기·투명도 (docs/specs/render-m3-fx.md 규칙 6).
///
/// 역할은 `regions.json enemies[].role`을 원문에서 직접 읽는다(필드가 없으면 공중 줄이면 air, 아니면 basic).
/// `_small`로 끝나는 종류(분열된 작은 적)는 `fx_map.enemySmallSize`.
class EnemyLooks {
  EnemyLooks._(this._fx, this._roleByKind);

  factory EnemyLooks.fromTables(GameTables tables) => EnemyLooks.fromRegionsJson(tables.fxMap, rawTables['regions']!);

  factory EnemyLooks.fromRegionsJson(FxMapTable fx, String regionsJson) {
    final root = jsonDecode(regionsJson) as Map<String, dynamic>;
    final roles = <String, String>{};
    for (final e in (root['enemies'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final role = e['role'] as String? ?? (e['layer'] == 'air' ? 'air' : 'basic');
      roles[e['id'] as String] = role;
    }
    return EnemyLooks._(fx, roles);
  }

  final FxMapTable _fx;
  final Map<String, String> _roleByKind;
  final Map<String, EnemyLook> _cache = {};

  static const _smallSuffix = '_small';

  Iterable<String> get kinds => _roleByKind.keys;

  EnemyLook _lookOf(String kind) => _cache[kind] ??= _fx.enemyLook[_roleByKind[kind]] ?? _fx.enemyLook['basic']!;

  int colorOf(String kind) => _lookOf(kind).color;
  double alphaOf(String kind) => _lookOf(kind).alpha;
  double sizeOf(String kind) => kind.endsWith(_smallSuffix) ? _fx.enemySmallSize : _lookOf(kind).size;
}
