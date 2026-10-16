import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/top/ship_preview.dart';
import 'package:pirate_dot/ui/bounty/bounty_battle.dart';
import 'package:pirate_dot/ui/dock/dock_panels.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/dock/home_dock.dart';
import 'package:pirate_dot/ui/hud/battle_overlay.dart';
import 'package:pirate_dot/ui/hud/battle_top_strip.dart';
import 'package:pirate_dot/ui/hud/bottle_choices.dart';
import 'package:pirate_dot/ui/hud/chest_layer.dart';
import 'package:pirate_dot/ui/hud/coin_arrival.dart';
import 'package:pirate_dot/ui/hud/fever_drama.dart';
import 'package:pirate_dot/ui/hud/fleet_rejected_toast.dart';
import 'package:pirate_dot/ui/hud/save_failure_banner.dart';
import 'package:pirate_dot/ui/hud/top_bar.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/offline/offline_reward.dart';
import 'package:pirate_dot/ui/ship/ship_look.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/analytics_provider.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/summon/summon_gate.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 한 화면 (사용자 결정 2026-10-15 ‘도크 + 끌어올리는 시트’): 평소엔 전투가 상단 바 아래 화면 전체,
/// 아래 엄지 자리에 도크(아이콘 4개 + 빠른 강화). 아이콘을 누르면 그 패널이 아래에서 올라와 화면 절반(끌면 거의 전체).
/// 같은 아이콘·아래로 끌기·전투 영역 탭·뒤로 가기 = 닫기, 다른 아이콘 = 패널만 교체. 탭 4개 고정(설계서 4.9).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// 시트 높이 스냅 (본문 높이 대비): 닫힘 · 절반 · 거의 전체.
const _snapHalf = 0.5;
const _snapFull = 0.9;

