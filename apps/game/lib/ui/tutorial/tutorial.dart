import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/guide/guide_spots.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 튜토리얼 단계 → 가리킬 곳 (설계서 4.12 표). 가리킬 위젯은 [TutorialSpot]으로 감싼다. 말·손가락·어둡게는 가이드 층(GuideLayer).
const Map<int, Set<String>> tutorialSpots = {
  1: {},
  // 2단계: 도크의 빠른 강화(‘여기를 눌러 배를 강화해요’)와 배 패널의 대포 강화.
  2: {'tab.ship', 'ship.upgrade.cannon', 'quick.upgrade'},
  3: {'quick.upgrade', 'ship.upgrade.cannon', 'boss.challenge'},
  4: {'tab.summon', 'summon.ten'},
  5: {'tab.crew', 'crew.mergeAll'},
  6: {'goal'},
};

/// UI 동작으로 끝나는 단계 — 카드의 '알겠어요'가 TutorialAck를 보낸다. 나머지는 코어가 상태로 판정한다.
/// (4단계 ‘소환 결과 닫기’는 소환 탭이 10회 소환 직후 보낸다.)
const tutorialAckSteps = {1, 6};

/// 현재 튜토리얼 단계 (null = 끝·건너뜀).
final tutorialStepProvider = Provider<int?>((ref) => ref.watch(gameStateProvider.select((s) => s.tutorialStep)));

/// 가이드가 가리키는 위젯: 금색 테두리 + 자리 등록(가이드 층이 그 자리만 밝히고 큰 손가락을 얹는다).
/// [force]는 가이드와 별개의 길 안내(첫 환생·화물칸 바로가기) — 작은 손을 직접 그린다.
class TutorialSpot extends ConsumerStatefulWidget {
  const TutorialSpot({required this.id, required this.child, this.force = false, super.key});

  final String id;
  final Widget child;

  /// 단계와 상관없이 가리킨다 (UI 길 안내 — 예: 첫 환생 손가락).
  final bool force;

  @override
  ConsumerState<TutorialSpot> createState() => _TutorialSpotState();
}

class _TutorialSpotState extends ConsumerState<TutorialSpot> {
  final GlobalKey _key = GlobalKey();
  bool _registered = false;

  void _sync(bool pointed) {
    if (pointed == _registered) return;
    _registered = pointed;
    pointed ? putGuideSpot(widget.id, _key) : removeGuideSpot(widget.id, _key);
  }

  @override
  void dispose() {
    _sync(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guided = ref.watch(guidePointedProvider.select((ids) => ids.contains(widget.id)));
    _sync(guided);
    // 트리 모양을 늘 같게(가리킴이 켜지고 꺼져도 child 상태가 남게) — 테두리만 바뀐다.
    final pointed = guided || widget.force;
    return Stack(
      // 가리키지 않을 때는 받던 크기 제약을 그대로(감싸지 않은 것과 같은 배치), 가리킬 때는 예전처럼 느슨하게.
      fit: pointed ? StackFit.loose : StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          key: _key,
          position: DecorationPosition.foreground,
          // 도트 강조: 금색 네모 테두리 2칸.
          decoration: pointed
              ? BoxDecoration(
                  border: Border.all(color: PixelPalette.gold, width: pixelUnit(context) * 2),
                )
              : const BoxDecoration(),
          child: widget.child,
        ),
        if (pointed)
          Positioned(
            right: -6,
            bottom: -10,
            child: IgnorePointer(
              // 가이드가 가리키면 큰 손가락은 가이드 층이 그린다 — 여기는 자리 표시(키)만.
              child: widget.force
                  ? PixelSprite(UiSprites.hand, dots: 16, key: Key('tutorial.spot.${widget.id}'))
                  : SizedBox.shrink(key: Key('tutorial.spot.${widget.id}')),
            ),
          ),
      ],
    );
  }
}
