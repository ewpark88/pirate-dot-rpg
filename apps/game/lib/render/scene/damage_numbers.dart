import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/fx/pool.dart';
import 'package:pirate_dot/render/fx/transients.dart';

export 'package:pirate_dot/render/fx/transients.dart' show DamageKind;

/// 떠오르는 데미지 숫자 하나. [text]가 바뀌면 [version]이 올라 그리는 쪽이 다시 배치한다.
class DamageNumber {
  BigNum amount = BigNum.zero;
  String text = '';
  int version = 0;
  DamageKind kind = DamageKind.normal;
  double x = 0;
  double y = 0;
  double ageMs = 0;

  /// 그리는 쪽이 붙여 두는 캐시(TextPainter 등). 풀과 함께 재사용된다.
  Object? cache;

  void _setAmount(BigNum value) {
    amount = value;
    text = value.format();
    version++;
  }
}

/// 데미지 숫자 묶음. 상한(juice limits.damageNumbers)을 넘으면 가장 오래된 둘을 하나로 합친다 → 합계 보존.
class DamageNumbers {
  DamageNumbers(this.spec, int capacity) : pool = Pool(capacity, DamageNumber.new);

  final DamageNumberSpec spec;
  final Pool<DamageNumber> pool;

  List<DamageNumber> get active => pool.active;

  void add(BigNum amount, double x, double y, DamageKind kind) {
    final list = pool.active;
    if (list.length >= pool.capacity) {
      final oldest = list[0];
      final next = list[1].._setAmount(list[1].amount + oldest.amount);
      if (oldest.kind == DamageKind.sum || oldest.kind == DamageKind.crit) next.kind = oldest.kind;
      pool.release(oldest);
    }
    pool.obtain()
      .._setAmount(amount)
      ..kind = kind
      ..x = x
      ..y = y
      ..ageMs = 0;
  }

  void update(double dtMs) {
    for (final n in pool.active) {
      n.ageMs += dtMs;
    }
    pool.releaseWhere(_expired);
  }

  // 메서드 tear-off는 부를 때마다 클로저를 만든다 → 필드에 한 번만 만들어 둔다(프레임당 할당 0).
  // ignore: prefer_function_declarations_over_variables
  late final bool Function(DamageNumber) _expired = (n) => n.ageMs >= spec.lifeMs;

  /// 숫자 [n]의 지금 그리기 위치 (위로 떠오르고, 치명타는 한 번 튄다).
  double riseOf(DamageNumber n) {
    final t = (n.ageMs / spec.lifeMs).clamp(0.0, 1.0);
    var dy = spec.risePx * t;
    if (n.kind == DamageKind.crit && t < _bounceEnd) {
      final b = t / _bounceEnd;
      dy += spec.critBouncePx * 4 * b * (1 - b);
    }
    return dy;
  }

  static const _bounceEnd = 0.35;

  double scaleOf(DamageNumber n) => n.kind == DamageKind.normal ? spec.normalScale : spec.critScale;

  int colorOf(DamageNumber n) => switch (n.kind) {
    DamageKind.normal => spec.normalColor,
    DamageKind.crit => spec.critColor,
    DamageKind.sum => spec.sumColor,
  };

  void clear() => pool.clear();
}
