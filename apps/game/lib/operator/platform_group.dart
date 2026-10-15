import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/state/platform_providers.dart';

/// 운영자 패널 — 플랫폼: 광고·알림을 실기기에서 바로 시험 (요청서 platform-operator-test).
/// 광고를 봐도 보상 명령(GrantAdReward)은 보내지 않는다 — 하루 한도·세이브를 건드리지 않게.
class PlatformTestGroup extends ConsumerWidget {
  const PlatformTestGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ads = ref.watch(adsPortProvider);
    final notifier = ref.watch(notifierProvider);

    Widget readyText({required bool ready}) =>
        Text(ready ? l10n.opAdReady : l10n.opAdNotReady, key: const Key('op.adReady'));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // AdMob은 뒤늦게 로드된다 → 준비 상태를 듣는다.
        if (ads is AdMobAds)
          ValueListenableBuilder<bool>(
            valueListenable: ads.ready,
            builder: (_, ready, _) => readyText(ready: ready),
          )
        else
          readyText(ready: ads.isReady(AdPlacement.chest)),
        OutlinedButton(
          key: const Key('op.adShow'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final result = await ads.show(AdPlacement.chest);
            messenger?.showSnackBar(SnackBar(content: Text(l10n.opAdResult(result.name))));
          },
          child: Text(l10n.opAdShow),
        ),
        // 운영자는 privacyOptionsRequired와 무관하게 항상 연다.
        if (ads is AdMobAds)
          OutlinedButton(
            key: const Key('op.privacy'),
            onPressed: () => unawaited(ads.showPrivacyOptions()),
            child: Text(l10n.opPrivacyOptions),
          ),
        OutlinedButton(
          key: const Key('op.testRing'),
          onPressed: notifier == null ? null : () => unawaited(notifier.testRing()),
          child: Text(l10n.opTestRing),
        ),
      ],
    );
  }
}
