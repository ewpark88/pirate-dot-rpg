import 'package:game_cli/src/sim/sim_check.dart';
import 'package:game_cli/src/sim/sim_result.dart';
import 'package:game_data/game_data.dart';

/// 3자 균형 경계(잡몹·보스·배 — 사용자 상시 지시 2026-10-17 '나중에 붕괴되면 고치기 더 어렵다'): `meta.sim.guard`의 지표마다
/// 가상 플레이어 중앙값이 [min, max] 안인가. 목표(meta.sim.targets)보다 넓은 '붕괴 경계'라 시드 흔들림엔 안 걸리고,
/// 누가 수치를 바꿔 균형이 무너지면 check가 빨개진다. 키는 judge()의 지표 키 + 'waveSecAll'(한 파 소요 전체).
typedef GuardLine = ({String key, String label, double? value, double min, double max, bool ok});

List<GuardLine> balanceGuard(GameTables t, List<SimCheck> checks, List<SimResult> results) {
  final sim = t.meta.raw.obj('sim');
  if (!sim.has('guard')) return const [];
  final g = sim.obj('guard');
  final byKey = {for (final c in checks) c.key: c};
  double? waveSec() {
    final xs = [
      for (final r in results)
        if (r.waveSecAll > 0) r.waveSecAll,
    ]..sort();
    return xs.isEmpty ? null : xs[xs.length ~/ 2];
  }

  return [
    for (final key in g.raw.keys)
      () {
        final r = g.obj(key);
        final value = key == 'waveSecAll' ? waveSec() : byKey[key]?.value;
        final label = key == 'waveSecAll' ? '잡몹 한 파 소요(전체)' : byKey[key]?.label ?? key;
        final (min, max) = (r.number('min'), r.number('max'));
        return (
          key: key,
          label: label,
          value: value,
          min: min,
          max: max,
          ok: value != null && value >= min && value <= max,
        );
      }(),
  ];
}

/// check에 보이는 표 — 벗어난 줄은 ✗.
String formatGuard(List<GuardLine> lines) => [
  '3자 균형 경계 (meta.sim.guard, 가상 플레이어 중앙값):',
  for (final l in lines)
    '  ${l.ok ? '✓' : '✗'} ${l.label}: ${l.value?.toStringAsFixed(1) ?? '미도달'} (경계 ${l.min}~${l.max})',
].join('\n');
