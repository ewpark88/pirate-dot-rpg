import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/hd/hd_portrait.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show BossPortrait, bossName;
import 'package:pirate_dot/ui/dex/monster_dex_data.dart';
import 'package:pirate_dot/ui/guide/guide_marks.dart' show guideMotionProvider;
import 'package:pirate_dot/ui/guide/once_tip.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 몬스터 도감 보스 상세 (사용자·S1 2026-10-18): 보스 칸을 누르면 HD 초상(움직임) · 이름 · 해역 · 체력·공격(지금 스테이지 기준 —
// 경제 bossPreview를 그 보스 체력 배율로 바꿔) · 특성 아이콘 + 설명 · 약점 계열 칩 · 공격 패턴 이름 · 처치 수 · 처음 등장 /
// 다음 등장 스테이지(표 regions.bossAt). 못 만난 보스는 실루엣 + '스테이지 n에서 등장'. 처음 등장 스테이지와 그때 체력·공격은
// 경제 bossDexView(S2) 값 그대로.

/// 이 보스가 나오는 [from] 이후 첫 스테이지(표 regions.bossAt, 최대 [limit]까지 찾는다).
int? bossNextStage(GameTables t, String id, int from, {int limit = 2000}) {
  for (var st = from; st <= limit; st++) {
    if (t.regions.bossAt(st).id == id) return st;
  }
  return null;
}

/// 특성 보정까지 넣은 체력 배율(경제 bossMaxHp와 같은 곱).
double _hpFactor(BossDef d) => d.hpMultiplier * d.traits.fold<double>(1, (a, x) => a * x.cfg.numberOr('hpFactor', 1));

String patternName(AppLocalizations l, String type) => switch (type) {
  'volley' => l.uiPatternVolley,
  'blast' => l.uiPatternBlast,
  'charge' => l.uiPatternCharge,
  'ink' => l.uiPatternInk,
  'summon' => l.uiPatternSummon,
  _ => l.uiPatternSwallow,
};

void showBossDex(BuildContext context, DexEntry entry) =>
    showSkinDialog<void>(context, builder: (_) => BossDexDialog(entry: entry)).ignore();

class BossDexDialog extends ConsumerWidget {
  const BossDexDialog({required this.entry, super.key});

  final DexEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final s = ref.watch(gameStateProvider);
    final def = t.regions.bosses[entry.id]!;
    final stage = s.progress.stage;
    final dex = bossDexView(s, t).where((e) => e.id == entry.id).firstOrNull;
    final first = (dex?.firstStage ?? 0) > 0 ? dex!.firstStage : null;
    final next = first == null ? null : bossNextStage(t, entry.id, stage + 1);
    final region = first == null ? null : t.regions.regionAt(first);
    if (!entry.met) {
      return PixelDialog(
        key: Key('dex.boss.${entry.id}'),
        title: l10n.uiDexUnknown,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (HdPortrait.has(entry.id, boss: true))
              HdPortrait(kind: entry.id, boss: true, size: 160, silhouette: true)
            else
              ColorFiltered(
                colorFilter: const ColorFilter.mode(Color(0xFF2B3550), BlendMode.srcIn),
                child: BossPortrait(bossId: entry.id, size: 110),
              ),
            const SizedBox(height: 8),
            if (first != null) Text(l10n.uiBossDexUnmet(first), style: Skin.bold(16)),
          ],
        ),
      );
    }
    // 지금 스테이지 보스의 체력을 이 보스 배율로(공격은 스테이지만 따른다).
    final preview = bossPreview(s, t);
    final cur = t.regions.bosses[preview.bossId]!;
    final hp = preview.maxHp.times(_hpFactor(def) / _hpFactor(cur));
    return PixelDialog(
      key: Key('dex.boss.${entry.id}'),
      title: bossName(l10n, ref, entry.id),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: HdPortrait.has(entry.id, boss: true)
                ? HdPortrait(
                    kind: entry.id,
                    boss: true,
                    size: 160,
                    // 평소 → 공격 예고(붉은 눈) → 쓰러짐 순환(S3) · 움직임 끄기면 평소 얼굴.
                    animate: ref.watch(guideMotionProvider) && !MediaQuery.disableAnimationsOf(context),
                    moods: true,
                    shadow: true,
                  )
                : BossPortrait(bossId: entry.id, size: 110),
          ),
          if (region != null)
            Text(
              tableText(l10n, region.nameKey),
              textAlign: TextAlign.center,
              style: Skin.text(13, color: Skin.sub),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(l10n.uiBossDexHp(hp.format()), key: const Key('dex.boss.hp'), style: Skin.bold(15)),
              ),
              Expanded(child: Text(l10n.uiBossDexAtk(preview.attack.format()), style: Skin.bold(15))),
            ],
          ),
          Text(l10n.uiBossDexAtStage(stage), style: Skin.text(12, color: Skin.sub)),
          if (dex != null && first != null)
            Text(
              l10n.uiBossDexAtFirst(dex.hp.format(), dex.attack.format()),
              key: const Key('dex.boss.first'),
              style: Skin.text(12, color: Skin.sub),
            ),
          if (def.traits.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final tr in def.traits)
              Row(
                children: [
                  Icon(traitIcon(tr.type), size: 18, color: Skin.goldInk),
                  const SizedBox(width: 6),
                  Expanded(child: Text(traitName(l10n, tr), style: Skin.text(14))),
                ],
              ),
          ],
          if (bossCounters(def).isNotEmpty) ...[
            const SizedBox(height: 8),
            WeakChips(boss: def),
            // 처음 연 보스 상세에만 옥토 한 마디.
            OnceTip(id: 'tip.bossDex', text: l10n.uiTipBossDex),
          ],
          if (def.patterns.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l10n.uiBossDexPatterns, style: Skin.bold(13)),
            Text(
              {for (final p in def.patterns) patternName(l10n, p.type)}.join(l10n.uiListSep),
              key: const Key('dex.boss.patterns'),
              style: Skin.text(14),
            ),
          ],
          const SizedBox(height: 8),
          Text(l10n.uiDexKills(entry.kills), style: Skin.text(13, color: Skin.sub)),
          if (first != null) Text(l10n.uiBossDexFirst(first), style: Skin.text(13, color: Skin.sub)),
          if (next != null)
            Text(
              l10n.uiBossDexNext(next),
              key: const Key('dex.boss.next'),
              style: Skin.bold(14, color: Skin.mintInk),
            ),
        ],
      ),
    );
  }
}
