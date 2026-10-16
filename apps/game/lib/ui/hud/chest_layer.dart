import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
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
/// 배 자리를 아직 안 보낸 프레임의 기본 배 중심 (탑다운 전장 270×480의 가운데).
const _shipHome = Offset(135, 240);

/// 상자 광고 말풍선 크기(dp).
const _bubbleWidth = 190.0;
const _bubbleHeight = 44.0;

class ChestLayer extends ConsumerWidget {
  const ChestLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    final rewardOf = ref.watch(chestRewardProvider);
    final chest = ref.watch(
      gameStateProvider.select((s) {
        final b = s.battle;
        final c = b?.chest;
        return c == null
            ? null
            : (c.x, c.y, c.ticksLeft, rewardOf(s), b!.shipX ?? _shipHome.dx, b.shipY ?? _shipHome.dy);
      }),
    );
    if (chest == null) return const SizedBox.shrink();
    final (x, y, ticksLeft, reward, shipX, shipY) = chest;
    final floatTicks = tables.ads.chest.number('floatSec') * Duration.millisecondsPerSecond / tables.waves.tickMs;

    return LayoutBuilder(
      builder: (context, box) {
        // 탑다운 전장 좌표 → 전장 상자 dp (렌더와 같은 topFrameFor: 배 중심이 화면의 정해진 자리).
        final f = topFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context));
        final at = f.worldToDp(Offset(x, y), Offset(shipX, shipY));
        // 카메라 밖(상자 밖)의 보물상자는 보이지 않는다 — 누를 곳도 없다.
        if (!(Offset.zero & box.biggest).contains(at)) return const SizedBox.shrink();
        // 광고 제안은 상자 옆 작은 말풍선(반투명, 상자를 따라감) — 전장 위 전폭 띠 금지(사용자 지시 2026-10-16).
        final bubbleLeft = (at.dx - _bubbleWidth / 2).clamp(4.0, box.maxWidth - _bubbleWidth - 4);
        final above = at.dy - _size / 2 - _bubbleHeight - 6;
        final bubbleTop = above >= 0 ? above : at.dy + _size / 2 + 6;
        return Stack(
          children: [
            Positioned(
              left: bubbleLeft,
              top: bubbleTop,
              width: _bubbleWidth,
              height: _bubbleHeight,
              child: const ChestAdBubble(),
            ),
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

/// 상자 광고 말풍선: 반투명 흰 판 안에 [골드 ×5] [젬] 작은 버튼 (광고가 준비됐을 때만).
class ChestAdBubble extends ConsumerWidget {
  const ChestAdBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adOfferProvider(AdPlacement.chest))) return const SizedBox.shrink();
    return Container(
      key: const Key('chest.adBubble'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const FittedBox(child: ChestAdButtons()),
    );
  }
}
