import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/hud/cargo.dart';

// 광고 버프·보상 칩 (사용자 2026-10-17 '칩이 작아 잘 안 보인다' + S5 실기기 ③ 19dp): 위 막대 안에서 줄어들던 칩을
// 제 크기(44dp, 아이콘 36·외곽선 글자 15)로. 자리는 오른쪽 끝 세로 줄(S1 실기기 ① — 가로 줄은 보스 몸·체력 막대를
// 덮었다; 보스·배는 전장 가운데). 새로 생기면 통통 튀며 등장.

class BuffChips extends StatelessWidget {
  const BuffChips({super.key});

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      key: Key('hud.buffChips'),
      direction: Axis.vertical,
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.end,
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
