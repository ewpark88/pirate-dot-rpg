import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_ring.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 상자 탭 영역 지름 (화면 픽셀).
const _size = 44.0;

/// 금액 글자를 상자 위로 띄우는 높이.
const _rewardOffset = -18.0;

/// 떠내려온 보물상자 탭 영역 (설계서 4.6). 전장 위에 겹쳐, 게임 좌표를 `battleFrameFor`로 dp에 놓는다.
/// 상자 그림은 렌더 레인이 그리고, 여기는 누를 곳·가라앉기까지 남은 시간 링·기본 보상 금액만.
class ChestLayer extends ConsumerWidget {
  const ChestLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    final rewardOf = ref.watch(chestRewardProvider);
    final chest = ref.watch(
      gameStateProvider.select((s) {
        final c = s.battle?.chest;
        return c == null ? null : (c.x, c.y, c.ticksLeft, rewardOf(s));
      }),
    );
    if (chest == null) return const SizedBox.shrink();
    final (x, y, ticksLeft, reward) = chest;
    final floatTicks = tables.ads.chest.number('floatSec') * Duration.millisecondsPerSecond / tables.waves.tickMs;

    return LayoutBuilder(
      builder: (context, box) {
        // 게임 좌표 → 전장 상자 dp (렌더와 같은 battleFrameFor).
        final f = battleFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context));
        final at = f.toDp(Offset(x, y));
        // 필드가 상자보다 넓으면(렌더 k+1) 상자 밖의 보물상자는 보이지 않는다 — 누를 곳도 없다.
        if (!(Offset.zero & box.biggest).contains(at)) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned(
              left: at.dx - _size / 2,
              top: at.dy - _size / 2,
              child: GestureDetector(
                key: const Key('chest'),
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(commandSinkProvider).send(const TapChest()),
                child: SizedBox.square(
                  dimension: _size,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      PixelRing(value: (ticksLeft / floatTicks).clamp(0.0, 1.0)),
                      if (reward != null)
                        Positioned(
                          top: _rewardOffset,
                          child: Text(
                            reward.format(),
                            style: const TextStyle(color: PixelPalette.gold, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 상자 광고 줄 (전장 바로 아래, 상자가 떠 있고 광고가 준비됐을 때만): 상자 그림 + 골드 ×5 · 젬.
/// 전장 안에는 버튼을 두지 않는다 (layout-v2-brief 2).
class ChestAdStrip extends ConsumerWidget {
  const ChestAdStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasChest = ref.watch(gameStateProvider.select((s) => s.battle?.chest != null));
    if (!hasChest || !ref.watch(adOfferProvider(AdPlacement.chest))) return const SizedBox.shrink();
    return const ColoredBox(
      key: Key('chest.adStrip'),
      color: PixelPalette.outline,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Center(child: ChestAdButtons()),
      ),
    );
  }
}
