import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:pirate_dot/ui/bounty/bounty_vm.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_ready.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/state/badge_providers.dart';

/// 도크 탭 i에 지금 할 일이 있나(빨간 점과 같은 판정). 0 항해 · 1 배 · 2 선원 · 3 소환.
final ProviderFamily<bool, int> tabWorkProvider = Provider.family<bool, int>(
  (ref, i) => switch (i) {
    // 항해: 환생 가능 · 보물지도 상점에서 살 칸 · 현상금 티켓이 상한(넘치기 직전).
    0 =>
      ref.watch(rebirthReadyProvider) ||
          ref.watch(rebirthShopProvider.select((s) => s.anyAffordable)) ||
          ref.watch(bountyProvider.select((v) => v.tickets)) >= ref.watch(bountyLimitsProvider).ticketCap,
    1 => ref.watch(shipBadgeProvider),
    2 => ref.watch(crewBadgeProvider),
    3 => ref.watch(summonBadgeProvider),
    _ => false,
  },
);

/// 시트에서 할 일을 다 하면 접는 사이(결과를 잠깐 보게).
const _settle = Duration(milliseconds: 700);

/// 시트 자동 접기(사용자 2026-10-18 '버튼을 다 눌렀으면 자동으로 내려가서 전투를 볼 수 있게'): 열린 탭의 할 일(빨간 점)이
/// 있다가 없어지면(환생 확정·모두 강화로 살 것 없음·일괄 합치기 끝·소환할 젬 없음) 잠깐 뒤 시트를 접는다. 남아 있으면 그대로.
class SheetAutoClose extends ConsumerStatefulWidget {
  const SheetAutoClose({required this.open, required this.tab, super.key});

  final bool open;
  final int tab;

  @override
  ConsumerState<SheetAutoClose> createState() => _SheetAutoCloseState();
}

class _SheetAutoCloseState extends ConsumerState<SheetAutoClose> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tabWorkProvider(widget.tab), (was, now) {
      if (!widget.open || was != true || now) return;
      _timer?.cancel();
      _timer = Timer(_settle, () {
        if (mounted && widget.open && !ref.read(tabWorkProvider(widget.tab))) {
          ref.read(dockTabRequestProvider.notifier).close();
        }
      });
    });
    return const SizedBox.shrink();
  }
}
