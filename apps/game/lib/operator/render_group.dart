import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';

/// 운영자 패널 ‘렌더’ 묶음: 전장 모드(라이브·데모·부하), 성능 표시, 히트박스.
/// 렌더 레인의 BattleGame 공개 API만 부른다. 전장이 Flame 게임이 아니면(테스트의 빈 상자) 비활성.
class RenderGroup extends ConsumerStatefulWidget {
  const RenderGroup({super.key});

  @override
  ConsumerState<RenderGroup> createState() => _RenderGroupState();
}

class _RenderGroupState extends ConsumerState<RenderGroup> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final game = ref.watch(hasBattleGameProvider) ? ref.watch(battleGameProvider) : null;

    // BattleGame 값은 GameState가 아니라서, 바꾼 뒤 setState로 다시 그린다.
    void apply(void Function(BattleGame g) change) => setState(() => change(game!));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<BattleMode>(
          key: const Key('op.mode'),
          segments: [
            ButtonSegment(value: BattleMode.live, label: Text(l10n.opModeLive)),
            ButtonSegment(value: BattleMode.demo, label: Text(l10n.opModeDemo)),
            ButtonSegment(value: BattleMode.stress, label: Text(l10n.opModeStress)),
          ],
          selected: {?game?.mode},
          emptySelectionAllowed: true,
          onSelectionChanged: game == null
              ? null
              : (s) => apply(
                  (g) => switch (s.single) {
                    BattleMode.live => g.resumeLive(),
                    BattleMode.demo => g.loadDemo(),
                    BattleMode.stress => g.loadStress(),
                  },
                ),
        ),
        FilterChip(
          key: const Key('op.perfOverlay'),
          label: Text(l10n.opPerfOverlay),
          selected: game?.perfOverlay ?? false,
          onSelected: game == null ? null : (on) => apply((g) => g.perfOverlay = on),
        ),
        FilterChip(
          key: const Key('op.hitboxes'),
          label: Text(l10n.opHitboxes),
          selected: game?.showHitboxes ?? false,
          onSelected: game == null ? null : (on) => apply((g) => g.showHitboxes = on),
        ),
      ],
    );
  }
}
