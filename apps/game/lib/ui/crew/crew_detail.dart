import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_growth_reasons.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';
import 'package:pirate_dot/ui/crew/crew_pill.dart';
import 'package:pirate_dot/ui/crew/crew_text.dart';
import 'package:pirate_dot/ui/crew/fleet_sheet.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
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
    // 전설 미만인데 값이 있으면 특징(전설 능력 × 등급 배율, 개성 v2).
    final traitScale = rarityIndex < legendIndex && legendNow != null && rarityIndex < tables.skills.traitScale.length
        ? tables.skills.traitScale[rarityIndex]
        : null;
    final color = rarityColor(rarity);
    const dim = TextStyle(color: PixelPalette.textDim);
    final title = Theme.of(context).textTheme.titleSmall;

    // 정보 묶음 = 작은 판 (스킨 r2 다듬기). [tone]: 금색(전설 능력 열림) · 흐림(잠김) · 기본.
    // 아이콘: 그림 경로(String) 또는 머티리얼 아이콘(IconData). 별은 등급만 뜻하므로 여기 쓰지 않는다.
    Widget section(String head, List<Widget> body, {Color? fill, Color? border, Object? icon}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: fill ?? const Color(0xFFF1F7FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border ?? Skin.cardEdge, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon is String) ...[SkinIcon(icon, size: 16), const SizedBox(width: 4)],
                if (icon is IconData) ...[Icon(icon, size: 18, color: Skin.goldInk), const SizedBox(width: 4)],
                Flexible(child: Text(head, style: title)),
              ],
            ),
            const SizedBox(height: 2),
            ...body,
          ],
        ),
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
                      // 등급 알약(등급 색 테두리·옅은 바탕·진한 글 — 일반의 회색도 읽힌다) · 출전 알약.
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          CrewPill(
                            fill: color.withValues(alpha: 0.18),
                            border: color,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 등급 별은 카드 리본에만(한 의미 한 자리) — 알약은 등급 이름만.
                                Text(tableText(l10n, rarity.nameKey), style: Skin.text(13)),
                              ],
                            ),
                          ),
                          if (deployed)
                            CrewPill(
                              fill: const Color(0xFFDDF7EA),
                              border: Skin.mint,
                              child: Text(l10n.uiCrewDeployed, style: Skin.text(13, color: Skin.mintInk)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 특색 (선원 개성 v2): 한 줄 + 조준·연사·범위·명중.
            CrewIdentityPanel(crewId: def.id, rarity: rarityIndex),
            if (crew == null)
              section(l10n.uiCrewNotOwned, [Text(l10n.uiCrewHowToGet, key: const Key('crew.detail.howTo'))])
            else
              _Growth(
                crew: crew,
                rarity: rarity,
                tables: tables,
                atGate: _atGate.contains(status),
                // 이 선원 혼자의 초당 피해 (상단 바 함대 합계와 같은 계산 — 경제 fleetDps).
                dps: ref.watch(gameStateProvider.select((s) => fleetDps(s, tables, [def.id]).format())),
              ),
            // 레벨을 올리는 이유 + 합치기 버튼(피드백 #12·#16).
            if (crew != null) CrewGrowthReasons(crewId: def.id),
            section(icon: UiSprites.flag, l10n.uiCrewType, [
              Text(tableText(l10n, family.nameKey), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(shapeText(l10n, family.attack.shape), style: dim),
            ]),
            section(icon: Icons.bolt_rounded, l10n.uiCrewSkill, [
              Text(skillName(l10n, skill.id), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(shapeText(l10n, skill.area.shape), style: dim),
              Text(skillDesc(l10n, skill), style: dim),
            ]),
            if (legend != null)
              section(
                traitScale != null ? l10n.uiCrewTrait(percentText(l10n, traitScale)) : l10n.uiCrewLegend,
                icon: legendNow == null
                    ? UiSprites.lock
                    : (traitScale != null ? Icons.auto_awesome_rounded : Icons.workspace_premium_rounded),
                // 열린 전설 능력은 금빛 판, 아직이면 흐린 판.
                fill: legendNow == null ? Skin.track : const Color(0xFFFFF4CF),
                border: legendNow == null ? Skin.plainEdge : Skin.goldBottom,
                [
                  if (legendNow == null) Text(l10n.uiCrewLegendLocked, style: dim),
                  for (final line in legendLines(l10n, legend))
                    Text(line, style: legendNow == null ? dim : Skin.text(15, color: Skin.goldInk)),
                  if (traitScale != null)
                    Text(l10n.uiCrewTraitFull, key: const Key('crew.detail.traitFull'), style: dim),
                ],
              ),
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
            onPressed: () => undeployCrew(context, ref, def.id),
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
  const _Growth({
    required this.crew,
    required this.rarity,
    required this.tables,
    required this.atGate,
    required this.dps,
  });

  final CrewState crew;

  /// 이 선원의 초당 공격력 (표시 글).
  final String dps;
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
              Text(l10n.uiCrewDps(dps), key: const Key('crew.detail.power')),
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
