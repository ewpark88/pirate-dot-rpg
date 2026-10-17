import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/guide/once_tip.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 항해 탭 카드 '심연의 탑' (S5 계약 platform-tower.md, 기획 platform-content-v2 4절): 최고 층 · 도전권 n/3 ·
/// [도전] [소탕 n층] · 도전권 0이면 [광고로 1장]. 열리기 전(환생 1 또는 스테이지 60)엔 없다.
class TowerCard extends ConsumerWidget {
  const TowerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tablesProvider);
    final w = ref.watch(gameStateProvider.select((s) => s.tower));
    final can = ref.watch(gameStateProvider.select((s) => canStartTower(s, t)));
    if (w == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final sink = ref.read(commandSinkProvider);
    final cap = t.meta.raw.obj('tower').integer('maxTickets');
    return Container(
      key: const Key('tower.card'),
      padding: const EdgeInsets.all(10),
      decoration: Skin.inset(radius: Skin.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 처음 열렸을 때 한 번 옥토 한 마디(S1 2026-10-18).
          OnceTip(id: 'tip.tower', text: l10n.uiTipTower),
          Row(
            children: [
              // 심연 보라 칸 + 최고 층 큰 숫자.
              IconCell(
                color: const Color(0xFF4B3A8C),
                child: OutlineText(l10n.uiTowerFloor(w.best), size: 18, fit: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.uiTowerTitle, style: Skin.bold(18)),
                    Text(
                      w.best > 0 ? l10n.uiTowerBest(w.best) : l10n.uiTowerNone,
                      maxLines: 2,
                      style: Skin.text(13, color: Skin.sub),
                    ),
                  ],
                ),
              ),
              SceneTicketPill(key: const Key('tower.tickets'), tickets: w.tickets, cap: cap),
            ],
          ),
          const SizedBox(height: 8),
          if (w.tickets == 0)
            const SceneNoTicketRow(placement: AdPlacement.towerTicket, adKey: Key('tower.ad'))
          else
            Row(
              children: [
                Expanded(
                  child: SkinButton(
                    key: const Key('tower.start'),
                    onPressed: can ? () => sink.send(const StartTower()) : null,
                    child: Text(l10n.uiSceneChallenge),
                  ),
                ),
                if (w.best > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SkinButton(
                      key: const Key('tower.sweep'),
                      tone: SkinTone.gold,
                      onPressed: w.active == null ? () => sink.send(const SweepTower()) : null,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l10n.uiTowerSweep(towerSweepFloor(w, t))),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// 도전권 알약 'n/cap' (가득이면 빨강 — 쌓인 것을 쓰라는 신호).
class SceneTicketPill extends StatelessWidget {
  const SceneTicketPill({required this.tickets, required this.cap, super.key});

  final int tickets;
  final int cap;

  @override
  Widget build(BuildContext context) {
    final full = tickets >= cap;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: full ? const Color(0xFFFFE3E7) : Skin.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: full ? Skin.danger : Skin.outline, width: 2),
      ),
      child: Text(
        AppLocalizations.of(context).uiSceneTickets(tickets, cap),
        style: Skin.text(13, color: full ? const Color(0xFFB0102A) : Skin.goldInk),
      ),
    );
  }
}

/// 도전권 0: 안내 한 줄 + [광고로 1장](경제가 하루 1번을 지킨다 — 줄 수 없으면 버튼이 안 보인다).
class SceneNoTicketRow extends StatelessWidget {
  const SceneNoTicketRow({required this.placement, required this.adKey, super.key});

  final AdPlacement placement;
  final Key adKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(l10n.uiSceneNoTicket, style: Skin.text(13, color: Skin.sub)),
        ),
        AdButton(key: adKey, placement: placement, label: l10n.uiSceneAdTicket),
      ],
    );
  }
}
