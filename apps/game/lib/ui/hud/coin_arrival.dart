import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';

// 코인 도착 (렌더 coinFlow 계약): 처치 코인이 상단 바 골드 아이콘으로 날아간다.
// 사용자 지시(2026-10-15): 아이콘 통통·'+금액'은 조잡하니 없앤다 — 상단 골드는 지갑 값이 실시간으로 바뀌기만 한다.

/// 상단 바 골드 아이콘 자리를 찾는 키 (전장 상자 기준 좌표로 바꿔 렌더에 준다).
final GlobalKey topGoldIconKey = GlobalKey(debugLabel: 'top.gold.icon');

/// 전장 상자 안에 둔다: 상단 바 골드 아이콘 중심을 상자 기준 dp로 바꿔 렌더에 알린다(코인이 그쪽으로 날아감).
/// 상자 크기가 바뀌면(시트 끌기) 다시 계산한다.
class CoinLink extends ConsumerStatefulWidget {
  const CoinLink({super.key});

  @override
  ConsumerState<CoinLink> createState() => _CoinLinkState();
}

class _CoinLinkState extends ConsumerState<CoinLink> {
  Offset? _sent;

  void _sync() {
    if (!mounted || !ref.read(hasBattleGameProvider)) return;
    final box = context.findRenderObject() as RenderBox?;
    final icon = topGoldIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || icon == null || !box.attached || !icon.attached) return;
    final target = box.globalToLocal(icon.localToGlobal(icon.size.center(Offset.zero)));
    if (target != _sent) {
      _sent = target;
      ref.read(battleGameProvider).goldTargetDp = target;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _sync());
      return const SizedBox.expand();
    },
  );
}
