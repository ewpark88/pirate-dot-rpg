import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 운영자 '오늘 새 기능'(설계서 6.10, S1 2026-10-17): 사용자가 폰에서 새 기능을 바로 불러 본다.
/// 피버 곧 시작(게이지 99% — 다음 처치에 켜짐) · 보스 브레이크 가득 · 특성 보스 골라 소환 · 연쇄 번개 선원(pelly 전설) 시험 ·
/// 출항 대기 상태 · 첫 10연 다시 받기. 상태를 바꾸는 것은 운영자 명령(OpLoadState 등)만 — 세이브 백업은 위 '저장' 묶음.
class TodayGroup extends ConsumerStatefulWidget {
  const TodayGroup({super.key});

  @override
  ConsumerState<TodayGroup> createState() => _TodayGroupState();
}

class _TodayGroupState extends ConsumerState<TodayGroup> {
  String? _boss;

  void _send(Command c) => ref.read(commandSinkProvider).send(c);

  /// 지금 상태를 고쳐 다시 불러온다.
  void _load(GameState Function(GameState s) edit) => _send(OpLoadState(edit(ref.read(gameStateProvider))));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    // 특징이 있는 보스(해역 보스 패턴·분열). 보스 특성(S2 boss-traits)이 BossDef에 들어오면 여기에 더한다.
    final special = [
      for (final b in t.regions.bosses.values)
        if (b.mechanic != null || b.splitAt.isNotEmpty) b,
    ];
    final legend = t.rarities.rarities.firstWhere((r) => r.id == 'legend').levelMin;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonal(
          key: const Key('op.today.fever'),
          onPressed: () => _load((s) => s.copyWith(progress: s.progress.copyWith(fever: 0.99))),
          child: Text(l10n.opTodayFever),
        ),
        FilledButton.tonal(
          key: const Key('op.today.break'),
          onPressed: () => _send(const OpBossBreak()),
          child: Text(l10n.opTodayBreak),
        ),
        DropdownButton<String>(
          key: const Key('op.today.bossPick'),
          value: _boss,
          hint: Text(l10n.opTodayBossPick),
          items: [
            for (final b in special) DropdownMenuItem(value: b.id, child: Text(tableText(l10n, b.nameKey))),
          ],
          onChanged: (id) => setState(() => _boss = id),
        ),
        FilledButton.tonal(
          key: const Key('op.today.boss'),
          onPressed: _boss == null ? null : () => _send(OpSpawnBoss(bossId: _boss)),
          child: Text(l10n.opTodayBoss),
        ),
        FilledButton.tonal(
          key: const Key('op.today.arc'),
          onPressed: () {
            _send(OpSetCrew('pelly', level: legend));
            _send(const OpSetFleet(['pelly']));
          },
          child: Text(l10n.opTodayArc),
        ),
        FilledButton.tonal(
          key: const Key('op.today.sail'),
          onPressed: () => _load(
            (s) => s.copyWith(
              progress: s.progress.copyWith(rebirths: s.progress.rebirths < 1 ? 1 : null, sailHold: true),
            ),
          ),
          child: Text(l10n.opTodaySail),
        ),
        FilledButton.tonal(
          key: const Key('op.today.firstTen'),
          onPressed: () => _load((s) => s.copyWith(summonsTotal: 0)),
          child: Text(l10n.opTodayFirstTen),
        ),
      ],
    );
  }
}
