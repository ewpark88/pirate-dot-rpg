import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 숫자가 굴러가는 시간, '+N'이 떠 있는 시간.
const _roll = Duration(milliseconds: 600);
const _flash = Duration(milliseconds: 1200);

/// 지금 함대 전투력 (경제 `fleetPower`). 표시 글자가 바뀔 때만 다시 그린다(틱마다 작은 변화는 무시).
final fleetPowerProvider = Provider<BigNum>((ref) {
  final tables = ref.watch(tablesProvider);
  ref.watch(gameStateProvider.select((s) => fleetPower(s, tables).power.format()));
  return fleetPower(ref.read(gameStateProvider), tables).power;
});

/// 상단 바 골드·젬 옆 전투력 (S1 지시 — 전장을 가리지 않게): 숫자가 굴러 오르고, 오르면 초록 '+N'이 아래로 잠깐 뜬다(연달아 오르면 합친다).
/// 내려갈 때(편성 교체 등)는 굴러 내려가기만 한다.
class PowerBadge extends ConsumerStatefulWidget {
  const PowerBadge({super.key});

  @override
  ConsumerState<PowerBadge> createState() => _PowerBadgeState();
}

class _PowerBadgeState extends ConsumerState<PowerBadge> with TickerProviderStateMixin {
  late final AnimationController _rollCtl = AnimationController(vsync: this, duration: _roll);
  late final AnimationController _flashCtl = AnimationController(vsync: this, duration: _flash);
  late BigNum _from = ref.read(fleetPowerProvider);
  late BigNum _to = _from;
  BigNum _gain = BigNum.zero;

  @override
  void initState() {
    super.initState();
    ref.listenManual(fleetPowerProvider, (_, next) => _change(next));
  }

  BigNum get _shown => _from + (_to - _from).times(Curves.easeOutCubic.transform(_rollCtl.value));

  void _change(BigNum next) {
    if (next == _to) return;
    final now = _shown;
    // 떠 있는 '+N'이 사라지기 전에 또 오르면 합친다.
    final rising = next > _to;
    if (rising) _gain = (_flashCtl.isAnimating ? _gain : BigNum.zero) + (next - _to);
    _from = now;
    _to = next;
    unawaited(_rollCtl.forward(from: 0));
    if (rising) unawaited(_flashCtl.forward(from: 0));
  }

  @override
  void dispose() {
    _rollCtl.dispose();
    _flashCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_rollCtl, _flashCtl]),
        builder: (context, _) {
          final f = _flashCtl.value;
          final flashing = _flashCtl.isAnimating;
          // 오를 때 한 번 통 튄다.
          final pop = flashing ? 1 + 0.12 * Curves.easeOut.transform((1 - f * 4).clamp(0, 1).toDouble()) : 1.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: pop,
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label: '${l10n.uiPower} ${_to.format()}',
                  excludeSemantics: true,
                  child: AnimatedContainer(
                    key: const Key('hud.power'),
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(2, 1, 6, 1),
                    decoration: BoxDecoration(
                      color: flashing ? const Color(0xFFDDF7EA) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SkinIcon('assets/ui/part_cannon.png', size: 16),
                        const SizedBox(width: 3),
                        Text(
                          _shown.format(),
                          key: const Key('hud.power.value'),
                          style: Skin.text(15, color: flashing ? Skin.mintInk : Skin.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (flashing)
                Positioned(
                  left: 18,
                  top: 20 + 12 * f,
                  child: Opacity(
                    opacity: (1 - f).clamp(0, 1).toDouble(),
                    child: Text(
                      '+${_gain.format()}',
                      key: const Key('hud.power.gain'),
                      style: Skin.text(16, color: Skin.mint).copyWith(
                        shadows: const [Shadow(color: Color(0xCC0E3A26), blurRadius: 3, offset: Offset(0, 1))],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
