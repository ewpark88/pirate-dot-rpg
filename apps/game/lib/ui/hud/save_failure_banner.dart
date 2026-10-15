import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/adapters/file_save_store.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/state/platform_providers.dart';

/// HUD 위 얇은 도트 띠 — 저장이 실패한 동안만 (요청서 platform-save-failure). 다음 저장이 성공하면 사라진다.
/// 재촉하지 않고 짧게 (설계서 4.9). 누르는 것 없음.
class SaveFailureBanner extends ConsumerWidget {
  const SaveFailureBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ValueListenableBuilder<SaveFailure?>(
    valueListenable: ref.watch(saveFailureProvider),
    builder: (context, failure, _) {
      if (failure == null) return const SizedBox.shrink();
      final l10n = AppLocalizations.of(context);
      final u = pixelUnit(context);
      return DecoratedBox(
        key: const Key('hud.saveFailure'),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE3E7),
          border: Border(
            bottom: BorderSide(color: PixelPalette.danger, width: u),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: u * 2),
          child: Text(
            switch (failure) {
              SaveFailure.diskFull => l10n.uiSaveFailedDiskFull,
              SaveFailure.io => l10n.uiSaveFailedIo,
            },
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: PixelPalette.text),
          ),
        ),
      );
    },
  );
}
