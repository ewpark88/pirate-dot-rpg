import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 튜토리얼 단계 → 손가락으로 가리킬 곳 (설계서 4.12 표). 가리킬 위젯은 [TutorialSpot]으로 감싼다.
const Map<int, Set<String>> tutorialSpots = {
  1: {},
  // 2단계: 도크의 빠른 강화(‘여기를 눌러 배를 강화해요’)와 배 패널의 대포 강화.
  2: {'tab.ship', 'ship.upgrade.cannon', 'quick.upgrade'},
  3: {'ship.upgrade.cannon', 'boss.challenge'},
  4: {'tab.summon', 'summon.ten'},
  5: {'tab.crew', 'crew.mergeAll'},
  6: {'goal'},
};

/// UI 동작으로 끝나는 단계 — 말풍선의 확인 버튼이 TutorialAck를 보낸다. 나머지는 코어가 상태로 판정한다.
/// (4단계 ‘소환 결과 닫기’는 소환 탭이 10회 소환 직후 보낸다.)
const _ackSteps = {1, 6};

/// 현재 튜토리얼 단계 (null = 끝·건너뜀).
final tutorialStepProvider = Provider<int?>((ref) => ref.watch(gameStateProvider.select((s) => s.tutorialStep)));

/// 튜토리얼이 가리키는 위젯에 테두리와 손가락을 겹친다. 가리키지 않으면 [child] 그대로.
class TutorialSpot extends ConsumerWidget {
  const TutorialSpot({required this.id, required this.child, super.key});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(tutorialStepProvider);
    if (!(tutorialSpots[step]?.contains(id) ?? false)) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          position: DecorationPosition.foreground,
          // 도트 강조: 금색 네모 테두리 2칸.
          decoration: BoxDecoration(
            border: Border.all(color: PixelPalette.gold, width: pixelUnit(context) * 2),
          ),
          child: child,
        ),
        Positioned(
          right: -6,
          bottom: -10,
          child: IgnorePointer(
            child: PixelSprite(UiSprites.hand, dots: 16, key: Key('tutorial.spot.$id')),
          ),
        ),
      ],
    );
  }
}

/// 튜토리얼 말풍선 한 줄 — 전장과 탭 패널 사이에 자리를 차지해 둘 다 가리지 않는다. 건너뛰기는 항상 보인다.
class TutorialBubble extends ConsumerWidget {
  const TutorialBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(tutorialStepProvider);
    if (step == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final text = switch (step) {
      1 => l10n.uiTutStep1,
      2 => l10n.uiTutStep2,
      3 => l10n.uiTutStep3,
      4 => l10n.uiTutStep4,
      5 => l10n.uiTutStep5,
      _ => l10n.uiTutStep6,
    };
    void send(Command c) => ref.read(commandSinkProvider).send(c);

    // 도트 말풍선: 금색 테두리 도트 프레임 + 말풍선 아이콘, 버튼은 도트 버튼.
    return Padding(
      key: const Key('tutorial.bubble'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: PixelFrame(
        border: PixelPalette.gold,
        padding: 4,
        child: Row(
          children: [
            const PixelSprite(UiSprites.bubble, dots: 16, scale: 1),
            const SizedBox(width: 6),
            Expanded(child: Text(text)),
            if (_ackSteps.contains(step))
              PixelButton(
                key: const Key('tutorial.ok'),
                primary: true,
                onPressed: () => send(TutorialAck(step)),
                child: Text(l10n.uiTutOk),
              ),
            const SizedBox(width: 4),
            PixelButton(
              key: const Key('tutorial.skip'),
              onPressed: () => send(const SkipTutorial()),
              child: Text(l10n.uiTutSkip),
            ),
          ],
        ),
      ),
    );
  }
}
