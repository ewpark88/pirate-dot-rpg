import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 결과 카드 한 줄에 몇 장 (10연 = 2줄 × 5장).
const _perRow = 5;

/// 카드 가로:세로.
const _cardAspect = 0.5;

/// 카드 뒤집기 시간.
const _flip = Duration(milliseconds: 250);

/// 튜토리얼에서 소환을 배우는 단계 — 결과 창을 닫으면 끝난다 (설계서 4.12 표).
const _summonTutorialStep = 4;

/// `lastSummon`이 생기면 소환 결과 창을 하나 띄운다 (설계서 4.12 팝업 3가지 중 ‘소환 결과’).
class SummonResultGate extends ConsumerStatefulWidget {
  const SummonResultGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SummonResultGate> createState() => _SummonResultGateState();
}

class _SummonResultGateState extends ConsumerState<SummonResultGate> {
  var _open = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(gameStateProvider.select((s) => s.lastSummon), (_, results) => _show(results));
    // 시작할 때 이미 결과가 있으면(복원 직후 등) 첫 프레임 뒤에 띄운다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(ref.read(gameStateProvider).lastSummon));
  }

  void _show(List<SummonResult>? results) {
    if (_open || results == null || results.isEmpty || !mounted) return;
    _open = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SummonResultDialog(results: results),
      ).whenComplete(() => _open = false),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 카드 뒤집기: 눌러서 한 장씩 또는 ‘모두 뒤집기’. 다 뒤집으면 확인 → AckSummonResult.
class SummonResultDialog extends ConsumerStatefulWidget {
  const SummonResultDialog({required this.results, super.key});

  final List<SummonResult> results;

  @override
  ConsumerState<SummonResultDialog> createState() => _SummonResultDialogState();
}

class _SummonResultDialogState extends ConsumerState<SummonResultDialog> {
  late final List<bool> _revealed = List.filled(widget.results.length, false);

  void _close() {
    final sink = ref.read(commandSinkProvider)..send(const AckSummonResult());
    if (ref.read(tutorialStepProvider) == _summonTutorialStep) {
      sink.send(const TutorialAck(_summonTutorialStep));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rarities = ref.watch(tablesProvider).rarities;
    final allRevealed = _revealed.every((r) => r);
    return AlertDialog(
      title: Text(l10n.uiSummonResultTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: widget.results.length < _perRow ? widget.results.length : _perRow,
          childAspectRatio: _cardAspect,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < widget.results.length; i++)
              GestureDetector(
                onTap: () => setState(() => _revealed[i] = true),
                child: AnimatedSwitcher(
                  duration: _flip,
                  child: _revealed[i]
                      ? _Face(index: i, result: widget.results[i], rarities: rarities)
                      : _Back(key: Key('summon.card.$i.back')),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (allRevealed)
          FilledButton(key: const Key('summon.result.ok'), onPressed: _close, child: Text(l10n.uiSummonResultOk))
        else
          TextButton(
            key: const Key('summon.revealAll'),
            onPressed: () => setState(() => _revealed.fillRange(0, _revealed.length, true)),
            child: Text(l10n.uiSummonRevealAll),
          ),
      ],
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Center(child: Icon(Icons.help_outline, color: Colors.white)),
  );
}

class _Face extends ConsumerWidget {
  const _Face({required this.index, required this.result, required this.rarities});

  final int index;
  final SummonResult result;
  final RarityTable rarities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final rarity = rarities.rarities.firstWhere((r) => r.id == result.rarity);
    final order = rarities.rarities.map((r) => r.id).toList();
    // 천장 등급(영웅) 이상은 강조 — 10연 확정 카드가 눈에 띄게.
    final highlight = order.indexOf(result.rarity) >= order.indexOf(rarities.pityMinRarity);
    final small = Theme.of(context).textTheme.labelSmall;
    return Container(
      key: Key('summon.card.$index.face'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: rarityColor(rarity), width: highlight ? 3 : 2),
        borderRadius: BorderRadius.circular(6),
        boxShadow: highlight ? [BoxShadow(color: rarityColor(rarity), blurRadius: 8)] : null,
      ),
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (highlight) SizedBox.shrink(key: Key('summon.card.$index.highlight')),
          if (result.isNew)
            Text(
              l10n.uiSummonNew,
              style: small?.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          CrewPortrait(crew: tables.crews.byId(result.crewId), size: 24),
          Text(
            tableText(l10n, tables.crews.byId(result.crewId).nameKey),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: small,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (var s = 0; s < rarity.stars; s++) Icon(Icons.star, size: 8, color: rarityColor(rarity))],
          ),
        ],
      ),
    );
  }
}
