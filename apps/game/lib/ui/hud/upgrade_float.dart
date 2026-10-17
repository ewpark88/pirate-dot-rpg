import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';

/// 강화 떠오름 '+대포 Lv 9'(빠른 강화가 넣는다) — 번호가 바뀔 때마다 다시 떠오른다.
typedef UpgradeFloatMsg = ({int serial, String text});

final upgradeFloatProvider = NotifierProvider<UpgradeFloat, UpgradeFloatMsg?>(UpgradeFloat.new);

class UpgradeFloat extends Notifier<UpgradeFloatMsg?> {
  @override
  UpgradeFloatMsg? build() => null;

  void show(String text) => state = (serial: (state?.serial ?? 0) + 1, text: text);
}

/// 배 체력 막대 바로 위 가운데에서 떠올라 사라지는 강화 글 (S1 실기기 2026-10-18 — 빠른 강화 버튼 위에 띄우면 잠긴 선원 칸을
/// 덮었다). 전장 오버레이(BattleButtons)가 안전 영역 안에 둔다.
class UpgradeFloatLabel extends ConsumerWidget {
  const UpgradeFloatLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msg = ref.watch(upgradeFloatProvider);
    if (msg == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(msg.serial),
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 900),
        builder: (_, t, child) => t >= 1
            ? const SizedBox.shrink()
            : Transform.translate(
                offset: Offset(0, -26 * t),
                child: Opacity(opacity: (1 - t * t).clamp(0, 1).toDouble(), child: child),
              ),
        child: Center(
          child: OutlineText(msg.text, key: const Key('quick.upgrade.float'), size: 15, tone: OutlineTone.gold),
        ),
      ),
    );
  }
}
