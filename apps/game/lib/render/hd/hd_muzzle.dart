import 'dart:ui';

import 'package:pirate_dot/render/hd/hd_species.dart';

/// HD 원거리 적 발사 빛(S1 요청 '쏘는 부위가 밝아짐', S5 HdSpecies.muzzle): 적이 쏜 순간(EnemyFired) 그 종의 쏘는 부위
/// (부리·가시 끝·입 — r 배수, 왼쪽 보기 기준)에서 0.25초 노란·흰 빛이 번쩍 부풀었다 사라진다. muzzle 없는 종은 몸 가운데.
/// 엔진에 '쏘기 직전' 예고가 없어 발사 순간에 맞춘다. 전장 좌표.
class HdMuzzle {
  final Map<int, double> _fired = {};
  final List<(double, double, double)> _now = []; // x, y, 나이 0~1
  final _glow = Paint()
    ..isAntiAlias = true
    ..blendMode = BlendMode.plus;
  static const _ms = 250.0;

  /// EventDirectorTop: 적 [id]가 쐈다.
  void fired(int id, double now) {
    if (_fired.length > 64) _fired.removeWhere((_, at) => now - at > _ms);
    _fired[id] = now;
  }

  /// TopEnemies: HD로 그린 적마다 — 번쩍이는 중이면 빛 자리를 모은다. [world] = 칸 크기(단위), [right] = 뒤집어 오른쪽 봄.
  void collect(int id, String kind, double x, double y, double world, {required bool right, required double now}) {
    final at = _fired[id];
    if (at == null || now - at > _ms) return;
    final sp = hdEnemies[kind];
    if (sp == null) return;
    final r = world / (2 * sp.extent);
    final m = sp.muzzle ?? Offset.zero;
    _now.add((x + (right ? -m.dx : m.dx) * r, y + m.dy * r, (now - at) / _ms));
  }

  /// 이번 프레임에 모인 빛 수(테스트).
  int get pending => _now.length;

  /// 적을 다 그린 뒤 한 번.
  void paint(Canvas c) {
    for (final (x, y, t) in _now) {
      final s = t < 0.3 ? t / 0.3 : 1 - (t - 0.3) / 0.7;
      _glow.color = Color.fromRGBO(255, 210, 90, 0.55 * s);
      c.drawCircle(Offset(x, y), 3 + 4 * s, _glow);
      _glow.color = Color.fromRGBO(255, 255, 255, 0.9 * s);
      c.drawCircle(Offset(x, y), 1.2 + 1.8 * s, _glow);
    }
    _now.clear();
  }
}
