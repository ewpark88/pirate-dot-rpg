import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/summon/summon_result.dart';

/// `lastSummon`이 생기면 소환 연출 화면을 띄운다 (설계서 4.12 팝업 ‘소환 결과’, 사용자 지시 2026-10-15: 카드를 열 때 기대감).
class SummonResultGate extends ConsumerStatefulWidget {
  const SummonResultGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SummonResultGate> createState() => _SummonResultGateState();
}

class _SummonResultGateState extends ConsumerState<SummonResultGate> {
  var _open = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(gameStateProvider.select((s) => s.lastSummon), (_, results) => _show(results));
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(ref.read(gameStateProvider).lastSummon));
  }

  void _show(List<SummonResult>? results) {
    if (_open || results == null || results.isEmpty || !mounted) return;
    _open = true;
    unawaited(
      Navigator.of(context)
          .push(
            PageRouteBuilder<void>(
              opaque: false,
              transitionDuration: const Duration(milliseconds: 250),
              pageBuilder: (_, _, _) => SummonResultDialog(results: results),
              transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
            ),
          )
          .whenComplete(() => _open = false),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
