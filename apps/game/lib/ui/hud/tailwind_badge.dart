import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart' show audioPortProvider;
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

/// 남은 시간을 다시 그리는 주기.
const _tick = Duration(seconds: 1);

/// 흐린 아이콘의 불투명도 (순풍 없음).
const _inactiveOpacity = 0.4;

/// 순풍 버프 표시 (설계서 4.6): 켜져 있으면 남은 시간과 배율, 아니면 흐린 돛 아이콘.
// TODO(ui): 누르면 ‘광고 보고 30분 ×2’ 버튼 — 광고 포트(AdsPort)가 생기면. 로드 안 되면 숨김.
class TailwindBadge extends ConsumerStatefulWidget {
  const TailwindBadge({super.key});

  @override
  ConsumerState<TailwindBadge> createState() => _TailwindBadgeState();
}

class _TailwindBadgeState extends ConsumerState<TailwindBadge> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    // 상태가 바뀌지 않아도 남은 시간은 줄어든다 → 1초마다 다시 그린다.
    _timer = Timer.periodic(_tick, (_) => setState(() {}));
    // 켜지는 순간: 효과 한 줄 토스트 + '휘익'(사용자 2026-10-18 '속도 ×2 효과가 밋밋, 사서 쓰고 싶게').
    final t = ref.read(tablesProvider);
    ref.listenManual(
      gameStateProvider.select((s) {
        final now = ref.read(clockProvider).now();
        return (tailwindRemaining(s, now) > Duration.zero, purchasedSpeed(s, t, now) != null);
      }),
      (was, now) {
        if (was == null || !mounted) return;
        final l10n = AppLocalizations.of(context);
        final reward = t.ads.placements.firstWhere((p) => p.id == 'tailwind').reward;
        String? text;
        if (now.$1 && !was.$1) {
          text = l10n.uiSpeedOnTailwind(
            shortDecimal(reward.number('speedMultiplier')),
            shortDecimal(reward.number('goldMultiplier')),
          );
        } else if (now.$2 && !was.$2) {
          text = l10n.uiSpeedOnPaid(shortDecimal(t.iap.speedMultiplier.toDouble()));
        }
        if (text == null) return;
        showSkinToast(context, text);
        ref.read(audioPortProvider)?.playSfx('skill', pitch: 1.2);
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = ref.watch(clockProvider).now();
    // 남은 시간은 경제 tailwindRemaining (끝났으면 zero).
    final left = ref.watch(gameStateProvider.select((s) => tailwindRemaining(s, now)));
    final paid = ref.watch(gameStateProvider.select((s) => purchasedSpeed(s, ref.read(tablesProvider), now) != null));
    final tail = left > Duration.zero;
    final active = tail || paid;
    // 바람 고리 돌기: 전장 틱 기준(끝없는 애니메이션 없음).
    final spin = active ? ref.watch(gameStateProvider.select((s) => (s.battle?.tick ?? 0) % 120)) / 120 : 0.0;
    final reward = ref.watch(tablesProvider).ads.placements.firstWhere((p) => p.id == 'tailwind').reward;
    // 남은 시간 막대: 광고 한 번(durationSec) 기준 — 겹쳐 봐서 더 길면 가득.
    final full = Duration(seconds: reward.integer('durationSec'));

    final speed = tail ? reward.number('speedMultiplier') : ref.watch(tablesProvider).iap.speedMultiplier.toDouble();
    final chip = Container(
      key: const Key('tailwind'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      // k1: 짙은 남색 알약 + 외곽선. 켜지면 금빛 테.
      decoration: BoxDecoration(
        color: Skin.navyPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? const Color(0xFFFFD84A) : Skin.outline, width: 2),
        boxShadow: Skin.shadowSmall,
      ),
      child: Opacity(
        opacity: active ? 1 : _inactiveOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PixelSprite(UiSprites.tailwind, dots: 16, scale: 1),
                if (tail) ...[
                  const SizedBox(width: 4),
                  Text(remainingText(left), style: Skin.outlined(14, color: const Color(0xFF8CF5B8))),
                ],
                if (active) ...[
                  const SizedBox(width: 4),
                  // 금빛 큰 '×2'(사용자 2026-10-18 '사서 쓰고 싶게').
                  Text(
                    l10n.uiEffectMultiplier(shortDecimal(speed)),
                    key: const Key('tailwind.speed'),
                    style: Skin.outlined(19, color: const Color(0xFFFFD84A)),
                  ),
                ],
              ],
            ),
            if (tail)
              SizedBox(
                width: 64,
                child: SkinBar(
                  key: const Key('tailwind.bar'),
                  value: left.inSeconds / full.inSeconds,
                  color: const Color(0xFF8CF5B8),
                  height: 5,
                ),
              ),
          ],
        ),
      ),
    );
    if (!active) return chip;
    // 켜진 동안 칩 둘레에 바람 고리가 돈다.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(key: const Key('tailwind.ring'), painter: _WindRing(spin)),
          ),
        ),
        chip,
      ],
    );
  }
}

/// 칩 둘레 바람 줄 3개(돌아간다).
class _WindRing extends CustomPainter {
  _WindRing(this.turn);

  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius((Offset.zero & size).inflate(4), const Radius.circular(20));
    final metric = (Path()..addRRect(r)).computeMetrics().first;
    final paint = Paint()
      ..color = const Color(0xCC8CF5B8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      final start = (turn + k / 3) % 1 * metric.length;
      canvas.drawPath(metric.extractPath(start, start + metric.length * 0.12), paint);
    }
  }

  @override
  bool shouldRepaint(_WindRing old) => old.turn != turn;
}
