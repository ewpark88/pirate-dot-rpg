import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_text.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 배 스킨 칸 (S1 2026-10-17, docs/specs/economy-ship-skins.md — 꾸밈만): 기본 · 환생 스킨 4종(meta.rebirth.skins) ·
// 새 스킨 7종(meta.shipSkins — 도감·최고 스테이지·현상금·조각)을 한 목록으로. 잠긴 칸은 얻는 방법 한 줄 + 진행.

/// 스킨 칸 하나. id null = 기본 배. price는 조각으로 살 수 있는 스킨만(조각 수).
typedef SkinEntry = ({String? id, String name, bool owned, String how, int now, int need, int? price});

/// 지금 상태의 스킨 칸 목록 (기본 → 환생 → 새 스킨 순).
List<SkinEntry> skinEntries(AppLocalizations l, GameState s, GameTables t) {
  final owned = s.ship.skinsOwned;
  return [
    (id: null, name: l.uiShipSkinDefault, owned: true, how: '', now: 0, need: 0, price: null),
    for (final d in skinDefs)
      (
        id: d.id,
        name: skinName(l, d.id),
        owned: owned.contains(d.id),
        how: l.uiSkinLocked(d.rebirths),
        now: s.progress.rebirths,
        need: d.rebirths,
        price: null,
      ),
    for (final v in shipSkinsView(s, t))
      (
        id: v.id,
        name: tableText(l, v.nameKey),
        owned: v.owned,
        how: switch (v.type) {
          'collection' => l.uiSkinHowCollection(v.value),
          'bestStage' => l.uiSkinHowStage(v.value),
          'bountyTier' => l.uiSkinHowBounty(v.value),
          'bountyAll' => l.uiSkinHowBountyAll(v.value),
          _ => l.uiSkinHowPieces(v.value),
        },
        now: v.now,
        need: v.value,
        price: v.type == 'pieces' ? v.value : null,
      ),
  ];
}

/// 새 스킨을 얻으면 토스트 '새 배 스킨: …!' + [입어 보기]. 환생 스킨은 환생 보물상자 창이 보여 주니 뺀다.
class SkinUnlockGate extends ConsumerStatefulWidget {
  const SkinUnlockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SkinUnlockGate> createState() => _SkinUnlockGateState();
}

class _SkinUnlockGateState extends ConsumerState<SkinUnlockGate> {
  StreamSubscription<RecordedTick>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is SkinUnlocked && !skinDefs.any((d) => d.id == e.id)) _toast(e.id);
      }
    });
  }

  void _toast(String id) {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final s = ref.read(gameStateProvider);
    final entry = skinEntries(l, s, ref.read(tablesProvider)).where((x) => x.id == id).firstOrNull;
    if (entry == null) return;
    showSkinToast(
      context,
      l.uiSkinGot(entry.name),
      action: l.uiSkinTryOn,
      onAction: () => ref.read(rebirthV2Provider).selectSkin(id),
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
