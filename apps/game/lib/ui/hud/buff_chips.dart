import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/hud/cargo.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/scene/scene_vm.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 광고 버프·보상 칩 (사용자 2026-10-17 '칩이 작아 잘 안 보인다' + S5 실기기 ③ 19dp): 위 막대 안에서 줄어들던 칩을
// 제 크기(44dp, 아이콘 36·외곽선 글자 15)로. 자리는 오른쪽 끝 세로 줄(S1 실기기 ① — 가로 줄은 보스 몸·체력 막대를
// 덮었다; 보스·배는 전장 가운데). 새로 생기면 통통 튀며 등장.

/// 보스전·장면 모드 중 접힌 탭의 폭 — 전장 안전 영역 오른쪽 여백(S3 보스 카메라와 같은 값).
const buffFoldWidth = 24.0;

class BuffChips extends ConsumerStatefulWidget {
  const BuffChips({super.key});

  @override
  ConsumerState<BuffChips> createState() => _BuffChipsState();
}

class _BuffChipsState extends ConsumerState<BuffChips> {
  /// 접힌 상태에서 펼쳤나(보스전이 끝나면 다시 접힌 채로 시작).
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    // 보스전·탑·러시·던전 중엔 오른쪽 끝 24dp 탭 하나로 접는다(S1 2026-10-18 — 대보스(화면 폭 40%)·보스 호 이동과 겹침).
    final quiet =
        ref.watch(sceneActiveProvider) || ref.watch(gameStateProvider.select((s) => s.battle?.bossActive ?? false));
    if (!quiet) {
      _open = false;
      return const Padding(padding: EdgeInsets.only(right: 8), child: _Column());
    }
    final now = ref.watch(clockProvider).now();
    final any =
        ref.watch(adOfferProvider(AdPlacement.tailwind)) ||
        ref.watch(adOfferProvider(AdPlacement.autoUpgrade)) ||
        ref.watch(gameStateProvider.select((s) => autoUpgradeRemaining(s, now) > Duration.zero));
    if (!any) return const SizedBox.shrink();
    final tab = Semantics(
      button: true,
      label: AppLocalizations.of(context).uiAdFold,
      child: GestureDetector(
        key: const Key('hud.buffChips.fold'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () => setState(() => _open = !_open),
        child: Container(
          width: buffFoldWidth,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Skin.navyPanel.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            border: Border.all(color: Skin.outline, width: 1.5),
          ),
          child: const SkinIcon(UiSprites.ad, size: 16),
        ),
      ),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          tab,
          if (_open) const Padding(padding: EdgeInsets.only(top: 4, right: 8), child: _Column()),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerRight,
    child: Wrap(
      key: Key('hud.buffChips'),
      direction: Axis.vertical,
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        _PopIn(child: TailwindAdButton()),
        _PopIn(child: BossSupportAdButton()),
        _PopIn(child: AutoUpgradeChip()),
      ],
    ),
  );
}

/// 처음 그려질 때 60% → 100%로 통통 (350ms, easeOutBack). 동작 줄이기면 바로.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0.6, end: 1),
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutBack,
    builder: (_, s, child) => Transform.scale(scale: s, child: child),
    // 칩은 받은 폭만큼 늘어나게 짜여 있다(위 막대 FittedBox 안에서 쓰던 것) — 내용 폭으로 묶는다.
    child: IntrinsicWidth(child: child),
  );
}
