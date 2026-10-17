import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/flags.dart';
import 'package:pirate_dot/operator/operator_gate.dart';
import 'package:pirate_dot/ui/hud/cargo.dart';
import 'package:pirate_dot/ui/hud/coin_arrival.dart';
import 'package:pirate_dot/ui/hud/power_badge.dart';
import 'package:pirate_dot/ui/hud/tailwind_badge.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_icon_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/settings/settings_screen.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/big_num_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 상단 바 (전장 밖, layout-v2-brief 1): 왼쪽 골드·젬, 순풍 칩 + 광고 그림 버튼(순풍·파밍 중 함포 지원),
/// 오른쪽 설정 그림 버튼(퀘스트는 도크 첫 칸으로 — 사용자 피드백 #9 A). 누르는 영역이 48dp라 바 높이도 48dp.
class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 골드·젬은 지갑 값 그대로 실시간 (사용자 지시: 따로 움직이는 연출 없음).
    final (gold, gems) = ref.watch(gameStateProvider.select((s) => (s.wallet.gold, s.wallet.gems)));
    final tables = ref.watch(tablesProvider);
    final cap = ref.watch(gameStateProvider.select((s) => goldCapacity(s, tables).format()));
    final money = Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      // k1: 짙은 남색 알약 + 외곽선, 흰 외곽선 숫자.
      decoration: BoxDecoration(
        color: Skin.navyPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Skin.outline, width: 2),
        boxShadow: Skin.shadowSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 코인이 날아오는 자리(렌더에 좌표를 준다).
          KeyedSubtree(key: topGoldIconKey, child: const PixelSprite(UiSprites.coin, dots: 16, scale: 1)),
          const SizedBox(width: 4),
          // 길게 누르면 전체 자릿수.
          // 골드 + 화물칸 '현재 / 최대' 막대(80% 주황 · 가득 빨강 깜빡임).
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 골드 = 현재 / 최대(화물칸 상한, 사용자 피드백 #7) — 최대는 작고 흐리게.
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  BigNumText(
                    gold,
                    key: const Key('top.gold'),
                    style: Skin.outlined(16, color: const Color(0xFFFFD84A)),
                  ),
                  Text(
                    ' / $cap',
                    key: const Key('top.goldCap'),
                    style: Skin.text(14, color: const Color(0xFFB8BAE6)), // 노인 사용자 — 최대도 읽히게(#7·#9)
                  ),
                ],
              ),
              const TutorialSpot(id: 'cargo.bar', child: GoldCapBar()),
            ],
          ),
          const SizedBox(width: 10),
          const PixelSprite(UiSprites.gem, dots: 8, frames: 3),
          const SizedBox(width: 4),
          Text(gems.toString(), key: const Key('top.gems'), style: Skin.outlined(16)),
          const SizedBox(width: 8),
          const PowerBadge(),
        ],
      ),
    );
    // 운영자 빌드에서만 골드 글자 5번 → 운영자 패널. 배포 빌드에는 제스처가 없다.
    Widget moneyTap = money;
    if (kOperator) {
      moneyTap = OperatorTapGate(child: money);
    }
    // 하늘 바탕 위에 떠 있는 알약·동그라미들 (스킨 r1) — 바 자체는 투명.
    return DecoratedBox(
      decoration: const BoxDecoration(),
      child: SizedBox(
        height: kMinTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              // 돈 알약(골드·젬·전투력)은 좁으면 글자째 줄인다 — 순풍·광고보다 넓게(3:2).
              Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: moneyTap,
                ),
              ),
              const SizedBox(width: 8),
              // 순풍·광고는 남는 폭 안에서만 (좁으면 줄여서 넣는다).
              // 순풍 남은 시간은 위 막대에 그대로(줄이지 않음). 광고·자동 강화 칩은 게이지 아래 오른쪽(BuffChips — 크게).
              const TailwindBadge(),
              const Spacer(),
              PixelIconButton(
                key: const Key('hud.settings'),
                asset: UiSprites.gear,
                semanticLabel: l10n.uiSettingsTitle,
                onPressed: () => unawaited(
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
