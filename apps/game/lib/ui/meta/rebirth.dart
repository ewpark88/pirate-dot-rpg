import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bar.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

/// 상태 → 환생 미리보기 (경제 `rebirthPreview`, 사용자 결정 ①: 이번 회차 스테이지 기준). null이면 카드를 숨긴다(테스트용).
final rebirthPreviewProvider = Provider<RebirthPreview? Function(GameState state)>((ref) {
  final tables = ref.watch(tablesProvider);
  return (s) => rebirthPreview(s, tables);
});

/// 항해 탭의 환생 카드: 조각·보너스, 가능하면 이번 획득 조각과 보물지도 버튼, 아니면 해금 안내.
class RebirthCard extends ConsumerWidget {
  const RebirthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewOf = ref.watch(rebirthPreviewProvider);
    // RebirthPreview에는 ==가 없어서 화면에 쓰는 값만 레코드로 골라 구독한다.
    final view = ref.watch(
      gameStateProvider.select((s) {
        final p = previewOf(s);
        return p == null ? null : (p, s.progress.stage, p.locked, p.currentPieces, p.gain, p.nextPieceInStages);
      }),
    );
    if (view == null) return const SizedBox.shrink();
    final (preview, stage, _, _, _, _) = view;
    final l10n = AppLocalizations.of(context);
    final bonus = percentText(l10n, preview.bonusNow);

    return PixelFrame(
      key: const Key('rebirth.card'),
      padding: 6,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map_outlined),
                const SizedBox(width: 6),
                Text(l10n.uiRebirthTitle, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.uiRebirthPieces(preview.currentPieces, bonus)),
            const SizedBox(height: 8),
            if (!preview.locked) ...[
              Text(l10n.uiRebirthGain(preview.gain), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l10n.uiRebirthNext(preview.nextPieceInStages)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: PixelButton(
                  key: const Key('rebirth.open'),
                  primary: true,
                  child: Text(l10n.uiRebirthButton),
                  onPressed: () => unawaited(
                    showDialog<void>(
                      context: context,
                      builder: (_) => RebirthDialog(preview: preview),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Text(l10n.uiRebirthLocked(preview.minStage)),
              const SizedBox(height: 4),
              PixelBar(value: (stage / preview.minStage).clamp(0.0, 1.0), fill: PixelPalette.gold),
            ],
          ],
        ),
      ),
    );
  }
}

/// 환생 확인 창: 잃는 것 / 그대로인 것 / 얻는 것. 되돌릴 수 없으니 한 번 더 누른다.
class RebirthDialog extends ConsumerWidget {
  const RebirthDialog({required this.preview, super.key});

  final RebirthPreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final from = percentText(l10n, preview.bonusNow);
    final to = percentText(l10n, preview.bonusAfter);
    return AlertDialog(
      title: Text(l10n.uiRebirthTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(icon: Icons.restart_alt, color: Colors.red, text: l10n.uiRebirthLose),
          _Line(icon: Icons.lock_outline, color: Colors.blueGrey, text: l10n.uiRebirthKeep),
          _Line(
            icon: Icons.add_circle_outline,
            color: Colors.green,
            text: l10n.uiRebirthGainLine(preview.gain, '+$from', '+$to'),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('rebirth.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.uiCancel),
        ),
        PixelButton(
          key: const Key('rebirth.confirm'),
          primary: true,
          onPressed: () {
            ref.read(commandSinkProvider).send(const Rebirth());
            Navigator.of(context).pop();
          },
          child: Text(l10n.uiRebirthConfirm),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

/// 환생 결과 팝업 (‘조각 +N’). 이벤트가 아니라 상태로 안다: 환생 횟수가 늘면 그 사이 늘어난 지도 조각을 보인다.
class RebirthDoneGate extends ConsumerStatefulWidget {
  const RebirthDoneGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RebirthDoneGate> createState() => _RebirthDoneGateState();
}

class _RebirthDoneGateState extends ConsumerState<RebirthDoneGate> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(gameStateProvider.select((s) => (s.progress.rebirths, s.wallet.mapPieces)), (before, after) {
      if (before == null || after.$1 <= before.$1) return;
      final gain = after.$2 - before.$2;
      final bonus = rebirthBonus(ref.read(gameStateProvider), ref.read(tablesProvider));
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => _RebirthDoneDialog(gain: gain, bonus: bonus),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RebirthDoneDialog extends StatelessWidget {
  const _RebirthDoneDialog({required this.gain, required this.bonus});

  final int gain;
  final double bonus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      key: const Key('rebirth.done'),
      icon: const Icon(Icons.map, size: 40, color: Colors.amber),
      title: Text(l10n.uiRebirthDoneTitle),
      content: Text(l10n.uiRebirthDoneGain(gain, percentText(l10n, bonus)), textAlign: TextAlign.center),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.uiOk))],
    );
  }
}
