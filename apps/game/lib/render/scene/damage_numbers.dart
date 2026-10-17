import 'dart:math' as math;

import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/fx/pool.dart';
import 'package:pirate_dot/render/fx/transients.dart';
import 'package:pirate_dot/render/replay/recording_player.dart' show EnemyPose;

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

  /// 합치기 기준(적 id). 음수면 합치지 않는다(범위 합산 등).
  int key = -1;

  /// 따라갈 적 id(-1 = 제자리) — 맞은 적이 움직여도(보스 돌진·호 왕복) 숫자가 붙어 간다(S1 '숫자가 보스를 따라가야'),
  /// [ox]·[oy] = 생길 때 그 적과의 차이(쌓기 줄 포함). 적이 사라지면 그 자리에 남아 마저 떠오른다.
  int follow = -1;
  double ox = 0;
  double oy = 0;

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
  DamageNumbers(this.spec, int capacity, {required this.mergeMs, required this.stackRows})
    : pool = Pool(capacity, DamageNumber.new);

  /// juice damageNumber.mergeMs: 이 시간 안의 같은 적·같은 종류 피해는 숫자 하나로 합친다(숫자 더미 방지).
  final double mergeMs;
  late final double _merge = math.max(mergeMs, 300);

  /// 화면에 동시에 띄우는 숫자 최대(작은 보통 숫자부터 생략).
  int screenCap = 12;

  /// juice damageNumber.stackRows: 겹치는 숫자를 위로 비켜 쌓는 최대 줄 수. 넘치면 맨 위 숫자에 합친다.
  final int stackRows;

  final DamageNumberSpec spec;
  final Pool<DamageNumber> pool;

  List<DamageNumber> get active => pool.active;

  /// 숫자 하나를 띄운다 (platform E8 '숫자가 쌓여 읽히지 않음' 대책, 기준 gif처럼 읽히게):
  /// 1. 같은 적([key])·같은 종류가 [mergeMs] 안이면 그 숫자에 더하고 다시 튀어 오르게.
  /// 2. 지금 그려지는 숫자와 겹치면 한 줄씩 위로 비켜 쌓는다(최대 [stackRows]줄), 넘치면 맨 위 숫자에 합친다.
  /// 3. 동시 상한을 넘으면 가장 오래된 둘을 하나로 합친다 → 합계 보존.
  /// [on] = 맞은 적의 지금 그림 자리 — 주면 숫자가 그 적을 따라간다.
  void add(BigNum amount, double x, double y, DamageKind kind, {int key = -1, EnemyPose? on}) {
    final list = pool.active;
    if (key >= 0) {
      for (final n in list) {
        if (n.key == key && n.kind == kind && n.ageMs < _merge) {
          _renew(n.._setAmount(n.amount + amount));
          return;
        }
      }
    }
    final scale = _scaleOf(kind);
    final line = lineHeight(scale) * tall;
    final width = textWidth(amount.format(), scale) * wide;
    var top = y;
    DamageNumber? blocker;
    for (var row = 0; row < stackRows; row++) {
      blocker = _overlapping(x, top, line, width);
      if (blocker == null) break;
      top = math.min(top, blocker.y - riseOf(blocker)) - line;
    }
    if (blocker != null) {
      // 종류(크기)는 그대로 둔다 — 일반 숫자가 치명타 크기로 커지면 옆 줄과 다시 겹친다. 합계는 보존.
      _renew(blocker.._setAmount(blocker.amount + amount));
      return;
    }
    // 화면 동시 숫자 상한(디자인 개편 — 쿵푸할매처럼 숫자는 적고 크게): 넘치면 가장 작은 보통 숫자를 뺀다(새 것이 더 작으면 새 것을 생략).
    if (list.length >= screenCap) {
      DamageNumber? smallest;
      for (final n in list) {
        if (n.kind != DamageKind.normal) continue;
        if (smallest == null || n.amount < smallest.amount) smallest = n;
      }
      if (smallest == null || (kind == DamageKind.normal && amount <= smallest.amount)) return;
      pool.release(smallest);
    }
    if (list.length >= pool.capacity) {
      final oldest = list[0];
      final next = list[1].._setAmount(list[1].amount + oldest.amount);
      if (oldest.kind == DamageKind.sum || oldest.kind == DamageKind.crit) next.kind = oldest.kind;
      pool.release(oldest);
    }
    pool.obtain()
      .._setAmount(amount)
      ..kind = kind
      ..key = key
      ..x = x
      ..y = top
      ..ageMs = 0
      ..follow = on?.id ?? -1
      ..ox = on == null ? 0 : x - on.drawX
      ..oy = on == null ? 0 : top - on.drawY;
  }

  /// 따라가는 숫자를 대상의 지금 자리로(매 프레임). 대상이 없으면(죽음) 그 자리에 남는다.
  void track(EnemyPose? Function(int id) poseOf) {
    for (final n in pool.active) {
      if (n.follow < 0) continue;
      final p = poseOf(n.follow);
      if (p == null) {
        n.follow = -1;
        continue;
      }
      n
        ..x = p.drawX + n.ox
        ..y = p.drawY + n.oy;
    }
    _separate();
  }

  /// 따라가다 겹친 숫자(탑 실기기 '87.1.65K'): 나중 숫자를 앞 숫자 바로 위 줄로 비킨다(따라가는 차이도 같이).
  void _separate() {
    final list = pool.active;
    for (var j = 1; j < list.length; j++) {
      final b = list[j];
      final line = lineHeight(scaleOf(b)) * tall;
      final width = textWidth(b.text, scaleOf(b)) * wide;
      for (var i = 0; i < j; i++) {
        final a = list[i];
        final wa = textWidth(a.text, scaleOf(a)) * wide;
        final top = a.y - riseOf(a);
        final yb = b.y - riseOf(b);
        if ((a.x - b.x).abs() >= (wa + width) / 2 + _gapX || (top - yb).abs() >= line) continue;
        final dy = top - line - yb;
        b
          ..y += dy
          ..oy += dy;
      }
    }
  }

  /// 합친 숫자를 새로 띄운다: 지금 그려지는 높이를 새 기준으로 삼아(아래로 떨어져 위 숫자와 겹치지 않게) 수명만 처음부터.
  void _renew(DamageNumber n) {
    final rise = riseOf(n);
    n
      ..y = n.y - rise
      ..oy = n.oy - rise
      ..ageMs = 0;
  }

  /// 글자 줄 높이 (3×5 도트 글리프 × 배율 + 외곽선·여백).
  static double lineHeight(double scale) => 5 * scale + 3;

  /// 실제 그리는 글자가 도트 글자보다 몇 배 높고·넓은지(테두리 숫자 아틀라스면 HudPainter가 2.3·1.5로 넣는다).
  /// 쌓기 간격·겹침 판정에 곱한다 — 안 곱하면 큰 글자가 도트 줄 간격으로 쌓여 한 글자씩 세로로 겹쳐 보였다(S5 실기기).
  double tall = 1;
  double wide = 1;

  /// 글자 폭 (3×5 글리프 4칸 간격 × 배율, pixel_glyphs와 같은 계산).
  static double textWidth(String text, double scale) => text.length * 4 * scale;

  /// 가로로 숫자 사이에 둘 최소 틈.
  static const _gapX = 2.0;

  /// (x, y)에 폭 [width]·줄 높이 [line]인 숫자를 놓으면 겹치는 숫자 (가운데 정렬 기준 글자 상자끼리).
  DamageNumber? _overlapping(double x, double y, double line, double width) {
    for (final n in pool.active) {
      final w = textWidth(n.text, scaleOf(n)) * wide;
      if ((n.x - x).abs() < (w + width) / 2 + _gapX && ((n.y - riseOf(n)) - y).abs() < line) return n;
    }
    return null;
  }

  // 배 피해는 작게(S1 — 배 위 빨간 작은 숫자): 일반 크기.
  double _scaleOf(DamageKind kind) =>
      kind == DamageKind.normal || kind == DamageKind.ship ? spec.normalScale : spec.critScale;

  /// [poseOf]가 있으면 따라가는 숫자를 대상 자리로 옮긴다([track]).
  void update(double dtMs, [EnemyPose? Function(int id)? poseOf]) {
    for (final n in pool.active) {
      n.ageMs += dtMs;
    }
    pool.releaseWhere(_expired);
    if (poseOf != null) track(poseOf);
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

  double scaleOf(DamageNumber n) => _scaleOf(n.kind);

  int colorOf(DamageNumber n) => switch (n.kind) {
    DamageKind.normal => spec.normalColor,
    DamageKind.crit => spec.critColor,
    DamageKind.sum => spec.sumColor,
    DamageKind.ship => _shipColor,
  };

  static const _shipColor = 0xFFFF5A5A;

  void clear() => pool.clear();
}
