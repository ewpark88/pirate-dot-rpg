import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/fever_drama.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 위쪽 알약 줄 오른쪽 칸: 피버 동안 원형 남은 시간, 끝나면 '+골드' 알림 잠깐.
/// 알약·보스 실패 안내와 같은 흐름(줄) 안에 있어 서로 겹치지 않는다(S1 ① 2026-10-16).
class FeverSlot extends ConsumerStatefulWidget {
  const FeverSlot({super.key});

  @override
  ConsumerState<FeverSlot> createState() => _FeverSlotState();
}

class _FeverSlotState extends ConsumerState<FeverSlot> {
  /// 이번 피버의 처음 남은 틱(고리 비율 기준).
  int _total = 1;

  @override
  Widget build(BuildContext context) {
    final left = ref.watch(gameStateProvider.select((s) => s.battle?.feverTicksLeft ?? 0));
    final end = ref.watch(feverEndTextProvider);
    if (left <= 0) {
      _total = 1;
      if (end == null) return const SizedBox.shrink();
      return Container(
        key: const Key('fun.fever.end'),
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: feverNavy.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: feverGold, width: 2),
        ),
        child: Text(
          end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Skin.text(14, color: feverGold),
        ),
      );
    }
    _total = math.max(_total, left);
    final seconds = (left * ref.read(tablesProvider).waves.tickMs / Duration.millisecondsPerSecond).ceil();
    return IgnorePointer(
      child: _FeverRing(key: const Key('fun.fever.on'), value: left / _total, seconds: seconds),
    );
  }
}

/// 큰 원형 남은 시간: 금 고리 + 가운데 남은 초 + 'FEVER'.
class _FeverRing extends StatelessWidget {
  const _FeverRing({required this.value, required this.seconds, super.key});

  final double value;
  final int seconds;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 64,
    child: CustomPaint(
      painter: _RingPainter(value.clamp(0, 1).toDouble()),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(seconds.toString(), style: Skin.text(24, color: feverGold)),
            OutlineText(AppLocalizations.of(context).uiFever, size: 10),
          ],
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 5;
    canvas
      ..drawCircle(c, r + 4, Paint()..color = feverNavy.withValues(alpha: 0.85))
      ..drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = Colors.white24,
      )
      ..drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..shader = const SweepGradient(colors: [feverGold, feverOrange, feverGold]).createShader(
            Rect.fromCircle(center: c, radius: r),
          ),
      );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
