import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/ads/admob_ads.dart';
import 'package:pirate_dot/adapters/ads/no_ads.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 보상형 광고 포트. 앱·platform 레인이 실제 어댑터로 덮는다.
final adsPortProvider = Provider<AdsPort>((_) => const NoAds());

/// 효과음·배경음 포트 (null = 무음). 전장(`BattleGame`)에 넘긴다.
final audioPortProvider = Provider<AudioPort?>((_) => null);

/// 이 장치(`AdPlacement`)의 광고 버튼을 보여도 되나 = 광고 로드됨 && 경제가 허락(하루 한도·장치 조건) && 튜토리얼 아님 (설계서 4.6).
final ProviderFamily<bool, AdPlacement> adOfferProvider = Provider.family<bool, AdPlacement>((ref, placement) {
  if (ref.watch(tutorialStepProvider) != null) return false;
  final port = ref.watch(adsPortProvider);
  // AdMob 광고는 뒤늦게 로드된다 → 준비 상태가 바뀌면 다시 계산한다.
  if (port is AdMobAds) {
    void changed() => ref.invalidateSelf();
    port.ready.addListener(changed);
    ref.onDispose(() => port.ready.removeListener(changed));
  }
  final tables = ref.watch(tablesProvider);
  final allowed = ref.watch(gameStateProvider.select((s) => canWatchAd(s, tables, placement)));
  return allowed && port.isReady(placement);
});

/// 광고를 보여 주고, 보상 콜백(rewarded)이 왔을 때만 GrantAdReward를 보낸다. 그 밖의 결과는 아무것도 하지 않는다.
Future<void> watchAd(WidgetRef ref, AdPlacement placement, {String? choice}) async {
  final sink = ref.read(commandSinkProvider);
  final result = await ref.read(adsPortProvider).show(placement);
  if (result == AdResult.rewarded) sink.send(GrantAdReward(placement, choice: choice));
}

/// ads.json의 장치 정의.
AdPlacementDef adDef(GameTables t, AdPlacement p) => t.ads.placements.firstWhere((d) => d.id == p.name);

/// 광고 버튼 — 재생 아이콘 + 이득 숫자. 제안할 수 없으면(`adOfferProvider` false) 아무것도 그리지 않는다.
class AdButton extends ConsumerWidget {
  const AdButton({required this.placement, required this.label, this.choice, super.key});

  final AdPlacement placement;
  final String label;
  final String? choice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adOfferProvider(placement))) return const SizedBox.shrink();
    return FilledButton.tonalIcon(
      key: Key('ad.${placement.name}${choice == null ? '' : '.$choice'}'),
      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
      icon: const Icon(Icons.ondemand_video, size: 16),
      label: Text(label),
      onPressed: () => watchAd(ref, placement, choice: choice),
    );
  }
}
