import 'package:flutter/material.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_text.dart' show titleName;
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

/// 패스 보상 한 칸의 상태.
enum PassCellState {
  /// 받음(체크).
  claimed,

  /// 지금 받을 수 있다(금빛, 누르면 받기).
  ready,

  /// 아직 단계가 안 됨.
  ahead,

  /// 유료 줄인데 패스가 없다(자물쇠).
  locked,
}

/// 보상 아이콘·글('×2' · '40' · 칭호 이름).
(String, String) passRewardLook(AppLocalizations l, PassReward r) {
  if (r.skins.isNotEmpty) return (UiSprites.flag, l.uiPassSkinName);
  if (r.title != null) return (UiSprites.trophy, titleName(l, r.title!));
  if (r.legendSummon > 0) return (UiSprites.star, l.uiPassLegend);
  if (r.heroCards > 0) return (UiSprites.cardBack, l.uiShopHeroCards(r.heroCards));
  if (r.summons > 0) return (UiSprites.star, l.uiShopSummonN(r.summons));
  if (r.pieces > 0) return (UiSprites.shard, r.pieces.toString());
  return (UiSprites.gem, r.gems.toString());
}

/// 보상 한 칸 (64dp): 아이콘 + 글, 상태별 테두리·흐림·체크·자물쇠.
class PassCell extends StatelessWidget {
  const PassCell({required this.reward, required this.state, required this.paid, this.onTap, super.key});

  final PassReward reward;
  final PassCellState state;
  final bool paid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, text) = passRewardLook(l10n, reward);
    final ready = state == PassCellState.ready;
    final dim = state == PassCellState.ahead || state == PassCellState.locked;
    return GestureDetector(
      onTap: ready ? onTap : null,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: paid ? const Color(0xFFFFE9B0) : Skin.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ready ? Skin.goldBottom : Skin.outline, width: ready ? 3 : 2),
          boxShadow: ready ? [const BoxShadow(color: Color(0x88FFD84A), blurRadius: 8)] : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: dim ? 0.45 : 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkinIcon(icon, size: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: OutlineText(text, size: 11, fit: true),
                  ),
                ],
              ),
            ),
            if (state == PassCellState.claimed) const Positioned(right: 2, top: 2, child: SkinIcon(UiSprites.check)),
            if (state == PassCellState.locked) const Positioned(right: 2, top: 2, child: SkinIcon(UiSprites.lock)),
          ],
        ),
      ),
    );
  }
}
