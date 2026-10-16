import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';

/// 소환 결과 아래 버튼: 다 열기 전엔 '모두 열기', 다 열면 '다시 소환' · '확인'.
class SummonResultButtons extends StatelessWidget {
  const SummonResultButtons({
    required this.allRevealed,
    required this.canAgain,
    required this.onRevealAll,
    required this.onAgain,
    required this.onClose,
    super.key,
  });

  final bool allRevealed;
  final bool canAgain;
  final VoidCallback onRevealAll;
  final VoidCallback onAgain;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!allRevealed) {
      return SkinButton(
        key: const Key('summon.revealAll'),
        height: 56,
        onPressed: onRevealAll,
        child: Text(l10n.uiSummonRevealAll),
      );
    }
    return Row(
      children: [
        Expanded(
          child: SkinButton(
            key: const Key('summon.again'),
            tone: SkinTone.gold,
            height: 56,
            onPressed: canAgain ? onAgain : null,
            child: Text(l10n.uiSummonAgain),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SkinButton(
            key: const Key('summon.result.ok'),
            height: 56,
            onPressed: onClose,
            child: Text(l10n.uiSummonResultOk),
          ),
        ),
      ],
    );
  }
}
