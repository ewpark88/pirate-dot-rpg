import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 렌더가 탑다운(BattleView.mode 'top')을 그릴 수 있나. T2에서 렌더(S3)가 BattleGame에 연결하면 true로 바꾼다.
const kTopRenderReady = true;

/// 운영자 패널 '전장 방식' 토글 (요청서 platform-topdown-operator, S1 결정 (b)): 옆모습 / 탑다운.
/// 누르면 SetSetting('battleView', …). 렌더 연결 전에는 탑다운 옆에 '렌더 준비 중'.
class BattleViewToggle extends ConsumerWidget {
  const BattleViewToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(gameStateProvider.select((s) => s.settings.battleView));
    void send(String v) => ref.read(commandSinkProvider).send(SetSetting('battleView', v));
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l10n.opBattleView),
        ChoiceChip(
          key: const Key('op.battleView.side'),
          label: Text(l10n.opBattleViewSide),
          selected: now == 'side',
          onSelected: (_) => send('side'),
        ),
        ChoiceChip(
          key: const Key('op.battleView.top'),
          label: Text(l10n.opBattleViewTop),
          selected: now == 'top',
          onSelected: (_) => send('top'),
        ),
        if (!kTopRenderReady)
          Text(
            l10n.opBattleViewNotReady,
            key: const Key('op.battleView.notReady'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}
