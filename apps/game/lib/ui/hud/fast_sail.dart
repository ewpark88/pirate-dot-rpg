import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/hud/fever_drama.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 빠른 항해 돌파 UI (기획 platform-fast-sail-breakthrough 'UI (S4)', 사용자 결정 2026-10-16):
// 큰 스테이지 카운터(차르르) + 연속 격파 수 · 2회차부터 건너뛰기 · 끝 요약 창(돌파 스테이지·골드·젬·'더 강해진 당신').

/// 구간 중이면 (from, to, combo), 아니면 null.
final fastSailProvider = Provider<({int from, int to, int combo})?>((ref) {
  return ref.watch(
    gameStateProvider.select((s) {
      final f = s.battle?.fastSail;
      return f == null ? null : (from: f.from, to: f.to, combo: f.combo);
    }),
  );
});

/// 마지막 보급 (빠른 항해 끝 바로 다음 ShipResupplied — 요약 창이 이것을 보고 '배가 강해졌다!'를 더한다).
final resupplyProvider = NotifierProvider<ResupplyNotifier, ShipResupplied?>(ResupplyNotifier.new);

class ResupplyNotifier extends Notifier<ShipResupplied?> {
  @override
  ShipResupplied? build() => null;

  // 이벤트를 받아 둔다(동작 이름).
  // ignore: use_setters_to_change_properties
  void set(ShipResupplied? e) => state = e;
}

/// 위쪽 알약 줄 자리를 대신하는 돌파 띠: 제목 · 큰 스테이지 숫자(올라가는 애니메이션) · 구간 진행 막대 · ×연속 격파 · 건너뛰기.
class FastSailBanner extends ConsumerWidget {
  const FastSailBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(fastSailProvider);
    if (run == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final stage = ref.watch(gameStateProvider.select((s) => s.progress.stage));
    final canSkip = ref.watch(gameStateProvider.select((s) => s.progress.rebirths >= 2));
    final span = (run.to - run.from).clamp(1, 1 << 30);
    final done = ((stage - run.from) / span).clamp(0.0, 1.0);
    return Container(
      key: const Key('fastSail.banner'),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
      decoration: BoxDecoration(
        color: feverNavy.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: feverGold, width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 제목 + ×연속 격파 (한 줄).
                Row(
                  children: [
                    const Icon(Icons.anchor_rounded, size: 15, color: feverGold),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        l10n.uiFastSailTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Skin.text(13, color: feverGold),
                      ),
                    ),
                    if (run.combo > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        key: const Key('fastSail.combo'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: feverOrange, borderRadius: BorderRadius.circular(10)),
                        child: Text(l10n.uiFastSailCombo(run.combo), style: Skin.text(12, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                // 차르르: 숫자가 이전 값에서 지금 값까지 굴러 올라간다. 좁으면 줄여 맞춘다.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: stage.toDouble()),
                        duration: const Duration(milliseconds: 350),
                        builder: (_, v, _) => Text(
                          l10n.uiFastSailStage(v.round()),
                          key: const Key('fastSail.stage'),
                          style: Skin.text(26, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(l10n.uiFastSailRange(run.from, run.to), style: Skin.text(12, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: done,
                    minHeight: 5,
                    backgroundColor: Colors.white24,
                    color: feverGold,
                  ),
                ),
              ],
            ),
          ),
          if (canSkip) ...[
            const SizedBox(width: 6),
            SkinButton(
              key: const Key('fastSail.skip'),
              height: 44,
              onPressed: () => ref.read(commandSinkProvider).send(const SkipFastSail()),
              child: Text(l10n.uiFastSailSkip),
            ),
          ],
        ],
      ),
    );
  }
}

/// 구간 끝(FastSailEnded) → 요약 창 한 번(넘친 골드 = e.lost). 바로 뒤 보급(ShipResupplied)은 창에 더한다.
class FastSailEndGate extends ConsumerStatefulWidget {
  const FastSailEndGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FastSailEndGate> createState() => _FastSailEndGateState();
}

class _FastSailEndGateState extends ConsumerState<FastSailEndGate> {
  StreamSubscription<RecordedTick>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is FastSailEnded) {
          ref.read(resupplyProvider.notifier).set(null);
          _show(e);
        }
        if (e is ShipResupplied) ref.read(resupplyProvider.notifier).set(e);
      }
    });
  }

  void _show(FastSailEnded e) {
    if (!mounted) return;
    // 넘친 골드는 경제가 요약에 실어 준다(FastSailEnded.lost, S5·S2).
    final lost = e.lost;
    ref.read(audioPortProvider)?.playSfx('fanfare');
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => FastSailEndDialog(ended: e, lost: lost),
      ),
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

/// 끝 요약: '스테이지 from → to 돌파!' · 보스 n마리 · 골드 +·젬 + · (넘쳤으면) 못 실은 골드 + 화물칸 강화 · '더 강해진 당신'.
class FastSailEndDialog extends ConsumerWidget {
  const FastSailEndDialog({required this.ended, required this.lost, super.key});

  final FastSailEnded ended;
  final BigNum lost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget line(IconData icon, String text, {Color color = Skin.ink, Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: key,
              style: Skin.text(16, color: color),
            ),
          ),
        ],
      ),
    );
    return PixelDialog(
      key: const Key('fastSail.end'),
      title: l10n.uiFastSailEndTitle(ended.from, ended.to),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(Icons.military_tech_rounded, l10n.uiFastSailEndStages(ended.stages)),
          line(Icons.monetization_on_rounded, l10n.uiFastSailEndGold(ended.gold.format()), color: Skin.goldInk),
          if (ended.gems > 0) line(Icons.diamond_rounded, l10n.uiFastSailEndGems(ended.gems), color: Skin.primaryEdge),
          if (!lost.isZero) ...[
            line(
              Icons.inventory_2_rounded,
              l10n.uiFastSailEndLost(lost.format()),
              color: Skin.danger,
              key: const Key('fastSail.lost'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SkinButton(
                key: const Key('fastSail.cargo'),
                tone: SkinTone.gold,
                height: 44,
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(dockTabRequestProvider.notifier).open(shipTabIndex);
                },
                child: Text(l10n.uiCargoUpgrade),
              ),
            ),
          ],
          // 보급: 부위마다 Lv 전 → 후 (오른 부위만).
          if (ref.watch(resupplyProvider) case final r?)
            if (r.after.entries.any((p) => p.value > (r.before[p.key] ?? 0))) ...[
              const SizedBox(height: 8),
              Text(
                l10n.uiResupplyTitle,
                key: const Key('fastSail.resupply'),
                style: Skin.text(16, color: Skin.primaryEdge),
              ),
              for (final p in r.after.entries)
                if (p.value > (r.before[p.key] ?? 0))
                  line(
                    Icons.upgrade_rounded,
                    l10n.uiResupplyPart(
                      // 생성 함수 인자는 이름 abc순: (from, part, to).
                      r.before[p.key] ?? 0,
                      tableText(l10n, ref.read(tablesProvider).shipParts.byId(p.key).nameKey),
                      p.value,
                    ),
                    color: Skin.primaryEdge,
                  ),
            ],
          const SizedBox(height: 8),
          Text(l10n.uiFastSailEndCheer, style: Skin.text(16, color: Skin.mintInk)),
        ],
      ),
      actions: [
        SkinButton(
          key: const Key('fastSail.ok'),
          height: 44,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.uiFastSailEndOk),
        ),
      ],
    );
  }
}
