import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/ui/hud/chest_edge.dart';
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
        // 카메라 밖(상자 밖)의 보물상자는 보이지 않는다 — 누를 곳은 없고 가장자리 알약만.
        final onScreen = (Offset.zero & box.biggest).contains(at);
        // 광고 제안은 상자 위 말풍선 대신 왼쪽 가장자리 작은 알약(ChestEdgePill) — 상자를 누르면 같은 선택 시트(사용자 지시 2026-10-16).
        final slots = battleFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context)).slotRects;
        final slotTop = slots.isEmpty ? box.maxHeight : slots.map((r) => r.top).reduce((a, b) => a < b ? a : b);
        // 세로: 전장 높이 55% 근처, 선원 줄 위로 8dp 여유.
        final pillTop = (box.maxHeight * 0.55).clamp(0.0, slotTop - chestPillSize.height - 8);
        return Stack(
          children: [
            Positioned(left: 4, top: pillTop, child: const ChestEdgePill()),
            if (onScreen)
              Positioned(
                left: at.dx - _size / 2,
                top: at.dy - _size / 2,
                child: GestureDetector(
                  key: const Key('chest'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showChestChoices(context),
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
