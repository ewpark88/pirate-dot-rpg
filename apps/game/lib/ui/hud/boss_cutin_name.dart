import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/render/layout.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';
import 'package:pirate_dot/ui/hud/fever_drama.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 해역 보스 첫 등장 컷인(렌더 S3) 위 이름 얹기 — S3와 합의 2026-10-16: 컷인 동안은 이름만, 띠 아래 변 + 4dp,
// 가로는 컷인과 같이 움직인다(fx_map cutIn: 들어옴 300ms 오른쪽에서 · 머묾 600ms · 빠짐 300ms 왼쪽으로).

const cutInInMs = 300.0;
const cutInHoldMs = 600.0;
const cutInOutMs = 300.0;

/// 컷인 진행 [ageMs]에서 띠(=이름)의 가로 밀림 (보이는 폭 [width] 기준, 오른쪽 +).
double cutInShift(double ageMs, double width) {
  if (ageMs < cutInInMs) return width * (1 - ageMs / cutInInMs);
  final out = ageMs - cutInInMs - cutInHoldMs;
  if (out <= 0) return 0;
  return -width * (out / cutInOutMs).clamp(0.0, 1.0);
}

/// 전장 위에 얹는 층(누름 통과). 렌더 전장(Flame)이 있고 컷인이 켜졌을 때만 그린다.
class BossCutInName extends ConsumerStatefulWidget {
  const BossCutInName({super.key});

  @override
  ConsumerState<BossCutInName> createState() => _BossCutInNameState();
}

class _BossCutInNameState extends ConsumerState<BossCutInName> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  StreamSubscription<RecordedTick>? _sub;
  Timer? _stop;

  @override
  void initState() {
    super.initState();
    // 컷인을 따라가려고 그 1.5초 동안만 매 프레임 다시 그린다(끝없는 티커 없음).
    _ticker = createTicker((_) => setState(() {}));
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      if (!tick.events.any((e) => e is BossSpawned) || !ref.read(hasBattleGameProvider)) return;
      if (!_ticker.isActive) unawaited(_ticker.start());
      _stop?.cancel();
      _stop = Timer(const Duration(milliseconds: 1500), () {
        if (_ticker.isActive) _ticker.stop();
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _stop?.cancel();
    _ticker.dispose();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(hasBattleGameProvider)) return const SizedBox.shrink();
    final cut = ref.read(battleGameProvider).cutIn;
    final kind = cut.kind;
    if (!cut.active || kind == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final f = battleFrameFor(box.biggest, MediaQuery.devicePixelRatioOf(context));
          final centerY = f.toDp(const Offset(0, kFieldBottom / 2)).dy;
          final bandH = 40 * f.dot;
          final dx = cutInShift(cut.ageMs, box.maxWidth);
          return Stack(
            children: [
              Positioned(
                left: dx,
                width: box.maxWidth,
                top: centerY + bandH / 2 + 4,
                child: Center(
                  child: Container(
                    key: const Key('boss.cutin.name'),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: feverNavy.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: feverGold, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bossName(AppLocalizations.of(context), ref, kind),
                          style: Skin.outlined(20),
                        ),
                        if (ref.read(tablesProvider).regions.bosses[kind] case final def?)
                          BossTraitLine(boss: def, tables: ref.read(tablesProvider), size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 해역 보스 컷인이 지금 켜져 있나 (이름표가 이름만 얹는 모드로 물러날지).
bool bossCutInActive(WidgetRef ref) => ref.read(hasBattleGameProvider) && ref.read(battleGameProvider).cutIn.active;
