import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/ui/crew/fleet_sheet.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bitmap.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 선원 줄 오른쪽 끝 버튼 (layout-v2-brief 3, S3 좌표 약속 `battleFrameFor`):
/// 궁극기 = 렌더가 그린 자리(초상·함성 게이지) 위 투명 버튼, 보스 도전 = 파밍 중일 때만 그 왼쪽 도트 버튼.
/// 전장 필드 안에는 누르는 것을 두지 않는다(보물상자 탭은 예외 — ChestLayer).
class BattleButtons extends ConsumerWidget {
  const BattleButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 지금 배 등급이 연 칸만 누를 수 있다 (나머지 칸 그림은 렌더가 잠금으로 그린다).
    final slotCount = ref.watch(fleetSlotsProvider.select((s) => s.length));
    return LayoutBuilder(
      builder: (context, box) {
        final f = battleFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context));
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
            for (final (i, r) in f.slotRects.take(slotCount).indexed)
              Positioned.fromRect(
                rect: hit(r),
                child: _SlotButton(slot: i),
              ),
            Positioned.fromRect(rect: hit(f.ultimateRect), child: const _UltimateButton()),
            Positioned.fromRect(rect: hit(f.bossRect), child: const _BossChallengeButton()),
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

/// 파밍 중(보스를 못 잡아 제자리 항해)이면 보스 도전 (설계서 4.1-4). 파밍 그림 버튼.
class _BossChallengeButton extends ConsumerWidget {
  const _BossChallengeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(gameStateProvider.select((s) => s.progress.farming && !(s.battle?.bossActive ?? false)));
    if (!show) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return TutorialSpot(
      id: 'boss.challenge',
      child: Tooltip(
        message: l10n.uiBossChallenge,
        child: PixelButton(
          key: const Key('boss.challenge'),
          primary: true,
          semanticLabel: l10n.uiBossChallenge,
          onPressed: () => ref.read(commandSinkProvider).send(const ChallengeBoss()),
          // 칸이 50dp 안팎이라 그림만 (글자는 낭독·길게 누르기 설명으로).
          child: const PixelSprite(UiSprites.farm, dots: 16),
        ),
      ),
    );
  }
}

/// 선원 줄 한 칸: 투명 버튼(그림은 렌더), 빈 칸이면 가운데 ‘+’.
class _SlotButton extends ConsumerWidget {
  const _SlotButton({required this.slot});

  final int slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = ref.watch(fleetSlotsProvider.select((s) => slot < s.length ? s[slot] : null));
    final tables = ref.watch(tablesProvider);
    final label = id == null ? l10n.uiFleetEmptySlot : tableText(l10n, tables.crews.byId(id).nameKey);
    return Semantics(
      button: true,
      label: '${l10n.uiFleetSlotTitle(slot + 1)} · $label',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('fleet.slot.$slot'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openFleetPicker(context, slot),
        child: id == null ? const Center(child: PixelBitmap(PixelBitmaps.plus, color: PixelPalette.textDim)) : null,
      ),
    );
  }
}
