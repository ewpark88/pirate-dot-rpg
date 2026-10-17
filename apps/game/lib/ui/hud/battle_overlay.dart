import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/slot_states.dart';
import 'package:pirate_dot/ui/crew/crew_detail.dart';
import 'package:pirate_dot/ui/crew/fleet_sheet.dart';
import 'package:pirate_dot/ui/hud/boss_break.dart';
import 'package:pirate_dot/ui/hud/boss_challenge_button.dart';
import 'package:pirate_dot/ui/hud/boss_cutin_name.dart';
import 'package:pirate_dot/ui/hud/hp_bars.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 선원 줄 오른쪽 끝 버튼 (layout-v2-brief 3, S3 좌표 약속 `battleFrameFor`):
/// 보스 도전 = 파밍 중일 때만 도트 버튼(궁극기 버튼은 없앰 — 피버 첫 일격, 2026-10-17).
/// 전장 필드 안에는 누르는 것을 두지 않는다(보물상자 탭은 예외 — ChestLayer).
class BattleButtons extends ConsumerWidget {
  const BattleButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final f = battleFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context));
        // 시트를 거의 끝까지 열어 전장이 아주 작으면(줄 위 칸이 전장 위로 삐져 상단 바를 덮음) 버튼을 숨긴다.
        if (f.ultimateRect.top < 0) return const SizedBox.shrink();
        // 그림 자리가 48dp보다 작으면 누르는 영역만 가운데 기준으로 키운다.
        Rect hit(Rect r) => Rect.fromCenter(
          center: r.center,
          width: r.width < kMinTap ? kMinTap : r.width,
          height: r.height < kMinTap ? kMinTap : r.height,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 해역 보스 첫 등장 컷인(렌더) 위 보스 이름 — 컷인 동안만.
            const Positioned.fill(child: BossCutInName()),
            // 내 배 체력: 선원 줄 바로 위 전폭(사용자 2026-10-17 '배 체력이 안 보인다' — 늘 보인다).
            // 늘 전폭(S1·S4 2026-10-17 — 보스 도전 버튼 자리 때문에 끊기지 않게, 버튼은 막대 위로 올린다).
            Positioned(
              left: 8,
              right: 8,
              top: f.slotBand.top - _hpBarAbove,
              height: _hpBarHeight,
              child: const ShipHpBar(),
            ),
            // 보스가 쓰러지는 순간 보스 자리에 'BREAK!' (누름 통과).
            const Positioned.fill(child: BossBreakBurst()),
            // 선원 칸: 누르면 후보 시트 (수동 편성). 빈 칸은 ‘+’.
            // 선원 칸 3상태 (그림은 렌더 slot_states): 출전 중 = 선원 상세, 열린 빈 칸 = 편성 시트, 잠김 = 열리는 조건 안내.
            for (final (i, r) in f.slotRects.indexed)
              Positioned.fromRect(
                rect: hit(r),
                child: _SlotButton(slot: i, rect: r),
              ),
            // 보스 도전(사용자 피드백 #9 D·#26): 원형 56dp를 화면 오른쪽 가장자리에 붙이고 배 체력 막대 바로 위에 띄운다(엄지 자리,
            // 막대와 겹치지 않게 — S1 2026-10-17).
            Positioned(
              right: bossChallengeEdge,
              top: f.slotBand.top - _hpBarAbove - bossChallengeGap - bossChallengeHeight,
              child: const BossChallengeButton(),
            ),
          ],
        );
      },
    );
  }
}

/// 배 체력 막대: 선원 줄 윗변보다 이만큼 위에서 시작, 높이.
const _hpBarAbove = 24.0;
const _hpBarHeight = 20.0;

