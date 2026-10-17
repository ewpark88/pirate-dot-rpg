import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/dock/upgrade_all.dart';
import 'package:pirate_dot/ui/hud/cargo.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/ship_skin.dart';
import 'package:pirate_dot/ui/ship/ship_look.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/build_counter.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tabs/upgrade_multiplier.dart';
import 'package:pirate_dot/ui/text/big_num_text.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 강화 버튼 최소 폭.
const _buttonMinWidth = 100.0;

/// 배 탭: 부위 5줄 (이름·레벨·현재 효과·강화 비용 버튼). 효과·비용은 경제 함수로만 구한다 (설계서 4.2).
// TODO(ui): 꾹 눌러 연속 강화, 자동 강화 토글, 배 등급 진행 막대 — 다음 계획.
class ShipTab extends ConsumerWidget {
  const ShipTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    // 금고가 가득 차면 화물칸 줄을 맨 위로 — '화물칸 가득' 알약 바로가기로 오면 바로 보인다(사용자 지시 2026-10-16).
    final cargoFirst = ref.watch(cargoLevelProvider) == 2;
    final parts = [
      ...tables.shipParts.parts.where((p) => cargoFirst && p.id == 'cargo'),
      ...tables.shipParts.parts.where((p) => !(cargoFirst && p.id == 'cargo')),
    ];
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (cargoFirst) ...[for (final def in parts.take(1)) _PartRow(def: def)],
        // 지금 배 (크게) · 등급 이름 · 배 스킨(환생 v2 — 스킨이 생기면 보인다).
        const _ShipHeader(),
        // 일괄 강화 배수.
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: UpgradeMultiplierPills()),
        ),
        for (final def in cargoFirst ? parts.skip(1) : parts) _PartRow(def: def),
      ],
    );
  }
}

