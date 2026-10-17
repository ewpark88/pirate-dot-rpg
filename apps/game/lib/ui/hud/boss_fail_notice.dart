import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 안내가 저절로 사라지는 시간 — 처음(자세히)은 길게, 이후(짧게)는 짧게 (피로 원칙).
const _firstShow = Duration(seconds: 8);
const _laterShow = Duration(seconds: 4);

/// 보스 실패 직후 짧은 안내 (사용자 질문 "지는 판단이 뭐냐" → 규칙을 보인다).
/// 처음: '보스를 놓쳤어요' + '배를 강화하거나 선원 레벨을 올린 뒤 다시 도전' + [배 강화] [선원] 바로 가기 + [보스 도전].
/// 이후: 한 줄 + 같은 세 버튼(작게).
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
    // 처음 실패(경제 progress.bossFails — 이번 실패까지 센 누계가 1 이하)만 자세히. 환생해도 이어진다.
    final seen = ref.read(gameStateProvider).progress.bossFails > 1;
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
    // 바로 가기: 그 탭 시트를 열고 안내는 닫는다(사용자 피드백 #1 '어떻게 하면 이기는지 + 바로 가기').
    Widget go(String key, String label, int tab, SkinTone tone) => Expanded(
      child: SkinButton(
        key: Key(key),
        tone: tone,
        height: 44,
        onPressed: () {
          ref.read(dockTabRequestProvider.notifier).open(tab);
          onClose();
        },
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
      ),
    );
    final challenge = SkinButton(
      key: const Key('bossFail.challenge'),
      height: 44,
      onPressed: () {
        ref.read(commandSinkProvider).send(const ChallengeBoss());
        onClose();
      },
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.uiBossChallenge, maxLines: 1)),
    );
    final ship = go('bossFail.ship', l10n.uiBossFailShip, shipTabIndex, SkinTone.gold);
    final crew = go('bossFail.crew', l10n.uiBossFailCrew, crewTabIndex, SkinTone.gold);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        // 전폭으로 펴지 않는다(전장 가리기 금지, 사용자 지시 2026-10-16) — 왼쪽 위 판.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            key: Key(detailed ? 'bossFail.detailed' : 'bossFail.short'),
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: Skin.card,
              borderRadius: BorderRadius.circular(Skin.radiusCard),
              border: Border.all(color: Skin.danger, width: 2),
              boxShadow: Skin.shadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SkinIcon(UiSprites.flag, size: 22),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        detailed ? l10n.uiBossFailTitle : l10n.uiBossFailShort,
                        style: Skin.text(detailed ? 18 : 16),
                      ),
                    ),
                    _CloseX(onTap: onClose),
                  ],
                ),
                // 처음: 왜 졌는지 + 무엇을 하면 되는지 (큰 글씨 한 문단).
                if (detailed) ...[
                  const SizedBox(height: 4),
                  Text(l10n.uiBossFailRule, style: Skin.text(15, color: Skin.sub)),
                ],
                const SizedBox(height: 8),
                if (detailed) ...[
                  Row(children: [ship, const SizedBox(width: 8), crew]),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: challenge),
                ] else
                  Row(
                    children: [
                      ship,
                      const SizedBox(width: 6),
                      crew,
                      const SizedBox(width: 6),
                      Expanded(child: challenge),
                    ],
                  ),
              ],
            ),
          ),
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
