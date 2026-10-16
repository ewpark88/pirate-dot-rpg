import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/sample_states.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';

// 운영자 패널 — 선원 시험(사용자 요청 '모든 캐릭터를 테스트해 보고 싶다', S1 2026-10-16).

/// 운영자 세이브 백업 저장소(지원 폴더/operator_backup). main이 운영자 빌드에서만 넣는다. 없으면 백업 버튼이 꺼진다.
final operatorBackupProvider = Provider<SaveStore?>((_) => null);

/// 샘플 불러오기 + 내 세이브 백업·되돌리기. 샘플을 불러오기 전에 백업이 없으면 지금 세이브를 백업한다
/// (샘플 위에 샘플을 불러와도 처음 세이브가 남는다). '내 세이브로 돌아가기'는 백업을 불러오고 백업을 비운다.
class SaveBackupGroup extends ConsumerStatefulWidget {
  const SaveBackupGroup({required this.sampleLabels, super.key});

  final Map<String, String> sampleLabels;

  @override
  ConsumerState<SaveBackupGroup> createState() => _SaveBackupGroupState();
}

class _SaveBackupGroupState extends ConsumerState<SaveBackupGroup> {
  var _hasBackup = false;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    final text = await ref.read(operatorBackupProvider)?.read();
    if (mounted) setState(() => _hasBackup = text != null && text.isNotEmpty);
  }

  void _send(Command c) => ref.read(commandSinkProvider).send(c);

  Future<void> _load(GameState sample) async {
    final store = ref.read(operatorBackupProvider);
    if (store != null && !_hasBackup) {
      await store.write(SaveCodec.encode(ref.read(gameStateProvider)));
      if (mounted) setState(() => _hasBackup = true);
    }
    _send(OpLoadState(sample));
  }

  Future<void> _restore() async {
    final store = ref.read(operatorBackupProvider);
    final text = await store?.read();
    if (store == null || text == null || text.isEmpty) return;
    _send(OpLoadState(SaveCodec.decode(text)));
    await store.write('');
    if (mounted) setState(() => _hasBackup = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final name in sampleStateNames)
          OutlinedButton(
            key: Key('op.sample.$name'),
            onPressed: () => _load(loadSampleState(name)),
            child: Text(widget.sampleLabels[name] ?? name),
          ),
        FilledButton(
          key: const Key('op.backup.restore'),
          onPressed: _hasBackup ? _restore : null,
          child: Text(l10n.opRestoreMySave),
        ),
      ],
    );
  }
}

/// 선원 시험 칸: 등급을 고르고 선원을 누르면 그 등급 최소 레벨로 보유 + 출전 칸 1. '모든 선원 받기'(지금 세이브 유지),
/// 시험 장면(무리 30·기본 파 = 돌격대 포함·보스).
class CrewLabGroup extends ConsumerStatefulWidget {
  const CrewLabGroup({super.key});

  @override
  ConsumerState<CrewLabGroup> createState() => _CrewLabGroupState();
}

class _CrewLabGroupState extends ConsumerState<CrewLabGroup> {
  var _rarity = 0;

  /// 시험 장면 '무리' 마리 수.
  static const _swarm = 30;

  void _send(Command c) => ref.read(commandSinkProvider).send(c);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final rarities = tables.rarities.rarities;
    final owned = ref.watch(gameStateProvider.select((s) => s.crews.keys.join(','))).split(',').toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.opLabTapHint, style: Theme.of(context).textTheme.bodySmall),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < rarities.length; i++)
              ChoiceChip(
                key: Key('op.lab.rarity.${rarities[i].id}'),
                label: Text(tableText(l10n, rarities[i].nameKey)),
                selected: _rarity == i,
                onSelected: (_) => setState(() => _rarity = i),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final c in tables.crews.crews)
              Tooltip(
                message: tableText(l10n, c.nameKey),
                child: InkWell(
                  key: Key('op.lab.crew.${c.id}'),
                  onTap: () {
                    _send(OpSetCrew(c.id, level: rarities[_rarity].levelMin)); // 보유(그 등급 최소 레벨)
                    _send(SetFleetSlot(0, c.id)); // 출전 칸 1
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CrewPortrait(crew: c, size: 40),
                      SizedBox(
                        width: 48,
                        child: Text(
                          tableText(l10n, c.nameKey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('op.lab.collectAll'),
              onPressed: () {
                for (final c in tables.crews.crews) {
                  if (!owned.contains(c.id)) _send(OpSetCrew(c.id, level: rarities.first.levelMin));
                }
              },
              child: Text(l10n.opLabCollectAll),
            ),
            OutlinedButton(
              key: const Key('op.lab.swarm'),
              onPressed: () => _send(const OpSetWave(count: _swarm)),
              child: Text(l10n.opLabSwarm(_swarm)),
            ),
            OutlinedButton(
              key: const Key('op.lab.wave'),
              onPressed: () => _send(const OpSetWave()),
              child: Text(l10n.opLabWave),
            ),
            OutlinedButton(
              key: const Key('op.lab.boss'),
              onPressed: () => _send(const OpSpawnBoss()),
              child: Text(l10n.opSpawnBoss),
            ),
          ],
        ),
      ],
    );
  }
}
