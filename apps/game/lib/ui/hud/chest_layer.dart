import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/render/battle_game.dart';
import 'package:pirate_dot/ui/meta/meta_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 상자 탭 영역 지름 (화면 픽셀).
const _size = 44.0;

/// 금액 글자를 상자 위로 띄우는 높이.
const _rewardOffset = -18.0;

/// 떠내려온 보물상자 탭 영역 (설계서 4.6). 전장 위에 겹쳐, 전장 논리 좌표(320×180)를 화면 크기로 늘려 놓는다.
/// 상자 그림은 렌더 레인이 그리고, 여기는 누를 곳·가라앉기까지 남은 시간 링·기본 보상 금액만.
// TODO(ui): 광고 ×5 · 젬 버튼(Key 'chest.ad') — 광고 포트(AdsPort)가 생기면. 로드 안 되면 숨김 (4.6).
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
        final scale = box.maxWidth / kLogicalWidth;
        return Stack(
          children: [
            Positioned(
              left: x * scale - _size / 2,
              top: y * scale - _size / 2,
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
                      CircularProgressIndicator(
                        value: (ticksLeft / floatTicks).clamp(0.0, 1.0),
                        strokeWidth: 3,
                        color: Colors.amber,
                      ),
                      if (reward != null)
                        Positioned(
                          top: _rewardOffset,
                          child: Text(
                            reward.format(),
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
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
