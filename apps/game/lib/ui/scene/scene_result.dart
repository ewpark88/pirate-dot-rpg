import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/weak_fleet.dart' show weakFleetWithFeedback;
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/reward_sparkle.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/widgets/reward_fly.dart' show flyRewards;

// 탑·러시·던전·현상금 결과 창 HD 결 (S1 2026-10-18): 도달 층·기록 숫자가 크게 굴러 오르고, 신기록이면 금빛 'NEW RECORD!' 도장 ·
// 폭죽 · 이전 기록에 줄 긋기. 보상 칸은 [확인]을 누르면 위 막대로 날아간다. 실패면 '아깝다! 다음엔 약점 편성' 바로가기.
// 반복 애니메이션 없이 창이 열릴 때 한 번(1.6초).

const _open = Duration(milliseconds: 1600);

/// 보상 한 칸(아이콘 + 글).
typedef SceneRewardItem = ({String icon, String text});

class SceneResultDialog extends ConsumerWidget {
  const SceneResultDialog({
    required this.title,
    required this.big,
    this.lines = const [],
    this.rewards = const [],
    this.record = false,
    this.previous,
    this.failed = false,
    this.icon,
    this.okKey = const Key('scene.result.ok'),
    super.key,
  });

  final String title;

  /// 크게 굴러 오르는 숫자: 끝값과 글 만들기(진행 중 값 → 글).
  final ({int value, String Function(int) text})? big;
  final List<String> lines;
  final List<SceneRewardItem> rewards;

  /// 신기록이면 도장·폭죽, [previous]는 줄 그은 이전 기록 글.
  final bool record;
  final String? previous;

  /// 실패면 '아깝다! 다음엔 약점 편성' 바로가기.
  final bool failed;
  final Widget? icon;

  /// [확인] 버튼 키(현상금은 'bounty.result.ok').
  final Key okKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final calm = MediaQuery.disableAnimationsOf(context);
    void ok() {
      if (rewards.isNotEmpty) flyRewards(context, [for (final r in rewards) r.icon]);
      Navigator.of(context).pop();
    }

    return PixelDialog(
      title: title,
      icon: icon,
      content: TweenAnimationBuilder<double>(
        tween: Tween(begin: calm ? 1 : 0, end: 1),
        duration: _open,
        builder: (context, t, _) {
          // 0~0.55 숫자 굴림 · 0.55~0.8 도장 쾅 · 0.55~1 폭죽.
          final roll = Curves.easeOutCubic.transform((t / 0.55).clamp(0.0, 1.0));
          final stamp = ((t - 0.55) / 0.25).clamp(0.0, 1.0);
          final burst = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (big case final b?)
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (record && burst > 0 && burst < 1)
                      Positioned.fill(
                        child: IgnorePointer(child: CustomPaint(painter: _Fireworks(burst))),
                      ),
                    OutlineText(
                      b.text(t >= 1 ? b.value : (b.value * roll).round()),
                      key: const Key('scene.result.big'),
                      size: 40,
                      tone: record ? OutlineTone.gold : OutlineTone.white,
                    ),
                  ],
                ),
              if (record && stamp > 0)
                Transform.rotate(
                  angle: -0.14,
                  child: Transform.scale(
                    scale: 1 + 1.4 * (1 - Curves.easeOutBack.transform(stamp)),
                    child: Container(
                      key: const Key('scene.result.record'),
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Skin.goldBottom, width: 3),
                        color: const Color(0x33FFD84A),
                      ),
                      child: OutlineText(l10n.uiNewRecord, size: 20, tone: OutlineTone.gold),
                    ),
                  ),
                ),
              if (record && previous != null) ...[
                const SizedBox(height: 6),
                Text(
                  previous!,
                  key: const Key('scene.result.previous'),
                  style: Skin.text(14, color: Skin.sub).copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Skin.danger,
                    decorationThickness: 2,
                  ),
                ),
              ],
              for (final line in lines) Text(line, textAlign: TextAlign.center, style: Skin.text(16)),
              if (rewards.isNotEmpty) ...[
                const SizedBox(height: 10),
                RewardSparkle(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      for (final r in rewards)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SkinIcon(r.icon, size: 26),
                            const SizedBox(width: 4),
                            OutlineText(r.text, size: 22, tone: OutlineTone.gold),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              if (failed) ...[
                const SizedBox(height: 10),
                Text(l10n.uiSceneSoClose, style: Skin.bold(15, color: Skin.danger)),
                const SizedBox(height: 4),
                SkinButton(
                  key: const Key('scene.result.weak'),
                  tone: SkinTone.gold,
                  height: 44,
                  onPressed: () {
                    weakFleetWithFeedback(context, ref);
                    ref.read(dockTabRequestProvider.notifier).open(crewTabIndex);
                    Navigator.of(context).pop();
                  },
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiWeakFleet)),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        SkinButton(key: okKey, onPressed: ok, child: Text(l10n.uiOk)),
      ],
    );
  }
}

/// 신기록 폭죽: 숫자 둘레에서 금빛·분홍·하늘 불꽃이 한 번 퍼진다(번호로 정한 방향).
class _Fireworks extends CustomPainter {
  _Fireworks(this.t);

  final double t;

  static const List<Color> _colors = [Color(0xFFFFD84A), Color(0xFFFF7EB6), Color(0xFF7FD8FF), Colors.white];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final fade = 1 - t;
    for (final center in [Offset(size.width * 0.15, size.height * 0.3), Offset(size.width * 0.85, size.height * 0.2)]) {
      for (var i = 0; i < 14; i++) {
        final a = i / 14 * 2 * math.pi + rnd.nextDouble() * 0.3;
        final d = (28 + rnd.nextDouble() * 18) * Curves.easeOutCubic.transform(t);
        final p = center + Offset(math.cos(a) * d, math.sin(a) * d + 10 * t * t);
        canvas.drawCircle(
          p,
          2.4 * fade + 0.6,
          Paint()..color = _colors[i % _colors.length].withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Fireworks old) => old.t != t;
}
