import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/render/hd/hd_portrait.dart';

/// 도감 보스 상세 큰 초상(S1·S4): 표정 3종 순환(moods — 평소 → 예고 붉은 눈 → 쓰러짐 0.8초씩)·못 만난 보스 실루엣.
void main() {
  Widget row() => const Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        child: ColoredBox(
          color: Color(0xFF2E86C8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HdPortrait(kind: 'sea_croc', boss: true, size: 200, animate: true, moods: true, shadow: true),
              HdPortrait(kind: 'coral_golem', boss: true, size: 200, animate: true, moods: true, shadow: true),
              HdPortrait(kind: 'ghost_kraken', boss: true, size: 200, silhouette: true),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('보스 큰 초상: 예고 표정·실루엣', (tester) async {
    tester.view
      ..physicalSize = const Size(600, 200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(row());
    await tester.pump(const Duration(milliseconds: 1000)); // 2번째 0.8초 = 공격 예고
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_portrait_windup.png'));
    await tester.pump(const Duration(milliseconds: 800)); // 3번째 = 쓰러짐
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/hd_portrait_down.png'));
  });
}
