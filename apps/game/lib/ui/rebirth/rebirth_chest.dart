import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/chest_paint.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_text.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/ship/ship_look.dart';
import 'package:pirate_dot/ui/skin/reward_sparkle.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/summon/summon_fx.dart';

/// 뚜껑이 열리는 시간, 보상 한 줄씩 튀어나오는 간격.
const _open = Duration(milliseconds: 700);
const _itemEach = Duration(milliseconds: 260);

/// 환생 상자 팝업 (스펙 platform-rebirth-v2 7장 ③): 상자를 누르면 뚜껑이 열리고 조각·젬·소환·스킨·칭호가 차례로 튀어나온다 → '출항!'.
/// 지급은 이미 끝났으므로(받기 버튼 없음) 언제 닫아도 잃는 것이 없다. 스킨을 얻었으면 새 배를 크게 보인다.
/// '출항!'([onSail] = StartVoyage)을 눌러야 빠른 항해가 시작된다(사용자 피드백 #19). 바깥을 눌러 닫으면 전장 위 '출항' 버튼이 남는다.
class RebirthChestDialog extends StatefulWidget {
  const RebirthChestDialog({required this.chest, required this.pieces, required this.bonus, this.onSail, super.key});

  final ChestVm chest;

  /// 이번에 얻은 지도 조각과 바뀐 보너스 글('+35%').
  final int pieces;
  final String bonus;

  /// '출항!'을 누르면(창을 닫기 전에) 부른다.
  final VoidCallback? onSail;

  @override
  State<RebirthChestDialog> createState() => _RebirthChestDialogState();
}

class _RebirthChestDialogState extends State<RebirthChestDialog> with TickerProviderStateMixin {
  late final AnimationController _lid = AnimationController(vsync: this, duration: _open);
  late final AnimationController _items = AnimationController(vsync: this);

  @override
  void dispose() {
    _lid.dispose();
    _items.dispose();
    super.dispose();
  }

  List<(Widget, String)> _rewards(AppLocalizations l10n) {
    final c = widget.chest;
    final skin = skinDefs.where((s) => s.id == c.skin).firstOrNull;
    return [
      (const SkinIcon(UiSprites.tabMap, size: 28), l10n.uiRebirthDoneGain(widget.pieces, widget.bonus)),
      (const SkinIcon(UiSprites.gem, size: 28), l10n.uiRebirthChestGems(c.gems)),
      (const SkinIcon(UiSprites.tabSummon, size: 28), l10n.uiRebirthChestSummons(c.summons)),
      if (skin != null)
        (ShipLookPreview(useSkin: true, skin: skin.id, size: 40), l10n.uiRebirthChestSkin(skinName(l10n, skin.id))),
      if (c.title != null)
        (const SkinIcon(UiSprites.star, size: 28), l10n.uiRebirthChestTitle(titleName(l10n, c.title!))),
    ];
  }

  Future<void> _openChest(int count) async {
    if (_lid.isAnimating || _lid.value > 0) return;
    _items.duration = _itemEach * count;
    await _lid.forward();
    if (mounted) await _items.forward();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rewards = _rewards(l10n);
    final skin = skinDefs.where((s) => s.id == widget.chest.skin).firstOrNull;
    // k2: 노란 리본 제목 + 연보라 판(공용 PixelDialog), 상자 무대는 남색 안쪽 판. 출항으로만 닫는다(X 없음).
    return PixelDialog(
      key: const Key('rebirth.chest'),
      title: l10n.uiRebirthChest,
      showClose: false,
      content: AnimatedBuilder(
        animation: Listenable.merge([_lid, _items]),
        builder: (context, _) {
          final lid = Curves.easeOutBack.transform(_lid.value);
          final opened = _lid.value >= 1;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상자 (누르면 열림) + 빛줄기·불꽃.
                GestureDetector(
                  key: const Key('rebirth.chest.box'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openChest(rewards.length),
                  child: Container(
                    height: 150,
                    clipBehavior: Clip.hardEdge,
                    decoration: Skin.inset(fill: Skin.navyPanel),
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        if (_lid.value > 0)
                          Opacity(
                            opacity: _lid.value.clamp(0, 1).toDouble(),
                            child: Transform.rotate(
                              angle: _items.value * math.pi * 0.25,
                              child: const CustomPaint(size: Size(240, 240), painter: RaysPainter()),
                            ),
                          ),
                        if (_lid.value > 0) Positioned.fill(child: SparkBurst(t: _lid.value, rainbow: false)),
                        CustomPaint(
                          size: const Size(120, 100),
                          painter: ChestPainter(lid: lid),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!opened && _lid.value == 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      l10n.uiRebirthChestTap,
                      textAlign: TextAlign.center,
                      style: Skin.text(15, color: Skin.sub),
                    ),
                  ),
                // 보상 줄: 차례로 튀어나온다.
                for (final (i, (icon, text)) in rewards.indexed)
                  _RewardLine(
                    key: Key('rebirth.chest.item.$i'),
                    t: opened ? ((_items.value * rewards.length) - i).clamp(0, 1).toDouble() : 0,
                    icon: icon,
                    text: text,
                  ),
                if (skin != null && _items.isCompleted) ...[
                  const SizedBox(height: 6),
                  ShipLookPreview(key: const Key('rebirth.chest.skin'), useSkin: true, skin: skin.id, size: 140),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SkinButton(
                    key: Key(opened ? 'rebirth.chest.sail' : 'rebirth.chest.open'),
                    tone: SkinTone.gold,
                    height: 54,
                    onPressed: opened
                        ? () {
                            widget.onSail?.call();
                            Navigator.of(context).pop();
                          }
                        : () => _openChest(rewards.length),
                    child: Text(opened ? l10n.uiRebirthSail : l10n.uiRebirthChestOpen),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RewardLine extends StatelessWidget {
  const _RewardLine({required this.t, required this.icon, required this.text, super.key});

  final double t;
  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    final s = Curves.easeOutBack.transform(t);
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - s)),
        child: Transform.scale(
          scale: 0.7 + 0.3 * s,
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: Skin.inset(),
            child: Row(
              children: [
                SizedBox(width: 40, child: Center(child: icon)),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RewardSparkle(
                      seed: text.length,
                      child: Text(text, style: Skin.text(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
