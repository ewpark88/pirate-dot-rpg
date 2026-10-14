import 'package:game_cli/src/balance/crew_scores.dart';

/// 점수표를 마크다운으로 (레벨별 표 + 조합 요약). 비율은 같은 레벨 중앙값 대비.
String balanceMarkdown(BalanceReport r) {
  final b = StringBuffer()
    ..writeln('# 선원 균형 점수표 (설계서 4.8)')
    ..writeln()
    ..writeln('판정: ${r.passed ? '✓ 통과' : '✗ 실패'} · 허용 ±${(tolerance * 100).round()}% · 점수 = (무리전 + 보스전) / 2, 60초 피해')
    ..writeln();
  final levels = r.medians.keys.toList()..sort();
  for (final level in levels) {
    b
      ..writeln('## 레벨 $level (중앙값 ${_n(r.medians[level]!)})')
      ..writeln()
      ..writeln('| 선원 | 계열 | 무리전 A | 보스전 B | 점수 | 비율 | 판정 | 지원 환산 (자기 / 파트너 증가 / 배 보호) |')
      ..writeln('| --- | --- | ---: | ---: | ---: | ---: | :---: | --- |');
    final rows = r.crews.where((c) => c.level == level).toList()..sort((x, y) => y.ratio.compareTo(x.ratio));
    for (final c in rows) {
      final s = c.support;
      final sup = s == null ? '' : '${_n(s.own)} / ${_n(s.partnerUplift)} / ${_n(s.shipShield)}';
      b.writeln(
        '| ${c.id} | ${c.family} | ${_n(c.a)} | ${_n(c.b)} | ${_n(c.score)} | '
        '${c.ratio.toStringAsFixed(3)} | ${c.ok ? '✓' : '✗'} | $sup |',
      );
    }
    b.writeln();
  }
  if (r.combos.isNotEmpty) {
    b
      ..writeln('## 6명 조합 (레벨 $comboLevel, ${r.combos.length}개, 같은 계열 최대 2명)')
      ..writeln()
      ..writeln(
        '중앙값 ${_n(r.comboMedian)} · 상위 1% ${_n(r.comboTop)} '
        '(×${r.comboMedian > 0 ? (r.comboTop / r.comboMedian).toStringAsFixed(3) : '-'}, 한도 ×$comboLimit) · '
        '${r.comboOk ? '✓' : '✗'}',
      )
      ..writeln()
      ..writeln('| 순위 | 조합 | 점수 |')
      ..writeln('| ---: | --- | ---: |');
    for (var i = 0; i < r.combos.length && i < 5; i++) {
      b.writeln('| ${i + 1} | ${r.combos[i].crews.join(', ')} | ${_n(r.combos[i].score)} |');
    }
  }
  return b.toString();
}

String _n(double v) => v.abs() >= 1e6 ? v.toStringAsExponential(3) : v.toStringAsFixed(1);