/// 선원 줄 한 칸 (렌더 slot_states와 같은 규칙): 출전 선원은 왼쪽부터 채워 그려진다(activeFleet).
/// 출전 중 → 선원 상세, 열린 빈 칸 → 편성 시트(빈 자리에 앉힘), 잠김 → ‘스테이지 N에서 열림’ 안내 + 칸 아래 작은 ‘스테이지 N’.
class _SlotButton extends ConsumerWidget {
  const _SlotButton({required this.slot, required this.rect});

  final int slot;

  /// 그림 칸 (누르는 영역은 48dp 이상으로 키워져 있을 수 있다).
  final Rect rect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final (crewId, open) = ref.watch(
      gameStateProvider.select((s) {
        final active = activeFleet(s, tables);
        return (slot < active.length ? active[slot] : null, slot < fleetSlots(s, tables));
      }),
    );
    final String label;
    final VoidCallback onTap;
    Widget? overlay;
    if (crewId != null) {
      final def = tables.crews.byId(crewId);
      label = tableText(l10n, def.nameKey);
      onTap = () => unawaited(showCrewDetail(context, def));
      overlay = _SlotDamage(crewId: crewId);
    } else if (open) {
      label = l10n.uiFleetEmptySlot;
      onTap = () {
        final empty = ref.read(fleetSlotsProvider).indexOf(null);
        openFleetPicker(context, empty < 0 ? slot : empty);
      };
    } else {
      final stage = slotUnlockStage(tables, slot);
      if (stage == null) return const SizedBox.shrink();
      // 생성된 함수 인자 순서: (stage, tier).
      label = l10n.uiFleetSlotLocked(stage, tableText(l10n, tables.shipTiers.tierAt(stage).nameKey));
      onTap = () => showSkinToast(context, label);
      overlay = Align(
        alignment: const Alignment(0, 0.72),
        // 좁은 칸(360dp)에서도 한 줄 — 줄바꿈 대신 줄여 맞춘다.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.uiFleetSlotStage(stage),
            key: Key('fleet.locked.label.$slot'),
            maxLines: 1,
            style: Skin.outlined(11).copyWith(
              shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3)],
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      label: '${l10n.uiFleetSlotTitle(slot + 1)} · $label',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key(crewId != null ? 'fleet.crew.$slot' : (open ? 'fleet.slot.$slot' : 'fleet.locked.$slot')),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: overlay,
      ),
    );
  }
}

/// 선원 칸 아래 이번 스테이지 피해량(사용자 피드백 #13, BattleView.crewDamage — 남은 HP로 자른 실제 피해, 큰 수 줄임). 누름 통과.
class _SlotDamage extends ConsumerWidget {
  const _SlotDamage({required this.crewId});

  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 줄임 글이 바뀔 때만 다시 그린다(피해는 매 틱 늘어난다).
    final text = ref.watch(gameStateProvider.select((s) => s.battle?.crewDamage[crewId]?.format()));
    if (text == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.95),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            key: Key('fleet.damage.$crewId'),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(6)),
            // 숫자만 있으면 뭔지 몰라서(사용자 피드백 5번) — 작은 칼 + '피해 12K'.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CustomPaint(size: Size(10, 10), painter: _SwordPainter()),
                const SizedBox(width: 2),
                Text(
                  AppLocalizations.of(context).uiSlotDamage(text),
                  maxLines: 1,
                  style: Skin.outlined(12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 작은 칼 한 자루(대각선 칼날 + 손잡이) — 선원 칸 피해 표시.
class _SwordPainter extends CustomPainter {
  const _SwordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas
      ..drawLine(
        Offset(w * 0.9, w * 0.1),
        Offset(w * 0.3, w * 0.7),
        Paint()
          ..color = const Color(0xFFFFE27A)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        Offset(w * 0.15, w * 0.5),
        Offset(w * 0.5, w * 0.85),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        Offset(w * 0.3, w * 0.7),
        Offset(w * 0.1, w * 0.9),
        Paint()
          ..color = const Color(0xFFB07A3A)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
  }

  @override
  bool shouldRepaint(_SwordPainter old) => false;
}
