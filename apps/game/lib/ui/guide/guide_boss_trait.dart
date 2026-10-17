import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 특성 보스 한 마디 ('이 보스는 회피 25%! 투척·집속 선원이 잘 통해요.'). 특성 보스가 아니면 null.
String? bossTraitTalk(AppLocalizations l, WidgetRef ref) {
  final t = ref.watch(tablesProvider);
  final kind = ref.watch(gameStateProvider.select((s) => traitBoss(s, t)?.id));
  final def = kind == null ? null : t.regions.bosses[kind];
  if (def == null) return null;
  final counters = def.counterFamilies.take(3).map((f) => tableText(l, t.skills.byId(f).nameKey)).join('·');
  return l.uiTalkBossTrait(def.traits.map((tr) => traitName(l, tr)).join(' · '), counters);
}
