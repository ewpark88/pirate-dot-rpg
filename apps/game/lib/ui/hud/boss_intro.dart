import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart';
import 'package:pirate_dot/ui/hud/boss_cutin_name.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';
import 'package:pirate_dot/ui/hud/boss_weakness.dart' show WeakChips;
import 'package:pirate_dot/ui/hud/fever_drama.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 보스 등장 이름표 (S1 2026-10-16): 보스가 나오면 2초 동안 게이지 아래에 초상 · 이름 · 해역 · '대보스'/'중간 보스' 띠.

/// 이름표가 떠 있는 시간 (들어옴 0.25초 · 머묾 · 빠짐 0.35초).
const bossIntroShow = Duration(seconds: 2);

class BossIntro extends ConsumerStatefulWidget {
  const BossIntro({super.key});

  @override
  ConsumerState<BossIntro> createState() => _BossIntroState();
}

class _BossIntroState extends ConsumerState<BossIntro> with SingleTickerProviderStateMixin {
  // initState에서 만든다 — 지연(late =) 생성이면 한 번도 안 뜬 채 dispose에서 처음 만들어져 오류가 난다.
  late final AnimationController _ctl;
  StreamSubscription<RecordedTick>? _sub;

  /// 지금 보이는 보스 (id, 스테이지).
  (String, int)? _boss;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: bossIntroShow);
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is BossSpawned) _show(e);
      }
    });
  }

  void _show(BossSpawned e) {
    if (!mounted) return;
    final t = ref.read(tablesProvider);
    final stage = ref.read(gameStateProvider).progress.stage;
    // 이벤트의 kind가 보스 id면 그것, 아니면 스테이지의 보스.
    final id = t.regions.bosses.containsKey(e.kind) ? e.kind : t.regions.bossAt(stage).id;
    setState(() => _boss = (id, stage));
    _ctl.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _boss = null);
    }).ignore();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boss = _boss;
    if (boss == null) return const SizedBox.shrink();
    final (id, stage) = boss;
    final l10n = AppLocalizations.of(context);
    final t = ref.read(tablesProvider);
    final region = t.regions.regionAt(stage);
    final tag = id == region.regionBoss ? l10n.uiBossTagRegion : (id == region.midBoss ? l10n.uiBossTagMid : null);
    final big = tag != null;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, child) {
        // 해역 보스 첫 등장 컷인(렌더)이 켜진 동안은 이름표 대신 컷인 위 이름만(BossCutInName, S3 합의).
        if (bossCutInActive(ref)) return const SizedBox.shrink();
        final v = _ctl.value;
        // 0~0.12 왼쪽에서 들어옴, 0.82~1 사라짐.
        final inT = Curves.easeOutBack.transform((v / 0.12).clamp(0, 1).toDouble());
        final out = ((v - 0.82) / 0.18).clamp(0.0, 1.0);
        return Opacity(
          opacity: (1 - out) * (v / 0.06).clamp(0, 1).toDouble(),
          child: Transform.translate(offset: Offset(-40 * (1 - inT), 0), child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: Container(
          key: const Key('boss.intro'),
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: big
                  ? const [Color(0xF26E0F1E), Color(0xE6B3122E)]
                  : [feverNavy.withValues(alpha: 0.92), const Color(0xE62C3E73)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: big ? feverGold : Colors.white70, width: 2),
            boxShadow: Skin.shadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BossPortrait(bossId: id, size: 44),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tag != null) ...[
                          Container(
                            key: const Key('boss.intro.tag'),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: feverGold, borderRadius: BorderRadius.circular(8)),
                            child: Text(tag, style: Skin.text(11, color: feverNavy)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            tableText(l10n, region.nameKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Skin.text(12, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      bossName(l10n, ref, id),
                      key: const Key('boss.intro.name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Skin.text(big ? 22 : 19, color: Colors.white),
                    ),
                    // 보스 특성 아이콘 + 한 줄 (#25).
                    if (t.regions.bosses[id] case final def?) BossTraitLine(boss: def, tables: t),
                    // 약점 계열 칩도 이름표 안에(사용자 피드백 #9 C — 보스전 내내 덮던 약점 띠를 줄임).
                    if (t.regions.bosses[id] case final def? when bossCounters(def).isNotEmpty)
                      Padding(
                        key: const Key('boss.intro.weak'),
                        padding: const EdgeInsets.only(top: 2),
                        child: WeakChips(
                          boss: def,
                          labelStyle: Skin.text(13, color: Colors.white70),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
