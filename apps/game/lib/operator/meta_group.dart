import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 출전 전원을 바로 올려 볼 등급 (전설 능력·신화 연출 확인용).
const _fleetRarities = ['legend', 'mythic'];

/// 튜토리얼 단계 수 (설계서 4.12 표).
const _tutorialSteps = 6;

/// 운영자 패널 2차 — 선원: 출전 선원 스킬 즉시 시전, 출전 전원 등급 첫 레벨로.
class CrewTestGroup extends ConsumerWidget {
  const CrewTestGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    // 출전 목록은 틱마다 새 리스트라 문자열로 골라 구독한다(같으면 다시 그리지 않음).
    final fleet = ref.watch(gameStateProvider.select((s) => s.battle?.fleet.map((f) => f.crewId).join(','))) ?? '';
    final ids = fleet.isEmpty ? const <String>[] : fleet.split(',');
    void send(Command c) => ref.read(commandSinkProvider).send(c);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in ids)
          OutlinedButton(
            key: Key('op.skill.$id'),
            onPressed: () => send(OpCastSkill(id)),
            child: Text(l10n.opCastSkill(tableText(l10n, tables.crews.byId(id).nameKey))),
          ),
        for (final rarityId in _fleetRarities)
          Builder(
            builder: (context) {
              final rarity = tables.rarities.rarities.firstWhere((r) => r.id == rarityId);
              return FilledButton.tonal(
                key: Key('op.fleetLevel.$rarityId'),
                onPressed: ids.isEmpty
                    ? null
                    : () {
                        for (final id in ids) {
                          send(OpSetCrew(id, level: rarity.levelMin));
                        }
                      },
                child: Text(l10n.opSetFleetLevel(rarity.levelMin, tableText(l10n, rarity.nameKey))),
              );
            },
          ),
      ],
    );
  }
}

/// 운영자 패널 2차 — 보물상자 띄우기, 순풍 (경제 묶음 안).
class ChestTailwindGroup extends ConsumerWidget {
  const ChestTailwindGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tailwind = Duration(
      seconds: ref
          .watch(tablesProvider)
          .ads
          .placements
          .firstWhere((p) => p.id == 'tailwind')
          .reward
          .integer('durationSec'),
    );
    void send(Command c) => ref.read(commandSinkProvider).send(c);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          key: const Key('op.chest'),
          onPressed: () => send(const OpSpawnChest()),
          child: Text(l10n.opSpawnChest),
        ),
        OutlinedButton(
          key: const Key('op.tailwind'),
          onPressed: () => send(OpGrantTailwind(tailwind)),
          child: Text(l10n.opGrantTailwind(tailwind.inMinutes)),
        ),
      ],
    );
  }
}

/// 운영자 패널 2차 — 튜토리얼 아무 단계부터 / 끝내기 (설계서 4.12: 운영자 모드에서 아무 단계로나 다시 시작).
class TutorialTestGroup extends ConsumerWidget {
  const TutorialTestGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void send(Command c) => ref.read(commandSinkProvider).send(c);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var step = 1; step <= _tutorialSteps; step++)
          OutlinedButton(
            key: Key('op.tutorial.$step'),
            onPressed: () => send(OpSetTutorial(step)),
            child: Text(l10n.opTutorialStep(step)),
          ),
        OutlinedButton(
          key: const Key('op.tutorial.end'),
          onPressed: () => send(const OpSetTutorial(null)),
          child: Text(l10n.opTutorialEnd),
        ),
      ],
    );
  }
}
