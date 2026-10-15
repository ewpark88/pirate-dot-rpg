import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_text.dart';
import 'package:pirate_dot/ui/crew/fleet_sheet.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 상세 카드 폭(dp).
const _cardWidth = 132.0;

/// 승급 버튼을 보이는 상태 = 승급 문 앞.
const Set<PromoteStatus> _atGate = {PromoteStatus.ok, PromoteStatus.cards, PromoteStatus.gold, PromoteStatus.tokens};

/// 선원 카드를 누르면 상세 창 (사용자 요청 A).
Future<void> showCrewDetail(BuildContext context, CrewDef def) => showDialog<void>(
  context: context,
  builder: (_) => CrewDetailDialog(def: def),
);

/// 선원 상세: 큰 초상 · 이름(짧은 + 전체) · 등급·별 · 레벨·경험치 · 카드 · 파워 · 계열(공격 모양) · 스킬 · 전설 능력,
/// 승급(문 앞일 때) · 출전/내리기. 미보유는 실루엣 + 얻는 방법.
class CrewDetailDialog extends ConsumerWidget {
  const CrewDetailDialog({required this.def, super.key});

  final CrewDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final crew = ref.watch(gameStateProvider.select((s) => s.crews[def.id]));
    final status = ref.watch(gameStateProvider.select((s) => promoteStatus(s, tables, def.id)));
    final deployed = ref.watch(fleetSlotsProvider).contains(def.id);
    final rarities = tables.rarities;
    final rarity = crew == null ? rarities.byId(def.baseRarity) : rarityOfLevel(rarities, crew.level);
    final rarityIndex = rarities.rarities.indexOf(rarity);
    final legendIndex = rarities.rarities.indexWhere((r) => r.id == 'legend');
    final family = tables.skills.byId(def.family);
    final skillId = def.skill;
    final skill = skillId == null ? family.skill : tables.skills.skillById(skillId);
    // 지금 등급의 전설 능력. 아직 전설 전이면 전설 때 것을 흐리게 미리 보인다.
    final legendNow = tables.skills.legendFor(def.id, rarityIndex, legendIndex);
    final legend = legendNow ?? tables.skills.legendFor(def.id, legendIndex, legendIndex);
    final color = rarityColor(rarity);
    const dim = TextStyle(color: PixelPalette.textDim);
    final title = Theme.of(context).textTheme.titleSmall;

    Widget section(String head, List<Widget> body) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(head, style: title),
          const SizedBox(height: 2),
          ...body,
        ],
      ),
    );

    return PixelDialog(
      key: Key('crew.detail.${def.id}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BigPortrait(def: def, rarity: rarity, owned: crew != null, name: shortCrewName(l10n, def)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shortCrewName(l10n, def), style: Theme.of(context).textTheme.titleMedium),
                      Text(tableText(l10n, def.nameKey), style: dim),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(tableText(l10n, rarity.nameKey), style: TextStyle(color: color)),
                          const SizedBox(width: 6),
                          const PixelSprite(UiSprites.star, dots: 16, scale: 1),
                          Text(rarity.stars.toString(), style: TextStyle(color: color)),
                        ],
                      ),
                      if (deployed) Text(l10n.uiCrewDeployed, style: const TextStyle(color: PixelPalette.accent)),
                    ],
                  ),
                ),
              ],
            ),
            if (crew == null)
              section(l10n.uiCrewNotOwned, [Text(l10n.uiCrewHowToGet, key: const Key('crew.detail.howTo'))])
            else
              _Growth(crew: crew, rarity: rarity, tables: tables, atGate: _atGate.contains(status)),
            section(l10n.uiCrewType, [
              Text(tableText(l10n, family.nameKey), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(shapeText(l10n, family.attack.shape), style: dim),
            ]),
            section(l10n.uiCrewSkill, [
              Text(skillName(l10n, skill.id), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(shapeText(l10n, skill.area.shape), style: dim),
              Text(skillDesc(l10n, skill), style: dim),
            ]),
            if (legend != null)
              section(l10n.uiCrewLegend, [
                if (legendNow == null) Text(l10n.uiCrewLegendLocked, style: dim),
                for (final line in legendLines(l10n, legend))
                  Text(line, style: legendNow == null ? dim : const TextStyle(color: PixelPalette.accent)),
              ]),
          ],
        ),
      ),
      actions: [
        if (crew != null && _atGate.contains(status))
          PixelButton(
            key: Key('crew.detail.promote.${def.id}'),
            primary: true,
            onPressed: status == PromoteStatus.ok
                ? () => ref.read(commandSinkProvider).send(PromoteCrew(def.id))
                : null,
            child: Text(l10n.uiCrewPromote),
          ),
        // 출전 중이면 ‘바꾸기’(이 칸에 다른 선원)와 ‘내리기’.
        if (crew != null && deployed) ...[
          PixelButton(
            key: Key('crew.detail.replace.${def.id}'),
            primary: true,
            onPressed: () => unawaited(replaceCrew(context, ref, def.id)),
            child: Text(l10n.uiCrewReplace),
          ),
          PixelButton(
            key: Key('crew.detail.undeploy.${def.id}'),
            onPressed: () => undeployCrew(ref, def.id),
            child: Text(l10n.uiCrewUndeploy),
          ),
        ] else if (crew != null)
          PixelButton(
            key: Key('crew.detail.deploy.${def.id}'),
            primary: true,
            onPressed: () => unawaited(deployCrew(context, ref, def.id)),
            child: Text(l10n.uiCrewDeploy),
          ),
        PixelButton(
          key: const Key('crew.detail.close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.uiClose),
        ),
      ],
    );
  }
}

/// 레벨 / 등급 최대 · 경험치 막대(문 앞이면 안내) · 카드 수 · 파워.
class _Growth extends StatelessWidget {
  const _Growth({required this.crew, required this.rarity, required this.tables, required this.atGate});

  final CrewState crew;
  final RarityDef rarity;
  final GameTables tables;
  final bool atGate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final need = tables.growth.expToNext[rarity.id] ?? 0;
    const dim = TextStyle(color: PixelPalette.textDim);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 레벨 · 파워: 좁으면 다음 줄로.
          Wrap(
            spacing: 12,
            children: [
              Text(l10n.uiLevelMax(crew.level, rarity.levelMax), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                l10n.uiCrewPower(shortDecimal(crewPowerOf(tables, crew.level))),
                key: const Key('crew.detail.power'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (atGate || need <= 0)
            Text(l10n.uiCrewAtGate, style: dim)
          else ...[
            PixelBar(value: crew.exp / need, fill: Skin.goldBottom, dots: 6),
            Text(l10n.uiCrewExp(crew.exp, need), style: dim),
          ],
          Text(l10n.uiCrewCards(crew.cards), style: dim),
        ],
      ),
    );
  }
}

/// 큰 카드 (Pirate Busters 카드, 미보유는 실루엣).
class _BigPortrait extends StatelessWidget {
  const _BigPortrait({required this.def, required this.rarity, required this.owned, required this.name});

  final CrewDef def;
  final RarityDef rarity;
  final bool owned;
  final String name;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _cardWidth,
    child: PbCardFront(crew: def, rarity: rarity, name: name, silhouette: !owned),
  );
}
