import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/crew/collection_reward_row.dart';
import 'package:pirate_dot/ui/crew/crew_detail.dart';
import 'package:pirate_dot/ui/crew/crew_identity.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart' show GuideHold, guideHoldProvider;
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/fleet_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

// 수집의 재미 (사용자 2026-10-17 '초반에 선원이 중구난방으로 모여 어떻게 쓸지 체감이 안 된다'): 새 동료가 합류하는 순간
// (CardGranted isNew — 보스 드롭·시작 선원·현상금·오프라인·돌발. 소환은 결과 창이 따로) S3 앞면 공개 연출 뒤에
// '새 동료!' 카드: 역할 배지 · '이렇게 싸워요' 한 줄 · 공격 특색 아이콘 · [출전시키기] · '도감 7/40 · 다음 보상까지 3명'.

/// S3 카드 앞면 공개 연출이 끝나기를 기다리는 시간.
const newMateDelay = Duration(milliseconds: 2600);

/// 역할 5가지 = 표 crews[].role (S2 BALANCE 역할표, game_data crewRoles와 같은 이름).
enum CrewRole { guard, boss, mob, control, support }

CrewRole crewRoleOf(GameTables t, String crewId) => CrewRole.values.byName(t.crews.byId(crewId).role);

String roleText(AppLocalizations l, CrewRole r) => switch (r) {
  CrewRole.guard => l.uiRoleGuard,
  CrewRole.boss => l.uiRoleBoss,
  CrewRole.mob => l.uiRoleMob,
  CrewRole.control => l.uiRoleControl,
  CrewRole.support => l.uiRoleSupport,
};

IconData roleIcon(CrewRole r) => switch (r) {
  CrewRole.guard => Icons.shield_rounded,
  CrewRole.boss => Icons.gps_fixed_rounded,
  CrewRole.mob => Icons.blur_circular_rounded,
  CrewRole.control => Icons.ac_unit_rounded,
  CrewRole.support => Icons.favorite_rounded,
};

/// 새 동료가 들어오면(연출 뒤) 카드를 띄운다. 여러 명이면 차례로.
class NewMateGate extends ConsumerStatefulWidget {
  const NewMateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NewMateGate> createState() => _NewMateGateState();
}

class _NewMateGateState extends ConsumerState<NewMateGate> {
  StreamSubscription<RecordedTick>? _sub;
  final _queue = <(String, String)>[];
  Timer? _wait;
  bool _open = false;

  // dispose에서 ref를 쓸 수 없어 미리 잡아 둔다(환영 카드 때 가이드 접기).
  late final GuideHold _hold;

  @override
  void initState() {
    super.initState();
    _hold = ref.read(guideHoldProvider.notifier);
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        // 환영 카드(튜토리얼): 시트를 닫고 가이드 말을 접어 전장 가운데 카드 연출이 보이게(S3 c12ced0a).
        if (e is CardGranted && e.source == 'starter') {
          ref.read(dockTabRequestProvider.notifier).close();
          _hold.hold(newMateDelay);
        }
        if (e is CardGranted && e.isNew && !_queue.any((q) => q.$1 == e.crewId)) {
          _queue.add((e.crewId, e.rarity));
          _wait ??= Timer(newMateDelay, _next);
        }
      }
    });
  }

  Future<void> _next() async {
    _wait = null;
    if (!mounted || _open || _queue.isEmpty) return;
    _open = true;
    final (id, rarity) = _queue.removeAt(0);
    await showSkinDialog<void>(
      context,
      builder: (_) => NewMateDialog(crewId: id, rarityId: rarity),
    );
    _open = false;
    if (_queue.isNotEmpty) _wait = Timer(const Duration(milliseconds: 400), _next);
  }

  @override
  void dispose() {
    _hold.release();
    _wait?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// '새 동료!' 카드 (폰 폭 85%·최대 340dp, 본문 16sp — 팝업 기준).
class NewMateDialog extends ConsumerWidget {
  const NewMateDialog({required this.crewId, this.rarityId, super.key});

  final String crewId;

  /// 받은 카드 등급 (이벤트 값 — 상태가 아직 안 왔어도 맞게).
  final String? rarityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final def = t.crews.crews.firstWhere((c) => c.id == crewId);
    final s = ref.read(gameStateProvider);
    final level = s.crews[crewId]?.level ?? 1;
    final rarity = rarityId == null ? rarityOfLevel(t.rarities, level) : t.rarities.byId(rarityId!);
    final role = crewRoleOf(t, crewId);
    final id = crewIdentity(t, crewId);
    final how = [
      tableText(l10n, t.skills.byId(def.family).nameKey),
      if (id != null) aimText(l10n, id.aim),
      if (id != null) id.area ? l10n.uiAreaWide : l10n.uiAreaSingle,
    ].join(' · ');
    final dex = collectionBonus(s, t);
    final nextReward = nextCollectReward(s, t);
    final empty = ref.read(fleetSlotsProvider).indexOf(null);
    final name = shortCrewName(l10n, def);
    // k2: 노란 리본 '새 동료!' + X + 연보라 판 (공용 PixelDialog).
    return PixelDialog(
      key: const Key('newMate'),
      title: l10n.uiNewCrew,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // k2: 등급색 네모 칸.
                IconCell(
                  color: rarityColor(rarity),
                  size: 72,
                  child: CrewPortrait(crew: def, size: 56),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Skin.bold(20)),
                      // 등급: 등급색 외곽선 글자 크게(연한 노랑 '전설'이 안 읽히던 것 — S5 스토어 샷 ①).
                      Text(tableText(l10n, rarity.nameKey), style: Skin.outlined(17, color: rarityColor(rarity))),
                      const SizedBox(height: 4),
                      Container(
                        key: Key('newMate.role.${role.name}'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Skin.ink, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(roleIcon(role), size: 14, color: const Color(0xFFFFD84A)),
                            const SizedBox(width: 4),
                            OutlineText(roleText(l10n, role), size: 13),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.uiNewMateHow(how), key: const Key('newMate.how'), style: Skin.text(16)),
            const SizedBox(height: 6),
            CrewIdentityPanel(crewId: crewId, rarity: t.rarities.rarities.indexOf(rarity)),
            const SizedBox(height: 8),
            Text(
              // '다음 보상까지 n명' = 도감 수집 보상(S2 collectionRewards)의 다음 칸.
              nextReward == null
                  ? l10n.uiNewMateDexAll(dex.owned, dex.total)
                  : l10n.uiNewMateDex(dex.owned, dex.total, nextReward.at - s.collection.length),
              key: const Key('newMate.dex'),
              style: Skin.text(14, color: Skin.sub),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SkinButton(
                    key: const Key('newMate.later'),
                    tone: SkinTone.plain,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.uiNewMateLater),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SkinButton(
                    key: const Key('newMate.deploy'),
                    tone: SkinTone.gold,
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (empty >= 0) {
                        ref.read(commandSinkProvider).send(SetFleetSlot(empty, crewId));
                        showSkinToast(context, l10n.uiNewMateDeployed(name));
                      } else {
                        // 칸이 가득이면 상세 창의 '출전 → 바꿀 선원'으로.
                        unawaited(showCrewDetail(context, def));
                      }
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(empty >= 0 ? l10n.uiNewMateDeploy : l10n.uiNewMateDetail),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
