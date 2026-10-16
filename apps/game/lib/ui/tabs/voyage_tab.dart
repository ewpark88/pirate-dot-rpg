import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart';
import 'package:pirate_dot/ui/dex/monster_dex.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_ready.dart';
import 'package:pirate_dot/ui/rebirth/title_sheet.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/build_counter.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// ‘시간당’ 오프라인 골드를 구할 때 쓰는 가짜 경과 (받을 때와 같은 계산으로 1시간치).
const _hour = Duration(hours: 1);

/// 항해 탭 (설계서 4.12): 해역 진행·해역 보스 미리보기, 오프라인·순풍 상태, 환생(보물지도) 카드.
// TODO(ui): 해역 지도 그림(해역 6개), 패널 접어 전장 크게 보기 — 다음 계획.
class VoyageTab extends ConsumerWidget {
  const VoyageTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    countBuild('voyage');
    // 카드 3장 (layout-v2-brief): 해역 · 오프라인/순풍 · 보물지도.
    // 환생할 수 있으면 보물지도 카드를 맨 위로 — 알약·말풍선 바로가기로 오면 바로 보인다(사용자 지시 2026-10-16).
    final ready = ref.watch(rebirthReadyProvider);
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // 칭호 띠 (환생 v2 — 칭호가 생기면 보인다, 누르면 목록).
        const Align(alignment: Alignment.centerLeft, child: TitleChip()),
        if (ready) ...const [RebirthCard(), SizedBox(height: 8)],
        const _RegionCard(),
        const SizedBox(height: 8),
        const PixelFrame(key: Key('voyage.status'), padding: 5, child: _StatusLines()),
        const SizedBox(height: 8),
        // 현상금 사냥 (보물지도 카드 위, 기획 6절 ①).
        const BountyCard(),
        if (!ready) ...const [SizedBox(height: 8), RebirthCard()],
        // 바다 괴물 도감 (보물지도 옆, S1 2026-10-16 — 골격).
        const SizedBox(height: 8),
        const MonsterDexCard(),
      ],
    );
  }
}

/// 해역 카드: 이름·해역 안 진행·해역 보스까지·보스 이름과 약점·다음 해역.
class _RegionCard extends ConsumerWidget {
  const _RegionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final regions = ref.watch(tablesProvider).regions;
    final (stage, wave, best) = ref.watch(
      gameStateProvider.select((s) => (s.progress.stage, s.progress.wave, s.progress.bestStage)),
    );
    final per = regions.stagesPerRegion;
    // 해역 보스는 해역 마지막 스테이지(per의 배수)에 나온다 (regions.bossAt).
    final inRegion = (stage - 1) % per + 1;
    final toBoss = per - inRegion;
    final boss = regions.bossAt(stage + toBoss);
    final next = regions.regionAt(stage + toBoss + 1);

    return PixelFrame(
      key: const Key('voyage.region'),
      padding: 6,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const PixelSprite(UiSprites.tabShip, dots: 16, scale: 1),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${tableText(l10n, regions.regionAt(stage).nameKey)} · ${l10n.uiHudStage(stage, wave)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(l10n.uiRegionProgress(inRegion, per)),
              ],
            ),
            const SizedBox(height: 4),
            PixelBar(value: inRegion / per, fill: Skin.goldBottom),
            const SizedBox(height: 8),
            Text(toBoss == 0 ? l10n.uiRegionBossNow : l10n.uiRegionBossIn(toBoss)),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(tableText(l10n, boss.nameKey), style: const TextStyle(fontWeight: FontWeight.bold)),
                if (boss.weakFamilies.isNotEmpty) WeakChips(boss: boss),
              ],
            ),
            Text(l10n.uiNextRegion(tableText(l10n, next.nameKey)), style: Theme.of(context).textTheme.bodySmall),
            Text(l10n.uiBestStage(best), style: const TextStyle(color: PixelPalette.textDim)),
          ],
        ),
      ),
    );
  }
}

/// 오프라인 시간당 골드·최대 시간, 순풍 남은 시간.
class _StatusLines extends ConsumerWidget {
  const _StatusLines();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final now = ref.watch(clockProvider).now();
    // 받을 때와 같은 계산(경제 offlinePreview)으로 1시간치를 미리 본다.
    final perHour = ref.watch(
      gameStateProvider.select((s) => offlinePreview(s, tables, s.savedAt.add(_hour))?.gold),
    );
    final left = ref.watch(gameStateProvider.select((s) => tailwindRemaining(s, now)));
    final mult = adDef(tables, AdPlacement.tailwind).reward.number('goldMultiplier');
    final maxHours = Duration(seconds: tables.meta.offlineMaxSec).inHours;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoLine(
          icon: const PixelSprite(UiSprites.moon, dots: 16, scale: 1),
          text: Text(l10n.uiOfflineRate((perHour ?? BigNum.zero).format(), maxHours)),
        ),
        // 순풍 줄 옆에도 같은 광고 그림 버튼 (layout-v2-brief).
        _InfoLine(
          icon: const PixelSprite(UiSprites.tailwind, dots: 16, scale: 1),
          text: Text(
            left > Duration.zero ? l10n.uiTailwindStatus(shortDecimal(mult), remainingText(left)) : l10n.uiTailwindOff,
          ),
          trailing: const TailwindAdButton(),
        ),
      ],
    );
  }
}

/// 아이콘 + 글자 한 줄 (ListTile 대신, 도트 화면에 잉크·여백 없이).
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.trailing});

  final Widget icon;
  final Widget text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        icon,
        const SizedBox(width: 8),
        Expanded(child: text),
      ],
    ),
  );
}
