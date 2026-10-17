import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/dock/sheet_auto_close.dart';
import 'package:pirate_dot/ui/dock/upgrade_all.dart';
import 'package:pirate_dot/ui/hud/boss_fail_notice.dart';
import 'package:pirate_dot/ui/hud/boss_intro.dart';
import 'package:pirate_dot/ui/hud/buff_chips.dart';
import 'package:pirate_dot/ui/hud/cargo.dart';
import 'package:pirate_dot/ui/hud/fast_sail.dart';
import 'package:pirate_dot/ui/hud/fever_slot.dart';
import 'package:pirate_dot/ui/hud/fun_strips.dart';
import 'package:pirate_dot/ui/hud/stage_gauge.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_ready.dart';
import 'package:pirate_dot/ui/scene/scene_vm.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 전장 위쪽 (선원 줄·시트를 가리지 않게, 전장 가운데 60%를 덮지 않게): 진행 게이지(+목표·파밍·피버) · 왼쪽 위 작은 알약들 · 보스 실패 안내. 튜토리얼·가이드 카드는 가이드 층(GuideLayer)이 그린다.
/// 전폭 불투명 띠 금지(사용자 지시 2026-10-16) — 띠는 모두 왼쪽 위 작은 알약.
class BattleTopStrip extends StatelessWidget {
  const BattleTopStrip({required this.tutorial, this.sheetOpen = false, this.sheetTab = 0, super.key});

  /// 튜토리얼 중인가 (알약을 줄이는 데 쓸 수 있게 남겨 둔다 — 말풍선은 가이드 층으로 옮김).
  final bool tutorial;

  /// 아래 시트가 열려 있는가 — 보스 실패 안내를 토스트로 줄인다.
  final bool sheetOpen;

  /// 열린 시트의 탭(할 일을 다 하면 자동 접기).
  final int sheetTab;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // 진행 게이지 + 다음 목표 한 줄 (전투력은 상단 바 골드 옆).
      const _HudTopReporter(child: StageGauge()),
      // 왼쪽 위 작은 알약들 (현상금·돌발 이벤트·즉석 도전) — 옆으로 나란히, 넘치면 다음 줄. 누름 통과.
      // 현상금 전투 중에는 돌발 이벤트·도전이 멈추므로(계획 '영향') 현상금 알약만.
      // 빠른 항해 돌파 중엔 알약 대신 돌파 띠(현상금·돌발 이벤트는 구간 동안 안 생긴다).
      const Padding(padding: EdgeInsets.fromLTRB(10, 4, 10, 0), child: _PillsOrFastSail()),
      // 광고 버프·보상 칩(44dp) — 오른쪽 끝 세로 줄(보스·배는 가운데라 안 겹친다, 실기기 ① 2026-10-17).
      const Padding(padding: EdgeInsets.only(top: 4), child: BuffChips()), // 오른쪽 여백은 BuffChips가(접힘은 끝에 붙임)
      // 보스 등장 이름표 (2초).
      const BossIntro(),
      BossFailNotice(sheetOpen: sheetOpen),
      const RebirthReadyNotice(),
      SheetAutoClose(open: sheetOpen, tab: sheetTab),
    ],
  );
}

class _PillsOrFastSail extends ConsumerWidget {
  const _PillsOrFastSail();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(fastSailProvider) == null ? const _Pills() : const FastSailBanner();
}

class _Pills extends ConsumerWidget {
  const _Pills();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 보스전·장면 모드·현상금 중엔 띠 아래 알약 줄을 비운다(사용자 2026-10-18 '보스와의 전투를 가린다') — 그 글은 띠 안에.
    final quiet =
        ref.watch(sceneLabelProvider) || ref.watch(gameStateProvider.select((s) => s.battle?.bossActive ?? false));
    final challenge = ref.watch(gameStateProvider.select((s) => s.battle?.challenge != null));
    final cargoFull = ref.watch(cargoLevelProvider) == 2;
    final rebirth = ref.watch(rebirthReadyProvider);
    // 우선순위: 도전 > 환생 가능 > 화물칸 가득. 늘 한 줄(실기기 ④ — 전장 위가 3줄이 됐다): 한 묶음만,
    // 좁으면 줄여서. 돌발 이벤트는 띠 안 아이콘(SeaEventIcon). 도전이 끝난 '성공' 알약은 도전 자리에 잠깐.
    final List<Widget> pills;
    if (quiet) {
      pills = const [];
    } else {
      // 묶음 하나 = 한 칸. 화물칸 가득 + 바로 '모두 강화'는 한 칸.
      final ranked = <List<Widget>>[
        if (challenge) const [ChallengeStrip()],
        // 환생이 화물칸보다 먼저(사용자 2026-10-18 '환생이 이제 안 나온다' — 화물칸 가득이 늘 자리를 차지했다).
        if (rebirth) const [RebirthReadyPill()],
        if (cargoFull) const [CargoFullPill(), UpgradeAllPill()],
      ];
      pills = [...ranked.take(1).expand((g) => g), if (!challenge) const ChallengeStrip()];
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, p) in pills.indexed) ...[if (i > 0) const SizedBox(width: 6), p],
                ],
              ),
            ),
          ),
        ),
        if (!ref.watch(sceneActiveProvider)) const FeverSlot(),
      ],
    );
  }
}

/// 띠 아래 끝 + 8dp를 전장(BattleGame.hudTopDp)에 알린다 — S3 보스 카메라 안전 영역(fx_map topCam). 띠는 전장 상자 위에
/// 붙어 있어 띠 높이 = 전장 위에서 잰 값. 태블릿(uiScale)·보스전(막대 2줄)에 따라 바뀌므로 그릴 때마다 잰다.
class _HudTopReporter extends ConsumerStatefulWidget {
  const _HudTopReporter({required this.child});

  final Widget child;

  @override
  ConsumerState<_HudTopReporter> createState() => _HudTopReporterState();
}

class _HudTopReporterState extends ConsumerState<_HudTopReporter> {
  double? _sent;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(hasBattleGameProvider)) return;
      final h = context.size?.height;
      if (h == null || h + 8 == _sent) return;
      _sent = h + 8;
      ref.read(battleGameProvider).hudTopDp = _sent!;
    });
    return widget.child;
  }
}