/// 이 속도(본문 높이/초) 이상으로 튕기면 그 방향 다음 스냅으로.
const _flingVelocity = 1.2;

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  var _tab = 0;

  /// 시트 높이 비율 (0 = 닫힘). 스냅은 통통 튀는 이징.
  late final AnimationController _sheet = AnimationController(vsync: this, upperBound: _snapFull);

  /// 끌기 중 높이 계산용 본문 높이.
  double _bodyHeight = 1;

  bool get _open => _sheet.value > 0.01;

  @override
  void initState() {
    super.initState();
    // 이탈 분석(설계서 4.9): 마지막으로 본 화면·스테이지.
    ref.listenManual(gameStateProvider.select((s) => s.progress.stage), (_, _) => _reportLastSeen());
    _reportLastSeen();
    // 알약·안내의 바로가기(환생 가능 → 항해 탭 등): 그 탭 시트를 연다.
    ref.listenManual(dockTabRequestProvider, (_, tab) {
      if (tab == null) return;
      setState(() => _tab = tab);
      if (!_open) _snapTo(_snapHalf);
      ref.read(dockTabRequestProvider.notifier).done();
      _reportLastSeen();
    });
    // 배 미리보기 그림을 미리 읽어 둔다(배 탭 첫 그림 깜빡임 없음 — 렌더 S3 권장). 실패해도 위젯이 스스로 읽는다.
    final tables = ref.read(tablesProvider);
    unawaited(
      ShipPreview.preload(
        tables,
        skins: {
          for (final id in ['coral', 'storm', 'gold', 'phantom']) id: ?skinPalette(tables, id),
        },
      ).catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _reportLastSeen() => ref
      .read(analyticsPortProvider)
      .setLastSeen(screen: analyticsTabIds[_tab], stage: ref.read(gameStateProvider).progress.stage);

  void _snapTo(double target) {
    unawaited(_sheet.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutBack));
  }

  void _tapIcon(int i) {
    if (_open && _tab == i) {
      _snapTo(0);
    } else {
      setState(() => _tab = i);
      if (!_open) _snapTo(_snapHalf);
    }
    _reportLastSeen();
  }

  void _close() => _snapTo(0);

  void _dragUpdate(DragUpdateDetails d) {
    _sheet.value = (_sheet.value - d.delta.dy / _bodyHeight).clamp(0.0, _snapFull);
  }

  void _dragEnd(DragEndDetails d) {
    final v = -d.velocity.pixelsPerSecond.dy / _bodyHeight;
    const snaps = [0.0, _snapHalf, _snapFull];
    final double target;
    if (v.abs() > _flingVelocity) {
      target = v > 0
          ? snaps.firstWhere((s) => s > _sheet.value + 0.01, orElse: () => _snapFull)
          : snaps.lastWhere((s) => s < _sheet.value - 0.01, orElse: () => 0);
    } else {
      target = snaps.reduce((a, b) => (a - _sheet.value).abs() < (b - _sheet.value).abs() ? a : b);
    }
    _snapTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final tutorial = ref.watch(tutorialStepProvider) != null;
    return OfflineRewardGate(
      child: SummonResultGate(
        child: RebirthDoneGate(
          child: BountyResultGate(
            child: ShipLookCelebrationGate(
              child: FleetRejectedToast(
                child: PopScope(
                  // 뒤로 가기 = 시트 닫기 (열려 있을 때).
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (!didPop && _open) _close();
                  },
                  child: Scaffold(
                    body: SafeArea(
                      child: Column(
                        children: [
                          const SaveFailureBanner(),
                          const TopBar(),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, body) {
                                _bodyHeight = body.maxHeight;
                                return AnimatedBuilder(
                                  animation: _sheet,
                                  builder: (context, _) => _layout(context, body, tutorial: tutorial),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, BoxConstraints body, {required bool tutorial}) {
    final sheetH = _sheet.value * body.maxHeight;
    // 전장 상자는 시트(열림)나 도크(닫힘) 위에서 끝난다 — 렌더가 받은 상자를 채우므로 선원 줄·궁극기가 늘 그 바로 위에 붙는다.
    final battleBottom = math.max(sheetH, kDockHeight);
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: battleBottom,
          child: GestureDetector(
            // 시트가 열렸을 때 전투 영역의 빈 곳을 누르면 닫힌다(보물상자·칸 버튼은 자기가 먼저 받는다).
            behavior: HitTestBehavior.translucent,
            // 화면 낭독용 닫기는 뒤로 가기·손잡이로 — 전장 전체가 ‘누를 수 있는 곳’으로 읽히지 않게.
            excludeFromSemantics: true,
            onTap: _open ? _close : null,
            child: Stack(
              key: const Key('battle.area'),
              fit: StackFit.expand,
              children: [
                ref.watch(battleViewBuilderProvider)?.call(context) ?? GameWidget(game: ref.watch(battleGameProvider)),
                const ChestLayer(),
                const BattleButtons(),
                // 피버 연출 (큰 글자·가장자리 빛·큰 원형 게이지 — 누름 통과).
                const FeverDrama(),
                // 유리병 쪽지 3장 (전장 안 말풍선).
                const BottleChoices(),
                // 코인 도착: 골드 아이콘 자리를 렌더에 알린다(그림·누름 없음).
                const IgnorePointer(child: CoinLink()),
              ],
            ),
          ),
        ),
        // 위쪽 띠 (게이지·목표·전투력·안내·말풍선).
        Positioned(left: 0, right: 0, top: 0, child: BattleTopStrip(tutorial: tutorial)),
        // 도크: 시트 위(닫힘이면 화면 아래). 도크 위에는 아무것도 얹지 않는다 — 전장 상자가 도크 높이만큼만 비켜 있으므로(선원 줄 가림 버그).
        Positioned(
          left: 0,
          right: 0,
          bottom: sheetH,
          child: Column(
            key: const Key('dock.bottom'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_open) HomeDock(open: null, onTap: _tapIcon),
            ],
          ),
        ),
        if (_open)
          Positioned(
            key: const Key('sheet.panel'),
            left: 0,
            right: 0,
            bottom: 0,
            height: sheetH,
            child: _sheetPanel(context),
          ),
      ],
    );
  }

  /// 패널 시트: 손잡이(끌기) + 도크(패널 바꾸기) + 탭 내용. 태블릿은 폭 제한·가운데.
  Widget _sheetPanel(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Skin.sky,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [BoxShadow(color: Skin.shadowColor, blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          // 여닫는 동안 시트가 손잡이·도크보다 낮으면 내용을 위에 맞춰 자른다(넘침 없이).
          child: LayoutBuilder(
            builder: (context, box) => OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: math.max(box.maxHeight, _sheetMinContent),
              maxHeight: math.max(box.maxHeight, _sheetMinContent),
              child: Column(
                children: [
                  GestureDetector(
                    key: const Key('sheet.handle'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _dragUpdate,
                    onVerticalDragEnd: _dragEnd,
                    child: Semantics(
                      label: AppLocalizations.of(context).uiPanelHandle,
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(color: Skin.plainEdge, borderRadius: BorderRadius.circular(3)),
                          ),
                          HomeDock(open: _tab, onTap: _tapIcon),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: DockPanels(tab: _tab),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 시트 내용이 넘치지 않는 최소 높이(dp): 손잡이 + 도크 + 탭 내용 조금.
const double _sheetMinContent = 6 + 5 + kDockHeight + 48;

/// 시트 최대 폭(dp) — 태블릿에서 가운데.
const _sheetMaxWidth = 720.0;
