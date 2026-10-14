import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pirate_dot/adapters/system_clock.dart';
import 'package:pirate_dot/operator/operator_panel.dart';

/// 몇 번 눌러야 열리나 (설계서 6.10).
const _tapsToOpen = 5;

/// 그 안에 다 눌러야 하는 시간.
const _tapWindow = Duration(seconds: 2);

/// 패널 시트의 최대 높이 비율 — 위쪽 HUD를 가리지 않는다.
const _sheetMaxHeight = 0.7;

/// 감싼 위젯을 [_tapWindow] 안에 [_tapsToOpen]번 누르면 운영자 패널을 하단 시트로 연다.
/// 호출하는 쪽은 `if (kOperator)` 안에서만 감싼다 — 배포 빌드에는 이 제스처 자체가 없다.
class OperatorTapGate extends StatefulWidget {
  const OperatorTapGate({required this.child, super.key});

  final Widget child;

  @override
  State<OperatorTapGate> createState() => _OperatorTapGateState();
}

class _OperatorTapGateState extends State<OperatorTapGate> {
  final _taps = <DateTime>[];

  void _onTap() {
    final now = const SystemClock().now();
    _taps
      ..add(now)
      ..removeWhere((t) => now.difference(t) > _tapWindow);
    if (_taps.length < _tapsToOpen) return;
    _taps.clear();
    unawaited(showOperatorPanel(context));
  }

  @override
  Widget build(BuildContext context) =>
      GestureDetector(behavior: HitTestBehavior.opaque, onTap: _onTap, child: widget.child);
}

/// 운영자 패널을 하단 시트로 연다. 전장이 보이도록 바깥을 어둡게 하지 않는다.
Future<void> showOperatorPanel(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  barrierColor: Colors.transparent,
  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * _sheetMaxHeight),
  builder: (_) => const OperatorPanel(),
);
