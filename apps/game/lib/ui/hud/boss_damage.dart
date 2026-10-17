import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';

/// 보스 보상 연출(S3 TopBossLoot.totalMs 2.6초)이 끝난 뒤 창을 띄운다 — 겹치지 않게.
const bossDamageDelay = Duration(milliseconds: 2600);

/// 창이 저절로 닫히는 시간(탭하면 바로 닫힌다).
const bossDamageHold = Duration(seconds: 5);

/// 보스 처치 → 선원별 보스 피해 창(사용자 피드백 #14, BossCleared.crewDamage·mvp). 빠른 항해·현상금 중에는 띄우지 않는다
/// (보스가 연달아 나오거나 현상금 결과 창이 따로 있다). 선원 피해가 없으면(옛 기록) 띄우지 않는다.
class BossDamageGate extends ConsumerStatefulWidget {
  const BossDamageGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BossDamageGate> createState() => _BossDamageGateState();
}

class _BossDamageGateState extends ConsumerState<BossDamageGate> {
  StreamSubscription<RecordedTick>? _sub;
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is! BossCleared || e.crewDamage.isEmpty) continue;
        final b = tick.frame;
        if (b.fastSail != null || b.bounty != null) continue;
        _wait?.cancel();
        _wait = Timer(bossDamageDelay, () => _show(e));
      }
    });
  }

  void _show(BossCleared e) {
    if (!mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        barrierColor: const Color(0x66000000),
        builder: (_) => BossDamageDialog(damage: e.crewDamage, mvp: e.mvp),
      ),
    );
  }

  @override
  void dispose() {
    _wait?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 선원별 보스 피해 창: MVP(왕관·큰 초상·피해·%) + 선원마다 초상·이름·막대·피해·%. 탭하면 닫히고, [hold] 뒤 저절로 닫힌다.
class BossDamageDialog extends ConsumerStatefulWidget {
  const BossDamageDialog({required this.damage, required this.mvp, this.hold = bossDamageHold, super.key});

  final Map<String, BigNum> damage;
  final String? mvp;
  final Duration? hold;

  @override
  ConsumerState<BossDamageDialog> createState() => _BossDamageDialogState();
}

class _BossDamageDialogState extends ConsumerState<BossDamageDialog> {
  Timer? _close;

  @override
  void initState() {
    super.initState();
    if (widget.hold case final d?) _close = Timer(d, _pop);
  }

  void _pop() {
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final crews = ref.watch(tablesProvider).crews;
    final rows = widget.damage.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = rows.fold(BigNum.zero, (sum, e) => sum + e.value);
    double share(BigNum v) => total.isZero ? 0 : (v / total).toDouble();
    String pct(BigNum v) => '${(share(v) * 100).round()}%';
    final mvp = widget.mvp == null ? null : crews.byId(widget.mvp!);
    return GestureDetector(
      key: const Key('bossDamage'),
      behavior: HitTestBehavior.opaque,
      onTap: _pop,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF243565), Skin.night],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Skin.goldBottom, width: 3),
              boxShadow: Skin.shadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.uiBossDamageTitle,
                  textAlign: TextAlign.center,
                  style: Skin.text(20, color: Skin.goldTop),
                ),
                if (mvp != null) ...[
                  const SizedBox(height: 28), // 왕관이 초상 위로 22 튀어나온다 — 제목과 안 겹치게
                  Row(
                    key: const Key('bossDamage.mvp'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Skin.goldBottom, width: 3),
                            ),
                            child: CrewPortrait(crew: mvp, size: 72),
                          ),
                          const Positioned(
                            top: -22,
                            child: Icon(Icons.workspace_premium_rounded, size: 34, color: Skin.goldTop),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.uiBossDamageMvp, style: Skin.text(16, color: Skin.goldTop)),
                            Text(shortCrewName(l10n, mvp), style: Skin.text(20, color: Colors.white)),
                            Text(
                              l10n.uiBossDamageLine(widget.damage[mvp.id]!.format(), pct(widget.damage[mvp.id]!)),
                              style: Skin.text(16, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                for (final MapEntry(key: id, value: v) in rows)
                  Padding(
                    key: Key('bossDamage.row.$id'),
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        CrewPortrait(crew: crews.byId(id), size: 36),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      shortCrewName(l10n, crews.byId(id)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Skin.text(15, color: Colors.white),
                                    ),
                                  ),
                                  Text(
                                    l10n.uiBossDamageLine(v.format(), pct(v)),
                                    style: Skin.text(15, color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: share(v),
                                  minHeight: 8,
                                  backgroundColor: Colors.white24,
                                  color: id == widget.mvp ? Skin.goldTop : Skin.mint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  l10n.uiBossDamageTap,
                  textAlign: TextAlign.center,
                  style: Skin.text(14, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
