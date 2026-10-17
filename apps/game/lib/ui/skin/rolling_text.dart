import 'package:flutter/material.dart';

// 숫자 롤링 (모션 기준 #50, S1 2026-10-17): 값이 바뀌면 새 글이 아래에서 굴러 올라오고 옛 글은 위로 빠진다(260ms).
// 틱마다 바뀌는 숫자(골드·젬 — 사용자 '실시간, 따로 움직이는 연출 없음')에는 쓰지 않는다. 전투력처럼 가끔 바뀌는 곳만.

const rollFor = Duration(milliseconds: 260);

class RollingText extends StatelessWidget {
  const RollingText(this.text, {this.style, this.textKey, this.duration = rollFor, super.key});

  final String text;
  final TextStyle? style;

  /// 안쪽 Text의 key (테스트가 읽는 자리 그대로).
  final Key? textKey;

  /// 굴러가는 시간 (전투력은 0.5초 — S1 '강화의 손맛').
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: calm ? Duration.zero : duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, a) {
        // 들어오는 글: 아래(+) → 제자리, 나가는 글: 제자리 → 위(−). 둘 다 같은 a(1 → 0이 나감)를 쓴다.
        final incoming = child.key == ValueKey(text);
        // 한 줄 높이만큼(1.0) 밀어 두 글이 같은 줄에서 겹치지 않게 — 0.7이면 반쯤 겹쳐 뭉개져 보였다(S1 실기기 2026-10-18).
        final slide = Tween<Offset>(begin: Offset(0, incoming ? 1 : -1), end: Offset.zero).animate(a);
        return ClipRect(
          child: SlideTransition(
            position: slide,
            child: FadeTransition(opacity: a, child: child),
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(text),
        child: Text(text, key: textKey, style: style),
      ),
    );
  }
}
