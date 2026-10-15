import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/dock/quick_upgrade.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

/// 안내가 저절로 사라지는 시간 — 처음(자세히)은 길게, 이후(짧게)는 짧게 (피로 원칙).
const _firstShow = Duration(seconds: 8);
const _laterShow = Duration(seconds: 4);

/// 이번 실행에서 보스 실패 안내를 자세히 본 적이 있나.
// TODO(ui): 세이브 필드(보스 실패 횟수)가 생기면 그것으로 — 지금은 앱을 다시 켜면 한 번 더 자세히 나온다.
final bossFailSeenProvider = NotifierProvider<_Seen, bool>(_Seen.new);

class _Seen extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() => state = true;
}

/// 보스 실패 직후 짧은 안내 (사용자 질문 "지는 판단이 뭐냐" → 규칙을 보인다).
/// 처음: '보스를 놓쳤어요' + 규칙 한 줄 + [추천 부품 바로 강화] [보스 도전]. 이후: 한 줄 + [보스 도전].
/// 보스에 다시 도전하거나(파밍 끝) 시간이 지나면 사라진다. 전장 위쪽에 얹고 빈 곳은 눌림을 통과시킨다.
class BossFailNotice extends ConsumerStatefulWidget {
  const BossFailNotice({super.key});

  @override
  ConsumerState<BossFailNotice> createState() => _BossFailNoticeState();
}

class _BossFailNoticeState extends ConsumerState<BossFailNotice> {
  StreamSubscription<RecordedTick>? _sub;
  Timer? _hide;
  bool? _detailed;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      if (tick.events.any((e) => e is BossFailed) && mounted) _show();
    });
    // 파밍이 끝나면(보스 도전·통과) 바로 닫는다.
    ref.listenManual(gameStateProvider.select((s) => s.progress.farming), (_, farming) {
      if (!farming) _close();
    });
  }

  void _show() {
    final seen = ref.read(bossFailSeenProvider);
    ref.read(bossFailSeenProvider.notifier).mark();
    _hide?.cancel();
    _hide = Timer(seen ? _laterShow : _firstShow, _close);
    setState(() => _detailed = !seen);
  }

  void _close() {
    _hide?.cancel();
    if (mounted && _detailed != null) setState(() => _detailed = null);
  }

  @override
  void dispose() {
    _hide?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailed = _detailed;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, a) => SizeTransition(
        sizeFactor: a,
        child: FadeTransition(opacity: a, child: child),
      ),
      child: detailed == null
          ? const SizedBox(width: double.infinity)
          : _Card(key: ValueKey(detailed), detailed: detailed, onClose: _close),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.detailed, required this.onClose, super.key});

  final bool detailed;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final part = ref.watch(quickUpgradeProvider);
    final challenge = SkinButton(
      key: const Key('bossFail.challenge'),
      height: 44,
      onPressed: () {
        ref.read(commandSinkProvider).send(const ChallengeBoss());
        onClose();
      },
      child: Text(l10n.uiBossChallenge),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Container(
        key: Key(detailed ? 'bossFail.detailed' : 'bossFail.short'),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: Skin.card,
          borderRadius: BorderRadius.circular(Skin.radiusCard),
          border: Border.all(color: Skin.danger, width: 2),
          boxShadow: Skin.shadow,
        ),
        child: detailed
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const SkinIcon(UiSprites.flag, size: 22),
                      const SizedBox(width: 6),
                      Expanded(child: Text(l10n.uiBossFailTitle, style: Skin.text(18))),
                      _CloseX(onTap: onClose),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.uiBossFailRule, style: Skin.text(14, color: Skin.sub)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (part != null) ...[
                        Expanded(
                          child: SkinButton(
                            key: const Key('bossFail.upgrade'),
                            tone: SkinTone.gold,
                            height: 44,
                            onPressed: () => ref.read(commandSinkProvider).send(UpgradePart(part)),
                            child: Text(
                              l10n.uiBossFailUpgrade(tableText(l10n, tables.shipParts.byId(part).nameKey)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: challenge),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  const SkinIcon(UiSprites.flag, size: 20),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l10n.uiBossFailShort, style: Skin.text(15))),
                  challenge,
                ],
              ),
      ),
    );
  }
}

class _CloseX extends StatelessWidget {
  const _CloseX({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppLocalizations.of(context).uiClose,
    excludeSemantics: true,
    child: GestureDetector(
      key: const Key('bossFail.close'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const SizedBox.square(
        dimension: 40,
        child: Center(child: Icon(Icons.close_rounded, size: 22, color: Skin.sub)),
      ),
    ),
  );
}

/// 파밍 중 표시 (전장 위쪽 작은 띠): '파밍 중 · 보스 재도전 가능'. 보스가 나와 있으면 숨긴다.
// TODO(ui): 진행 게이지(웨이브·보스 해골)가 생기면 그 안으로 옮긴다.
class FarmingPill extends ConsumerWidget {
  const FarmingPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(gameStateProvider.select((s) => s.progress.farming && !(s.battle?.bossActive ?? false)));
    if (!show) return const SizedBox.shrink();
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Container(
          key: const Key('hud.farming'),
          padding: const EdgeInsets.fromLTRB(6, 3, 12, 3),
          decoration: BoxDecoration(
            color: Skin.ink.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SkinIcon(UiSprites.farm),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  AppLocalizations.of(context).uiFarmingRetry,
                  maxLines: 1,
                  softWrap: false,
                  style: Skin.text(13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
