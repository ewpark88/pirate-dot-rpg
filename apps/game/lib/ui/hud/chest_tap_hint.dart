import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 보물상자를 누르고 싶게 (사용자 피드백 #6, UI 몫): 처음 3번 뜬 상자 위에 '톡!'이 통통 세 번 튀고 멈춘다.
// 몇 번 봤는지는 세이브 hints(chest.tap1~3)에 남긴다. 상자 흔들림·반짝임은 렌더(S3) 몫 — 여기는 글자만.

/// 처음 몇 번 보여 줄지 = 이 id들을 다 볼 때까지.
const chestTapHints = ['chest.tap1', 'chest.tap2', 'chest.tap3'];

/// 튀는 시간(세 번).
const _bounceFor = Duration(milliseconds: 1500);

class ChestTapHint extends ConsumerStatefulWidget {
  const ChestTapHint({super.key});

  @override
  ConsumerState<ChestTapHint> createState() => _ChestTapHintState();
}

class _ChestTapHintState extends ConsumerState<ChestTapHint> with SingleTickerProviderStateMixin {
  // initState에서 만든다 — 지연(late =) 생성이면 안 보이는 상자에서 dispose 때 처음 만들어져 오류가 난다.
  late final AnimationController _t;

  /// 이번 상자에 보여 줄지 (뜰 때 한 번 정한다 — 본 기록이 늦게 와도 깜빡이지 않게).
  late final bool _show;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: _bounceFor);
    final seen = ref.read(gameStateProvider).settings.hints;
    final next = chestTapHints.where((id) => !seen.contains(id)).firstOrNull;
    _show = next != null;
    if (next != null) {
      // 빌드 중 명령을 보내지 않게 한 박자 뒤.
      scheduleMicrotask(() => ref.read(commandSinkProvider).send(MarkHint(next)));
      _t.forward().ignore();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final calm = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) {
          // 세 번 통통 (|sin|), 끝나면 제자리.
          final hop = calm ? 0.0 : math.sin(_t.value * math.pi * 3).abs() * 8;
          return Transform.translate(offset: Offset(0, -hop), child: child);
        },
        child: OutlineText(
          AppLocalizations.of(context).uiChestTap,
          key: const Key('chest.tapHint'),
          size: 18,
          tone: OutlineTone.gold,
        ),
      ),
    );
  }
}
