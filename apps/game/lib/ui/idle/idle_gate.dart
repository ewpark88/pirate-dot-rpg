import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/state/idle.dart';

// 발열·배터리·OLED 잔상 대책 (사용자 지시 2026-10-16, S1).
// ① 입력 없음이 길면 절전 화면: 검은 반투명 덮개(밝기 15%) + 가운데 작은 정보, 전투는 계속. 터치하면 즉시 복귀 — 그 터치는 게임에 안 간다.
// ② 잔상 방지: 평소 2분마다 화면 전체를 1~2dp 미세 이동(눈에 안 띄게). 절전 중엔 고정 UI가 덮개 아래로 숨는다.
// ③ 방치 단계는 idleLevelProvider(공용)로 렌더·오디오가 본다.

/// 단계를 다시 보는 간격.
const _check = Duration(seconds: 5);

/// 잔상 방지 미세 이동 주기와 폭(dp).
const _shiftEvery = Duration(minutes: 2);
const _shiftMax = 2.0;

class IdleGate extends ConsumerStatefulWidget {
  const IdleGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<IdleGate> createState() => _IdleGateState();
}

class _IdleGateState extends ConsumerState<IdleGate> {
  Timer? _timer;
  Offset _shift = Offset.zero;
  var _shiftStep = 0;
  late DateTime _lastShift;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    ref.read(idleLevelProvider.notifier).touch(now);
    _lastShift = now;
    _timer = Timer.periodic(_check, (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final now = ref.read(clockProvider).now();
    // 설정 '절전 모드'가 켜져 있을 때만 절전 화면(끄면 idle 신호만). 시간은 S2 설정 키(autoSleepMin)가 오면 그 값.
    final powerSave = ref.read(gameStateProvider).settings.powerSave;
    ref.read(idleLevelProvider.notifier).evaluate(now, sleepAfter: powerSave ? sleepAfterDefault : null);
    // 미세 이동: 2분마다 정해진 8방향 중 다음 자리(최대 2dp).
    if (now.difference(_lastShift) >= _shiftEvery) {
      _lastShift = now;
      _shiftStep = (_shiftStep + 1) % 8;
      final a = _shiftStep * math.pi / 4;
      setState(() => _shift = Offset(math.cos(a), math.sin(a)) * (_shiftStep.isEven ? _shiftMax : _shiftMax / 2));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sleeping = ref.watch(idleLevelProvider) == IdleLevel.sleep;
    final notifier = ref.read(idleLevelProvider.notifier);
    return Listener(
      // 모든 입력이 방치 시계를 되돌린다 (눌림이 게임으로 가는 것은 막지 않는다).
      onPointerDown: (_) => notifier.touch(ref.read(clockProvider).now()),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          Transform.translate(offset: _shift, child: widget.child),
          if (sleeping) const Positioned.fill(child: _SleepCover()),
        ],
      ),
    );
  }
}

/// 절전 덮개: 화면 밝기 약 15%로 낮춘 검은 판 + 가운데 스테이지·골드·안내. 누르면 복귀(누름은 덮개가 먹는다).
class _SleepCover extends ConsumerWidget {
  const _SleepCover();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (stage, gold) = ref.watch(gameStateProvider.select((s) => (s.progress.stage, s.wallet.gold)));
    return GestureDetector(
      key: const Key('idle.sleep'),
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(idleLevelProvider.notifier).touch(ref.read(clockProvider).now()),
      child: ColoredBox(
        color: const Color(0xD9000000),
        child: Center(
          child: DefaultTextStyle(
            style: Skin.text(15, color: const Color(0x99FFFFFF)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.uiSleepStage(stage)),
                const SizedBox(height: 4),
                // 앱 위(Navigator 밖)라 길게 누르기 툴팁이 없는 평범한 글.
                Text(gold.format(), style: Skin.text(18, color: const Color(0x99FFD447))),
                const SizedBox(height: 12),
                Text(l10n.uiSleepTouch, style: Skin.text(13, color: const Color(0x80FFFFFF))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
