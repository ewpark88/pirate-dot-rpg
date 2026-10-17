import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 승급이 스테이지로 잠김(S2 PromoteStatus.stageLocked — 첫 전설 유예 meta.firstLegend): 승급 버튼 자리에 자물쇠 +
/// '스테이지 45에서 열림'(누를 수 없음).
class PromoteLockedButton extends ConsumerWidget {
  const PromoteLockedButton({required this.crewId, super.key});

  final String crewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(tablesProvider).meta.raw.obj('firstLegend').integer('untilStage');
    return PixelButton(
      key: Key('crew.detail.promoteLocked.$crewId'),
      onPressed: null,
      // 버튼 줄이 좁으면(출전 중 바꾸기·내리기와 함께) 글자를 줄인다.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 18),
            const SizedBox(width: 4),
            Text(AppLocalizations.of(context).uiPromoteStageLocked(stage)),
          ],
        ),
      ),
    );
  }
}
