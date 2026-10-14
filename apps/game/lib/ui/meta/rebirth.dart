import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

/// 환생(보물지도) 미리보기 (설계서 4.5). 값은 경제 함수가 정한다.
// TODO(economy): S2 환생 스펙의 미리보기 타입이 오면 그것으로 바꾸고 이 타입은 지운다(이름은 S2 스펙대로).
@immutable
class RebirthPreviewView {
  const RebirthPreviewView({
    required this.unlockStage,
    required this.available,
    required this.currentPieces,
    required this.gainPieces,
    required this.nextPieceInStages,
    required this.bonusPerPiece,
  });

  /// 환생이 열리는 최고 스테이지 (meta.rebirth.minStage).
  final int unlockStage;
  final bool available;
  final int currentPieces;

  /// 지금 환생하면 받는 조각.
  final int gainPieces;

  /// 다음 조각까지 남은 스테이지.
  final int nextPieceInStages;

  /// 조각 하나당 전체 피해·골드 보너스 (0.05 = 5%, 합산).
  final double bonusPerPiece;
}

/// 상태 → 환생 미리보기. null이면 환생 카드를 숨긴다.
// TODO(economy): S2 환생 미리보기 함수가 main에 오면 본문을 그 함수로. 그 전엔 숨김.
final rebirthPreviewProvider = Provider<RebirthPreviewView? Function(GameState state)>(
  (_) =>
      (_) => null,
);

/// 항해 탭의 환생 카드: 조각·보너스, 가능하면 이번 획득 조각과 보물지도 버튼, 아니면 해금 안내.
class RebirthCard extends ConsumerWidget {
  const RebirthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewOf = ref.watch(rebirthPreviewProvider);
    final (preview, best) = ref.watch(gameStateProvider.select((s) => (previewOf(s), s.progress.bestStage)));
    if (preview == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final bonus = percentText(l10n, preview.currentPieces * preview.bonusPerPiece);

    return Card(
      key: const Key('rebirth.card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
            if (preview.available) ...[
              Text(l10n.uiRebirthGain(preview.gainPieces), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l10n.uiRebirthNext(preview.nextPieceInStages)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('rebirth.open'),
                  icon: const Icon(Icons.map),
                  label: Text(l10n.uiRebirthButton),
                  onPressed: () => unawaited(
                    showDialog<void>(
                      context: context,
                      builder: (_) => RebirthDialog(preview: preview),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Text(l10n.uiRebirthLocked(preview.unlockStage)),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: (best / preview.unlockStage).clamp(0.0, 1.0), minHeight: 6),
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

  final RebirthPreviewView preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final from = percentText(l10n, preview.currentPieces * preview.bonusPerPiece);
    final to = percentText(l10n, (preview.currentPieces + preview.gainPieces) * preview.bonusPerPiece);
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
            text: l10n.uiRebirthGainLine(preview.gainPieces, '+$from', '+$to'),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('rebirth.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.uiCancel),
        ),
        FilledButton(
          key: const Key('rebirth.confirm'),
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
