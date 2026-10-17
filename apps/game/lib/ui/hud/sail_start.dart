import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart' show rebirthChestOpenProvider;
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 환생 뒤 출항 대기(Progress.sailHold, 사용자 피드백 #19): 바다가 잔잔한 동안 전장 가운데에 큰 '출항!' 버튼.
/// 보통은 환생 상자 창의 '출항!'이 먼저 누르고, 창을 바깥으로 닫았거나 앱을 껐다 켰을 때 이 버튼이 남는다.
/// 가이드 v2 원칙: 버튼 56dp · 글자 18sp. 가이드 카드는 TutorialSpot 'sail.start'를 가리킨다(S4).
class SailStartButton extends ConsumerWidget {
  const SailStartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hold = ref.watch(gameStateProvider.select((s) => s.progress.sailHold));
    if (!hold || ref.watch(rebirthChestOpenProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Skin.night.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.uiSailHint,
                  key: const Key('sail.hint'),
                  textAlign: TextAlign.center,
                  style: Skin.outlined(15),
                ),
              ),
              const SizedBox(height: 10),
              TutorialSpot(
                id: 'sail.start',
                child: SizedBox(
                  width: double.infinity,
                  child: SkinButton(
                    key: const Key('sail.start'),
                    tone: SkinTone.gold,
                    height: 56,
                    onPressed: () => ref.read(commandSinkProvider).send(const StartVoyage()),
                    child: Text(l10n.uiRebirthSail, style: Skin.text(18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
