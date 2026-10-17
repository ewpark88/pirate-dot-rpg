import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/hud/boss_damage.dart';
import 'package:pirate_dot/ui/hud/fever_drama.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 환생 뒤 출항 버튼(빠른 항해의 시작, #19) — 홈 화면이 이 파일 하나로 둘 다 가져간다(home_screen 300줄).
export 'package:pirate_dot/ui/hud/sail_start.dart' show SailStartButton;

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

/// 빠른 항해 패널 (사용자 피드백 #20 '우상단에 예쁘게'): 화면 오른쪽 위 작은 패널 — '빠른 항해 n/m'(n은 구간 안 몇 번째 스테이지,
/// 굴러 올라가는 숫자) · 얇은 진행 막대 · '보스 연속 격파 x'(2부터) · 2회차부터 건너뛰기. 전장 가운데를 덮지 않게 폭을 줄였다.
class FastSailBanner extends ConsumerWidget {
  const FastSailBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(fastSailProvider);
    if (run == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final stage = ref.watch(gameStateProvider.select((s) => s.progress.stage));
    final canSkip = ref.watch(gameStateProvider.select((s) => s.progress.rebirths >= 2));
    final total = (run.to - run.from + 1).clamp(1, 1 << 30);
    final at = (stage - run.from + 1).clamp(1, total);
    return Align(
      alignment: Alignment.topRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 196),
        child: Container(
          key: const Key('fastSail.banner'),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          decoration: BoxDecoration(
            color: feverNavy.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: feverGold, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 빠른 항해 n/m — n이 굴러 올라간다(차르르). 좁으면 줄여 맞춘다.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(Icons.sailing_rounded, size: 18, color: feverGold),
                    const SizedBox(width: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: at.toDouble()),
                      duration: const Duration(milliseconds: 350),
                      builder: (_, v, _) => Text(
                        l10n.uiFastSailProgress(v.round(), total),
                        key: const Key('fastSail.stage'),
                        style: Skin.text(17, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: at / total,
                  minHeight: 5,
                  backgroundColor: Colors.white24,
                  color: feverGold,
                ),
              ),
              if (run.combo > 1) ...[
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: const Key('fastSail.combo'),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: feverOrange, borderRadius: BorderRadius.circular(10)),
                    child: Text(l10n.uiFastSailStreak(run.combo), style: Skin.text(13, color: Colors.white)),
                  ),
                ),
              ],
              if (canSkip) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: SkinButton(
                    key: const Key('fastSail.skip'), // 기본 높이 48 = 최소 누름(S4 검토), 글자만 작게
                    onPressed: () => ref.read(commandSinkProvider).send(const SkipFastSail()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(l10n.uiFastSailSkip, style: Skin.text(14, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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

  // 보스 처치 선원별 피해 창(#14)도 여기서 묶는다(home_screen 300줄 — 같은 '전투 결과 창' 무리).
  @override
  Widget build(BuildContext context) => BossDamageGate(child: widget.child);
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
