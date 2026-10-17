import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';

/// 판정 문턱: 새 선원 초당 피해가 지금의 이 배 이상이면 추천, 이 배 이하면 비추천(그 사이는 비슷).
const _better = 1.1;
const _worse = 0.9;

/// 편성 칸 선원 바꾸기 전 비교 창(사용자 피드백 #34): 지금 선원 [outId] vs 새 선원 [inId] — 초상·레벨·초당 피해,
/// 초당 공격력 ±%, 조준·범위·사거리 차이(다를 때만 한 줄씩), 결론 칩(추천·비슷·비추천) + 이유 한 줄, [취소] [교체].
/// 작은 창(폰 폭 85%·최대 340dp, 본문 16sp — S4 팝업 기준). 교체를 고르면 true.
Future<bool> showSwapCompare(BuildContext context, String outId, String inId) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => SwapCompareDialog(outId: outId, inId: inId),
    ) ??
    false;

enum SwapVerdict { better, similar, worse }

class SwapCompareDialog extends ConsumerWidget {
  const SwapCompareDialog({required this.outId, required this.inId, super.key});

  final String outId;
  final String inId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    // 두 선원 레벨이 바뀔 때만 다시 계산(S4 검토 ① — 전투 상태는 20Hz로 바뀐다, 발열 대책). 계산은 그때 상태로 한 번.
    ref.watch(gameStateProvider.select((s) => '${s.crews[outId]?.level}/${s.crews[inId]?.level}'));
    final s = ref.read(gameStateProvider);
    final cmp = swapCompare(s, t, outId, inId);
    final rarityOf = {
      for (final id in [outId, inId])
        id: t.rarities.rarities.indexOf(rarityOfLevel(t.rarities, s.crews[id]?.level ?? 1)),
    };
    final a = crewIdentity(t, outId, rarity: rarityOf[outId]!);
    final b = crewIdentity(t, inId, rarity: rarityOf[inId]!);
    final pct = ((cmp.ratio - 1) * 100).round();
    // 이유: 무리(범위)·보스(강한 적 조준) 쪽 강약 — 없으면 공격력 차이.
    final bossAims = {AimKind.boss, AimKind.strongest};
    final verdict = cmp.ratio >= _better
        ? SwapVerdict.better
        : (cmp.ratio <= _worse ? SwapVerdict.worse : SwapVerdict.similar);
    // 좋은 점 · 약한 점 순서(S4 검토 ③).
    final strong = [
      if (verdict == SwapVerdict.better) l10n.uiSwapDpsUp,
      if (a != null && b != null && b.area && !a.area) l10n.uiSwapMobStrong,
      if (a != null && b != null && bossAims.contains(b.aim) && !bossAims.contains(a.aim)) l10n.uiSwapBossStrong,
    ];
    final weak = [
      if (verdict == SwapVerdict.worse) l10n.uiSwapDpsDown,
      if (a != null && b != null && a.area && !b.area) l10n.uiSwapMobWeak,
      if (a != null && b != null && bossAims.contains(a.aim) && !bossAims.contains(b.aim)) l10n.uiSwapBossWeak,
    ];
    final reasons = [...strong, ...weak];
    final diffs = [
      if (a != null && b != null && a.aim != b.aim) l10n.uiSwapAim(aimText(l10n, a.aim), aimText(l10n, b.aim)),
      if (a != null && b != null && a.area != b.area)
        l10n.uiSwapArea(
          a.area ? l10n.uiSwapAreaWide : l10n.uiSwapAreaSingle,
          b.area ? l10n.uiSwapAreaWide : l10n.uiSwapAreaSingle,
        ),
      if (a != null && b != null && a.range != b.range)
        l10n.uiSwapRange(_rangeText(l10n, a.range), _rangeText(l10n, b.range)),
    ];
    final (chipText, chipColor) = switch (verdict) {
      // 옅은 바탕 + 진한 글자(S4 검토 ② — 흰 글자는 금·민트 바탕에서 대비 4.5:1 미만).
      SwapVerdict.better => (l10n.uiSwapBetter, Skin.mintInk),
      SwapVerdict.similar => (l10n.uiSwapSimilar, Skin.goldInk),
      SwapVerdict.worse => (l10n.uiSwapWorse, Skin.danger),
    };
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      key: const Key('swap.compare'),
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: (width * 0.85).clamp(0, 340)),
        child: Container(
          key: const Key('swap.compare.box'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Skin.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: Skin.shadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.uiSwapTitle, textAlign: TextAlign.center, style: Skin.text(18)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Side(crewId: outId, dps: cmp.dpsOut.format()),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 22, color: Skin.sub),
                  Expanded(
                    child: _Side(crewId: inId, dps: cmp.dpsIn.format()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.uiSwapDps(pct >= 0 ? '+$pct%' : '$pct%'),
                key: const Key('swap.delta'),
                textAlign: TextAlign.center,
                style: Skin.text(16, color: pct >= 0 ? Skin.mintInk : Skin.danger),
              ),
              for (final d in diffs)
                Text(
                  d,
                  textAlign: TextAlign.center,
                  style: Skin.text(15, color: Skin.sub),
                ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  key: Key('swap.verdict.${verdict.name}'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: chipColor, width: 1.5),
                  ),
                  child: Text(chipText, style: Skin.text(16, color: chipColor)),
                ),
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  reasons.join(' · '),
                  key: const Key('swap.reason'),
                  textAlign: TextAlign.center,
                  style: Skin.text(15),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SkinButton(
                      key: const Key('swap.cancel'),
                      tone: SkinTone.plain,
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.uiCancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SkinButton(
                      key: const Key('swap.confirm'),
                      tone: SkinTone.gold,
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(l10n.uiSwapConfirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _rangeText(AppLocalizations l, int r) => switch (r) {
  0 => l.uiRangeShort,
  1 => l.uiRangeMid,
  _ => l.uiRangeLong,
};

/// 한쪽: 초상 · 짧은 이름 · 레벨 · 초당 피해.
class _Side extends ConsumerWidget {
  const _Side({required this.crewId, required this.dps});

  final String crewId;
  final String dps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final def = ref.watch(tablesProvider).crews.byId(crewId);
    final level = ref.watch(gameStateProvider.select((s) => s.crews[crewId]?.level ?? 1));
    return Column(
      key: Key('swap.side.$crewId'),
      children: [
        CrewPortrait(crew: def, size: 48),
        Text(shortCrewName(l10n, def), maxLines: 1, overflow: TextOverflow.ellipsis, style: Skin.text(16)),
        Text(l10n.uiLevel(level), style: Skin.text(14, color: Skin.sub)),
        Text(l10n.uiCrewDps(dps), maxLines: 1, style: Skin.text(14)),
      ],
    );
  }
}
