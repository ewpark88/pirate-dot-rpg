import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_ready.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 사용자 직접 지시 2026-10-16: "환생 설명이 없어 환생하면 뭐가 좋은지 모른다" → 얻는 것 / 잃는 것 / 지금 vs 더 가고.
// 수치는 모두 경제 함수(rebirthPreview · fastSailFraction)에서 — 표가 바뀌어도 맞는다.

/// 비교에 쓰는 '더 가고' 스테이지 수.
const rebirthCompareStages = 10;

/// 환생하면 좋은 것 설명 판 (환생 창 맨 위).
class RebirthWhy extends ConsumerWidget {
  const RebirthWhy({required this.preview, super.key});

  /// 지금 환생 미리보기 (환생 창이 받은 것 그대로 — 카드·창·판이 같은 수).
  final RebirthPreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = ref.watch(tablesProvider);
    final s = ref.read(gameStateProvider);
    final now = preview;
    final laterStage = s.progress.stage + rebirthCompareStages;
    final later = rebirthPreview(s.copyWith(progress: s.progress.copyWith(stage: laterStage)), t);
    final best = math.max(s.progress.bestStage, s.progress.stage);
    final fast = (best * fastSailFraction(s, t)).ceil();
    String mult(double b) => rebirthMultText(l10n, b);

    Widget head(String text, Color color) => Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(text, style: Skin.bold(15, color: color)),
    );
    Widget line(IconData icon, String text, {Key? key, Color color = Skin.ink}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              key: key,
              style: Skin.text(14, color: color),
            ),
          ),
        ],
      ),
    );
    Widget cell(String title, String value, {required bool strong, Key? key}) => Expanded(
      child: Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        // k2: 굵은 외곽선 칸(지금 환생 = 금빛).
        decoration: Skin.inset(fill: strong ? const Color(0xFFFFF4CF) : Skin.insetFill, radius: 10),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Skin.text(12, color: Skin.sub),
            ),
            Text(value, textAlign: TextAlign.center, style: Skin.text(14)),
          ],
        ),
      ),
    );

    return Container(
      key: const Key('rebirth.why'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      decoration: Skin.inset(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head(l10n.uiRebirthWhyGain, Skin.mintInk),
          line(Icons.map_rounded, l10n.uiRebirthWhyPieces(now.gain), color: Skin.mintInk),
          line(
            Icons.trending_up_rounded,
            l10n.uiRebirthWhyMult(mult(now.bonusNow), mult(now.bonusAfter)),
            key: const Key('rebirth.why.mult'),
            color: Skin.mintInk,
          ),
          line(Icons.storefront_rounded, l10n.uiRebirthWhyShop, color: Skin.mintInk),
          if (fast > 1) line(Icons.fast_forward_rounded, l10n.uiRebirthWhyFast(fast), color: Skin.mintInk),
          head(l10n.uiRebirthWhyLose, Skin.danger),
          line(Icons.restart_alt_rounded, l10n.uiRebirthWhyLoseLine, color: Skin.danger),
          head(l10n.uiRebirthWhyKeep, Skin.sub),
          line(Icons.lock_rounded, l10n.uiRebirthWhyKeepLine, color: Skin.sub),
          head(l10n.uiRebirthCompare, Skin.ink),
          Row(
            children: [
              cell(
                l10n.uiRebirthCompareNow,
                l10n.uiRebirthCompareValue(now.gain, mult(now.bonusAfter)),
                strong: true,
                key: const Key('rebirth.compare.now'),
              ),
              const SizedBox(width: 6),
              cell(
                l10n.uiRebirthCompareLater(laterStage),
                l10n.uiRebirthCompareValue(later.gain, mult(later.bonusAfter)),
                strong: false,
                key: const Key('rebirth.compare.later'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
