import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/hud/battle_hud_buttons.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

// 사용자 직접 지시 2026-10-16: 환생할 수 있게 되면 알려서 '지금 환생 / 더 진행'을 고르게. 눌러 보지 않아도 방법을 알게.
// 전장 알약 '⚓ 환생 가능!'(탭 → 항해 탭) · 항해 아이콘 금빛 맥박·빨간 점 · 처음 1회 큰 말풍선 · 첫 환생 전 손가락.

/// 지금 환생할 수 있다 (해금됐고 얻는 조각이 있다).
final rebirthReadyProvider = Provider<bool>((ref) {
  final t = ref.watch(tablesProvider);
  return ref.watch(
    gameStateProvider.select((s) {
      final p = rebirthPreview(s, t);
      return !p.locked && p.gain > 0;
    }),
  );
});

/// 아직 한 번도 환생하지 않았고 지금 할 수 있으며, 환생 창을 아직 안 열었다(세이브에 남음) → 손가락으로 길 안내.
final rebirthGuideProvider = Provider<bool>((ref) {
  final ready = ref.watch(rebirthReadyProvider);
  final first = ref.watch(gameStateProvider.select((s) => s.progress.rebirths == 0));
  // 이번 실행에서 봤거나 세이브에 본 기록(Settings.hints)이 있으면 끝.
  final seen =
      ref.watch(hudHintsProvider.select((h) => (h['rebirth.seen'] ?? 0) > 0)) ||
      ref.watch(gameStateProvider.select((s) => s.settings.hints.contains('rebirth.seen')));
  return ready && first && !seen;
});

/// 환생 창을 열었다 (손가락 안내 끝).
void markRebirthSeen(WidgetRef ref) => ref.read(hudHintsProvider.notifier).shown('rebirth.seen');

/// 영구 배율 글: 보너스 0.5 → '×1.5'.
String rebirthMultText(AppLocalizations l10n, double bonus) => l10n.uiEffectMultiplier(shortDecimal(1 + bonus));

/// 전장 왼쪽 위 알약 '⚓ 환생 가능!' — 누르면 항해 탭(환생 카드)을 연다.
class RebirthReadyPill extends ConsumerWidget {
  const RebirthReadyPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(rebirthReadyProvider)) return const SizedBox.shrink();
    final label = AppLocalizations.of(context).uiRebirthReadyPill;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('rebirth.ready.pill'),
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(dockTabRequestProvider.notifier).open(voyageTab),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 160, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xE61B2A4A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Skin.goldBottom, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.anchor_rounded, size: 18, color: Skin.goldBottom),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Skin.text(14, color: Skin.goldBottom),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 처음 환생할 수 있게 됐을 때 큰 말풍선 한 번 (아직 환생한 적 없을 때, 이번 실행에서 한 번). 6초 뒤 또는 누르면 닫힘.
class RebirthReadyBubble extends ConsumerStatefulWidget {
  const RebirthReadyBubble({super.key});

  @override
  ConsumerState<RebirthReadyBubble> createState() => _RebirthReadyBubbleState();
}

class _RebirthReadyBubbleState extends ConsumerState<RebirthReadyBubble> {
  static const _show = Duration(seconds: 6);
  Timer? _hide;
  bool _on = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(rebirthGuideProvider, (_, guide) {
      final hints = ref.read(hudHintsProvider.notifier);
      if (!guide || hints.count('rebirth.bubble') > 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        hints.shown('rebirth.bubble');
        setState(() => _on = true);
        _hide = Timer(_show, _close);
      });
    }, fireImmediately: true);
  }

  void _close() {
    _hide?.cancel();
    if (mounted && _on) setState(() => _on = false);
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_on) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final p = rebirthPreview(ref.read(gameStateProvider), ref.read(tablesProvider));
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: GestureDetector(
        key: const Key('rebirth.ready.bubble'),
        onTap: () {
          _close();
          ref.read(dockTabRequestProvider.notifier).open(voyageTab);
        },
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Skin.goldBottom, width: 2.5),
            boxShadow: Skin.shadow,
          ),
          child: Row(
            children: [
              const Icon(Icons.anchor_rounded, size: 28, color: Skin.goldInk),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.uiRebirthReadyBubble(p.gain, rebirthMultText(l10n, p.bonusAfter)),
                  style: Skin.text(14, color: Skin.goldInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
