import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/top/top_frame.dart';
import 'package:pirate_dot/ui/hud/chest_edge.dart';
import 'package:pirate_dot/ui/hud/chest_tap_hint.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/pixel/pixel_ring.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

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
        return c == null ? null : (c.x, c.y, c.ticksLeft, rewardOf(s), b!.shipY ?? _shipHome.dy);
      }),
    );
    if (chest == null) return const SizedBox.shrink();
    final (x, y, ticksLeft, reward, shipY) = chest;
    final floatTicks = tables.ads.chest.number('floatSec') * Duration.millisecondsPerSecond / tables.waves.tickMs;

    return LayoutBuilder(
      builder: (context, box) {
        // 탑다운 전장 좌표 → 전장 상자 dp (렌더와 같은 topFrameFor: 배 중심이 화면의 정해진 자리).
        final f = topFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context));
        // 렌더가 그린 카메라 그대로(BattleGame.worldToDp — 보스전 당김·확대·피버 좌우 이동 포함, S3). 전장이 Flame이 아니거나
        // (테스트의 빈 상자) 아직 크기를 모르면 같은 계산의 기본 카메라(바다 가운데 · 배 높이).
        final game = ref.watch(hasBattleGameProvider) ? ref.read(battleGameProvider) : null;
        final at = game != null && game.hasLayout
            ? game.worldToDp(Offset(x, y))
            : f.worldToDp(Offset(x, y), Offset(tables.waves.top.shipX, shipY));
        // 카메라 밖(상자 밖)의 보물상자는 보이지 않는다 — 누를 곳은 없고 가장자리 알약만.
        final onScreen = (Offset.zero & box.biggest).contains(at);
        return Stack(
          children: [
            if (onScreen)
              Positioned(
                left: at.dx - _size / 2,
                top: at.dy - _size / 2,
                child: GestureDetector(
                  key: const Key('chest'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showChestChoices(context),
                  // 가이드 v2 '보물상자' 카드가 가리키는 자리.
                  child: TutorialSpot(
                    id: 'chest',
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
                              child: OutlineText(reward.format(), size: 15, tone: OutlineTone.gold),
                            ),
                          // 처음 3번: '톡!'이 통통 (사용자 피드백 #6).
                          const Positioned(top: _rewardOffset - 24, child: ChestTapHint()),
                        ],
                      ),
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