class _ShipHeader extends ConsumerWidget {
  const _ShipHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final tier = ref.watch(shipLookProvider.select((v) => v.tier));
    final name = tableText(l10n, tables.shipTiers.tiers.firstWhere((t) => t.id == tier).nameKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: const Key('ship.header'),
        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Skin.navyPanelTop, Skin.navyPanel],
          ),
          borderRadius: BorderRadius.circular(Skin.radiusCard),
          border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
          boxShadow: Skin.shadow,
        ),
        child: Row(
          children: [
            const ShipLookPreview(key: Key('ship.preview'), size: 84),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlineText(name, size: 20),
                  const SizedBox(height: 6),
                  const ShipSkinButton(),
                  // 모두 강화 원터치(경제 bestUpgradePlan) — 배 그림 옆에 두어 360에서도 부위 줄이 보이게.
                  const SizedBox(height: 6),
                  const UpgradeAllButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartRow extends ConsumerWidget {
  const _PartRow({required this.def});

  final ShipPartDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    countBuild('partRow');
    final l10n = AppLocalizations.of(context);
    final mult = ref.watch(upgradeMultiplierProvider);
    // 골드는 틱마다 바뀌므로 (레벨, 살 레벨 수, 비용)만 구독한다.
    final (level, levels, cost, honor) = ref.watch(
      gameStateProvider.select((s) {
        final lv = s.ship.parts[def.id] ?? 0;
        final (n, c) = bulkUpgrade(def, lv, s.wallet.gold, mult);
        // 명예 외형: 환생 전에 도달한 외형 단계가 지금 레벨의 단계보다 높다(그림은 명예 단계로 보인다).
        return (lv, n, c, (s.ship.honorParts[def.id] ?? 0) > partLookStage(def, lv));
      }),
    );
    final affordable = levels > 0;
    // 다음 외형: 다음 단계가 열리는 레벨과 그 모습(명예 단계로 이미 보이는 모습이면 없음).
    final look = ref.watch(shipLookProvider.select((v) => v.look[def.id] ?? 0));
    final nextAt = nextLookLevel(def, level);
    final nextStage = nextAt == null ? null : partLookStage(def, nextAt);
    final next = nextStage != null && nextStage > look ? nextAt : null;
    final max = def.maxLevel;
    final maxed = max != null && level >= max;

    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: PixelPalette.textDim);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      // 안쪽 여백 = 프레임 3칸 + 2칸.
      child: PixelFrame(
        padding: 5,
        child: Column(
          children: [
            Row(
              children: [
                // k2: 부위 색 네모 칸 + 왼쪽 위 Lv 배지 (쿵푸할매 장비 화면처럼).
                IconCell(
                  color: partCellColors[ref.read(tablesProvider).shipParts.parts.indexOf(def) % partCellColors.length],
                  level: l10n.uiLevel(level),
                  levelKey: Key('ship.lv.${def.id}'),
                  child: PixelSprite(UiSprites.part(def.id), dots: 16, key: Key('ship.icon.${def.id}')),
                ),
                const SizedBox(width: 8),
                // 이름과 레벨은 한 덩어리.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tableText(l10n, def.nameKey), style: const TextStyle(fontWeight: FontWeight.bold)),
                      // 레벨은 칸 배지에 — 최대가 있는 부위만 '현재/최대'.
                      if (max != null) Text(l10n.uiLevelMax(level, max), style: small),
                      // 화물칸 = 골드 금고: '최대 a → b'(다음 레벨 용량).
                      if (def.stat == 'capacity')
                        Text(
                          l10n.uiCargoMaxNext(partEffect(def, level).format(), partEffect(def, level + 1).format()),
                          key: Key('ship.effect.${def.id}'),
                          style: Skin.text(14, color: PixelPalette.accent),
                        ),
                      if (honor)
                        Text(
                          l10n.uiRebirthHonorLook,
                          key: Key('ship.honor.${def.id}'),
                          style: Skin.text(12, color: Skin.goldInk),
                        ),
                    ],
                  ),
                ),
                // 화물칸 효과는 이름 아래 줄('최대 a → b') — 오른쪽은 비운다.
                if (def.stat != 'capacity')
                  Text(
                    partEffectText(l10n, def, partEffect(def, level)),
                    key: Key('ship.effect.${def.id}'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: PixelPalette.accent),
                  ),
                const SizedBox(width: 8),
                // 비용 글자 길이와 상관없이 버튼 폭을 맞춘다(줄마다 오른쪽 끝 정렬).
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: _buttonMinWidth),
                  child: TutorialSpot(
                    id: 'ship.upgrade.${def.id}',
                    // 금고가 가득 차면 화물칸 강화 버튼을 가리킨다(사용자 지시 2026-10-16).
                    force: def.id == 'cargo' && ref.watch(cargoLevelProvider) == 2,
                    child: PixelButton(
                      key: Key('ship.upgrade.${def.id}'),
                      primary: true,
                      onPressed: maxed || !affordable
                          ? null
                          : () => ref.read(commandSinkProvider).send(bulkUpgradeCommand(def.id, mult)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!maxed) ...[
                            Opacity(
                              opacity: affordable ? 1 : 0.5,
                              child: const PixelSprite(UiSprites.coin, dots: 16, scale: 1),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (maxed) Text(l10n.uiShipMaxed) else BigNumText(cost),
                          // ×1이 아니면 실제로 오를 레벨 수.
                          if (!maxed && mult != 1 && levels > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              l10n.uiUpgradeLevels(levels),
                              key: Key('ship.upgrade.levels.${def.id}'),
                              style: Skin.text(12, color: Colors.white70),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // 다음 외형: 작은 배 그림(이 부위만 다음 단계) + '다음 외형 Lv N'.
            if (next != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    _NextLook(part: def.id, stage: nextStage!),
                    const SizedBox(width: 6),
                    Text(
                      l10n.uiShipNextLook(next),
                      key: Key('ship.next.${def.id}'),
                      style: Skin.text(12, color: Skin.primaryEdge),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 부위 줄 작은 미리보기: 이 부위만 다음 단계로 바꾼 배.
class _NextLook extends ConsumerWidget {
  const _NextLook({required this.part, required this.stage});

  final String part;
  final int stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(shipLookProvider.select((v) => v.look));
    return ShipLookPreview(key: Key('ship.next.preview.$part'), size: 30, look: {...look, part: stage});
  }
}
