import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

/// 지난 보스 처치의 선원별 피해(BossCleared.crewDamage) — 보스 처치 창(BossDamageGate)이 채운다. 앱을 다시 켜면 비어 있다.
class LastBossDamage extends Notifier<Map<String, BigNum>> {
  @override
  Map<String, BigNum> build() => const {};

  Map<String, BigNum> get value => state;
  set value(Map<String, BigNum> damage) => state = damage;
}

final NotifierProvider<LastBossDamage, Map<String, BigNum>> lastBossDamageProvider =
    NotifierProvider<LastBossDamage, Map<String, BigNum>>(LastBossDamage.new);

/// 선원 상세 '피해 줄'(사용자 피드백 #13): 이번 스테이지 피해(BattleView.crewDamage) · 지난 보스 피해와 그 몫(%).
/// 둘 다 없으면(출전 안 함·전투 전) 그리지 않는다.
class CrewDamageLine extends ConsumerWidget {
  const CrewDamageLine({required this.crewId, super.key});

  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stage = ref.watch(gameStateProvider.select((s) => s.battle?.crewDamage[crewId]?.format()));
    final boss = ref.watch(lastBossDamageProvider);
    final mine = boss[crewId];
    String? bossText;
    if (mine != null) {
      final total = boss.values.fold(BigNum.zero, (a, b) => a + b);
      bossText = l10n.uiCrewDamageBoss(mine.format(), percentText(l10n, total.isZero ? 0 : (mine / total).toDouble()));
    }
    if (stage == null && bossText == null) return const SizedBox.shrink();
    return Padding(
      key: Key('crew.damage.$crewId'),
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 2,
        children: [
          if (stage != null) OutlineText(l10n.uiCrewDamageStage(stage), size: 15),
          if (bossText != null) OutlineText(bossText, size: 15, tone: OutlineTone.gold),
        ],
      ),
    );
  }
}
