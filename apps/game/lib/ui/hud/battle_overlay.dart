import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/render/scene/slot_states.dart';
import 'package:pirate_dot/ui/bounty/bounty_battle.dart';
import 'package:pirate_dot/ui/crew/crew_detail.dart';
import 'package:pirate_dot/ui/crew/fleet_sheet.dart';
import 'package:pirate_dot/ui/hud/battle_hud_buttons.dart';
import 'package:pirate_dot/ui/hud/boss_challenge_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 선원 줄 오른쪽 끝 버튼 (layout-v2-brief 3, S3 좌표 약속 `battleFrameFor`):
/// 궁극기 = 렌더가 그린 자리(초상·함성 게이지) 위 투명 버튼, 보스 도전 = 파밍 중일 때만 그 왼쪽 도트 버튼.
/// 전장 필드 안에는 누르는 것을 두지 않는다(보물상자 탭은 예외 — ChestLayer).
class BattleButtons extends ConsumerWidget {
  const BattleButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) {
        final f = battleFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context));
        // 시트를 거의 끝까지 열어 전장이 아주 작으면(궁극기 원이 전장 위로 삐져 상단 바를 덮음) 버튼을 숨긴다.
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
            // 선원 칸: 누르면 후보 시트 (수동 편성). 빈 칸은 ‘+’.
            // 선원 칸 3상태 (그림은 렌더 slot_states): 출전 중 = 선원 상세, 열린 빈 칸 = 편성 시트, 잠김 = 열리는 조건 안내.
            for (final (i, r) in f.slotRects.indexed)
              Positioned.fromRect(
                rect: hit(r),
                child: _SlotButton(slot: i, rect: r),
              ),
            // 궁극기 표시(꼬리표·함성 원형 게이지·%·탭!·발동 띠) — 누름 통과, 그 위에 투명 버튼.
            Positioned.fill(child: UltimateHud(rect: f.ultimateRect)),
            Positioned.fromRect(rect: hit(f.ultimateRect), child: const _UltimateButton()),
            // 보스 도전: 보스 초상 + '보스 도전!' (글이 들어가게 칸 왼쪽으로 넓힘, 오른쪽 끝은 칸에 맞춤).
            Positioned(
              right: box.maxWidth - f.bossRect.right,
              top: f.bossRect.center.dy - 22,
              height: 44,
              child: const BossChallengeButton(),
            ),
            // 현상금 전투 중에는 같은 자리에 후퇴 버튼 (보스 도전은 파밍 중에만이라 겹치지 않는다).
            Positioned.fromRect(rect: hit(f.bossRect), child: const BountyRetreatButton()),
          ],
        );
      },
    );
  }
}

/// 궁극기: 그림은 렌더(ultimateRect), 여기서는 누르는 영역만. 함성이 가득일 때만 누를 수 있다.
class _UltimateButton extends ConsumerWidget {
  const _UltimateButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rageMax = ref.watch(tablesProvider).skills.rageMax;
    final full = ref.watch(gameStateProvider.select((s) => s.progress.rage >= rageMax));
    final label = AppLocalizations.of(context).uiHudUltimate;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: full,
        label: label,
        child: GestureDetector(
          key: const Key('hud.ultimate'),
          behavior: HitTestBehavior.opaque,
          onTap: full ? () => ref.read(commandSinkProvider).send(const TriggerUltimate()) : null,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

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
            style: Skin.text(11, color: Colors.white).copyWith(
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
