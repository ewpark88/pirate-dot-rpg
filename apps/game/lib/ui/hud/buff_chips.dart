import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/hud/cargo.dart';

// 광고 버프·보상 칩 (사용자 2026-10-17 '칩이 작아 잘 안 보인다' + S5 실기기 ③ 19dp): 위 막대 안에서 줄어들던 칩을
// 게이지 아래 오른쪽 줄로 옮겨 제 크기(44dp, 아이콘 36·외곽선 글자 15)로 보인다. 새로 생기면 통통 튀며 등장.

class BuffChips extends StatelessWidget {
  const BuffChips({super.key});

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      key: Key('hud.buffChips'),
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        _PopIn(child: TailwindAdButton()),
        _PopIn(child: BossSupportAdButton()),
        _PopIn(child: AutoUpgradeChip()),
      ],
    ),
  );
}

/// 처음 그려질 때 60% → 100%로 통통 (350ms, easeOutBack). 동작 줄이기면 바로.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0.6, end: 1),
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutBack,
    builder: (_, s, child) => Transform.scale(scale: s, child: child),
    // 칩은 받은 폭만큼 늘어나게 짜여 있다(위 막대 FittedBox 안에서 쓰던 것) — 내용 폭으로 묶는다.
    child: IntrinsicWidth(child: child),
  );
}
