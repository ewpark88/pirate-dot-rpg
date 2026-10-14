import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 상단 HUD: 골드 · 젬 · 스테이지 · 보스 타이머, 그 아래 함성 게이지와 궁극기 버튼 (설계서 4.12).
class HudBar extends ConsumerWidget {
  const HudBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    // 상태는 틱마다(20Hz) 바뀐다 — 보이는 값만 골라 구독해서 값이 같으면 다시 그리지 않는다.
    final (gold, gems, stage, wave, rage) = ref.watch(
      gameStateProvider.select(
        (s) => (s.wallet.gold, s.wallet.gems, s.progress.stage, s.progress.wave, s.progress.rage),
      ),
    );
    final bossSeconds = ref.watch(
      gameStateProvider.select((s) {
        final battle = s.battle;
        if (battle == null || !battle.bossActive) return null;
        return (battle.bossTicksLeft * tables.waves.tickMs / Duration.millisecondsPerSecond).ceil();
      }),
    );
    final rageRatio = (rage / tables.skills.rageMax).clamp(0.0, 1.0);
    final rageFull = rageRatio >= 1;

    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Amount(icon: Icons.monetization_on, color: Colors.amber, text: gold.format()),
                const SizedBox(width: 12),
                _Amount(icon: Icons.diamond, color: Colors.lightBlue, text: '$gems'),
                const Spacer(),
                if (bossSeconds != null) ...[
                  Text(
                    l10n.uiHudBossTimer(bossSeconds),
                    key: const Key('hud.bossTimer'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(l10n.uiHudStage(stage, wave)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: rageRatio, minHeight: 8)),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('hud.ultimate'),
                  onPressed: rageFull ? () => ref.read(commandSinkProvider).send(const TriggerUltimate()) : null,
                  child: Text(l10n.uiHudUltimate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 4),
      Text(text),
    ],
  );
}
