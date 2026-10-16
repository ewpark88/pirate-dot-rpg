import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/hud/fever_slot.dart' show FeverSlot;
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 피버 연출 UI 몫 (사용자 지시 2026-10-16 "조그맣게 나오면 이게 무슨 피버타임이냐 — 극적인 연출").
// 렌더(S3)는 바다 호박색·충격파·배 불꽃을 맡고, UI는 큰 글자·가장자리 불꽃 빛·큰 원형 게이지·끝 알림.
// 색은 렌더와 같은 값(fx_map topEvents.fever: 금 #FFD84A · 주황 #FF8A2A, 테두리 진한 남색 #1B2A4A).

const feverGold = Color(0xFFFFD84A);
const feverOrange = Color(0xFFFF8A2A);
const feverNavy = Color(0xFF1B2A4A);

/// 'FEVER!' 글자가 쾅 → 자리 잡고 → 위로 빠지는 시간, 끝 알림이 떠 있는 시간.
const _slam = Duration(milliseconds: 1300);
const _endShow = Duration(milliseconds: 1600);

/// 피버 끝 알림 글 ('+골드') — 위쪽 알약 줄 오른쪽 칸([FeverSlot])이 잠깐 보인다.
final feverEndTextProvider = NotifierProvider<FeverEndText, String?>(FeverEndText.new);

class FeverEndText extends Notifier<String?> {
  @override
  String? build() => null;

  // 다른 Notifier와 같은 모양(set 메서드)으로 맞춘다.
  // ignore: use_setters_to_change_properties
  void set(String? text) => state = text;
}

/// 전장 위에 얹는 피버 연출 (누름 통과). 전장 가운데는 시작 순간의 큰 글자 말고는 가리지 않는다.
class FeverDrama extends ConsumerStatefulWidget {
  const FeverDrama({super.key});

  @override
  ConsumerState<FeverDrama> createState() => _FeverDramaState();
}

class _FeverDramaState extends ConsumerState<FeverDrama> with SingleTickerProviderStateMixin {
  late final AnimationController _slamCtl = AnimationController(vsync: this, duration: _slam);
  StreamSubscription<RecordedTick>? _sub;
  Timer? _endTimer;

  /// 피버 시작 때 지갑 골드 (끝에 '+골드' 계산), 시작 때 남은 틱(게이지 기준).
  BigNum? _goldAtStart;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is FeverStarted) _start();
        if (e is FeverEnded) _end();
      }
    });
  }

  void _start() {
    if (!mounted) return;
    _goldAtStart = ref.read(gameStateProvider).wallet.gold;
    _endTimer?.cancel();
    ref.read(feverEndTextProvider.notifier).set(null);
    _slamCtl.forward(from: 0).ignore();
  }

  void _end() {
    if (!mounted) return;
    final start = _goldAtStart;
    final now = ref.read(gameStateProvider).wallet.gold;
    final gain = start == null || now < start ? BigNum.zero : now - start;
    ref.read(feverEndTextProvider.notifier).set(AppLocalizations.of(context).uiFeverEnd(gain.format()));
    _endTimer?.cancel();
    _endTimer = Timer(_endShow, () {
      if (mounted) ref.read(feverEndTextProvider.notifier).set(null);
    });
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    unawaited(_sub?.cancel());
    _slamCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (left, tick, flashOn) = ref.watch(
      gameStateProvider.select((s) => (s.battle?.feverTicksLeft ?? 0, s.battle?.tick ?? 0, s.settings.flash)),
    );
    final calm = MediaQuery.disableAnimationsOf(context);
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 가장자리 불꽃 빛 (피버 동안, 가장자리만). 맥박은 전장 틱으로(끝없는 애니메이션 없음). 번쩍임 끄기면 멈춘 옅은 빛.
          if (left > 0) _EdgeGlow(pulse: flashOn && !calm ? 0.45 + 0.15 * math.sin(tick / 6) : 0.3),
          // 'FEVER!' 쾅.
          AnimatedBuilder(
            animation: _slamCtl,
            builder: (context, _) {
              if (!_slamCtl.isAnimating) return const SizedBox.shrink();
              final t = _slamCtl.value;
              // 0~0.25 크게 → 튕기며 자리, ~0.62 머무름, 0.62~1 위로 빠지며 사라짐.
              final scale = calm ? 1.0 : 2.4 - 1.4 * Curves.easeOutBack.transform((t / 0.25).clamp(0, 1).toDouble());
              final out = ((t - 0.62) / 0.38).clamp(0.0, 1.0);
              return Align(
                alignment: Alignment(0, -0.1 - 0.5 * Curves.easeIn.transform(out)),
                child: Opacity(
                  opacity: (1 - out) * (t / 0.08).clamp(0, 1).toDouble(),
                  child: Transform.scale(
                    scale: scale,
                    child: _BigText(l10n.uiFeverBig, key: const Key('fun.fever.big')),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 진한 남색 외곽선 + 금색 글 + 주황 그늘의 큰 글자.
class _BigText extends StatelessWidget {
  const _BigText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    return Stack(
      children: [
        Text(
          text,
          style: Skin.text(size).copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..strokeJoin = StrokeJoin.round
              ..color = feverNavy,
          ),
        ),
        Text(
          text,
          style: Skin.text(size, color: feverGold).copyWith(
            shadows: const [Shadow(color: feverOrange, offset: Offset(0, 4))],
          ),
        ),
      ],
    );
  }
}

/// 화면 네 가장자리에서 안쪽으로 번지는 금·주황 빛 (가운데는 투명).
class _EdgeGlow extends StatelessWidget {
  const _EdgeGlow({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    final a = 0.35 + 0.35 * pulse;
    Widget edge(Alignment begin) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: Alignment(-begin.x, -begin.y),
          // 위아래는 화면이 길어 비율을 더 작게(가장자리만).
          stops: begin.y == 0 ? const [0, 0.05, 0.13] : const [0, 0.025, 0.06],
          colors: [
            feverOrange.withValues(alpha: a),
            feverGold.withValues(alpha: a * 0.55),
            feverGold.withValues(alpha: 0),
          ],
        ),
      ),
    );
    return Stack(
      key: const Key('fun.fever.glow'),
      fit: StackFit.expand,
      children: [
        edge(Alignment.centerLeft),
        edge(Alignment.centerRight),
        edge(Alignment.topCenter),
        edge(Alignment.bottomCenter),
      ],
    );
  }
}
