import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/render_group.dart';
import 'package:pirate_dot/operator/sample_states.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 배속 버튼 (OpSetSpeed는 0·1·2·4를 받는다. 일시정지는 2차).
const _speeds = [1, 2, 4];

/// 골드 지급 버튼의 10의 지수 (1e6 · 1e12 · 1e30).
const _goldExponents = [6, 12, 30];

/// 젬 지급량.
const _gemGrant = 1000;

/// 운영자 패널 1차 (설계서 6.10, 스펙 docs/specs/ui-operator-panel.md).
/// 모든 조작은 OperatorCommand만 보낸다 — 엔진 상태가 기준이라 gameStateProvider를 직접 바꾸지 않는다.
class OperatorPanel extends ConsumerStatefulWidget {
  const OperatorPanel({super.key});

  @override
  ConsumerState<OperatorPanel> createState() => _OperatorPanelState();
}

class _OperatorPanelState extends ConsumerState<OperatorPanel> {
  // 무적·쿨타임 0은 GameState에 없어서 패널이 마지막으로 보낸 값을 기억한다.
  var _invincible = false;
  var _zeroCooldown = false;
  final _stage = TextEditingController();

  @override
  void dispose() {
    _stage.dispose();
    super.dispose();
  }

  void _send(Command command) => ref.read(commandSinkProvider).send(command);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stage = int.tryParse(_stage.text);
    final sampleLabels = {
      'new_player': l10n.opSampleNewPlayer,
      'stage37_midgame': l10n.opSampleStage37,
      'boss_fight': l10n.opSampleBossFight,
      'all_crews_mythic': l10n.opSampleAllMythic,
    };

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(l10n.opPanelTitle, style: Theme.of(context).textTheme.titleLarge),
        _Group(l10n.opGroupSave, [
          for (final name in sampleStateNames)
            OutlinedButton(
              key: Key('op.sample.$name'),
              onPressed: () => _send(OpLoadState(loadSampleState(name))),
              child: Text(sampleLabels[name] ?? name),
            ),
        ]),
        _Group(l10n.opGroupBattle, [
          for (final s in _speeds)
            OutlinedButton(
              key: Key('op.speed.$s'),
              onPressed: () => _send(OpSetSpeed(s)),
              child: Text(l10n.opSpeed(s)),
            ),
          FilledButton.tonal(
            key: const Key('op.boss'),
            onPressed: () => _send(const OpSpawnBoss()),
            child: Text(l10n.opSpawnBoss),
          ),
          FilterChip(
            key: const Key('op.invincible'),
            label: Text(l10n.opInvincible),
            selected: _invincible,
            onSelected: (on) {
              setState(() => _invincible = on);
              _send(OpSetInvincible(on: on));
            },
          ),
          SizedBox(
            width: 96,
            child: TextField(
              key: const Key('op.stage.input'),
              controller: _stage,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.opJumpStageHint, isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          FilledButton(
            key: const Key('op.stage.go'),
            onPressed: stage != null && stage >= 1 ? () => _send(OpJumpStage(stage)) : null,
            child: Text(l10n.opJumpStage),
          ),
        ]),
        _Group(l10n.opGroupCrew, [
          FilterChip(
            key: const Key('op.zeroCooldown'),
            label: Text(l10n.opZeroCooldown),
            selected: _zeroCooldown,
            onSelected: (on) {
              setState(() => _zeroCooldown = on);
              _send(OpZeroCooldown(on: on));
            },
          ),
        ]),
        _Group(l10n.opGroupRender, const [RenderGroup()]),
        _Group(l10n.opGroupEconomy, [
          for (final e in _goldExponents)
            OutlinedButton(
              key: Key('op.gold.$e'),
              onPressed: () => _send(OpGrant(gold: BigNum.fromParts(1, e))),
              child: Text(l10n.opGrantGold(BigNum.fromParts(1, e).format())),
            ),
          OutlinedButton(
            key: const Key('op.gems'),
            onPressed: () => _send(const OpGrant(gems: _gemGrant)),
            child: Text(l10n.opGrantGems(_gemGrant)),
          ),
        ]),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: children),
      ],
    ),
  );
}
