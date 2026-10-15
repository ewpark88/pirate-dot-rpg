import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_bitmap.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/pixel/pixel_theme.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 초상 그림 한 변의 도트 수 (도트 팩 32×32).
const _portraitDots = 32;

/// 배지 글자 최소 크기(dp).
const _badgeMinDp = 10.0;

/// 미보유 선원 실루엣 색 (도트 윤곽색).
const Color _silhouette = PixelPalette.outline;

/// 승급 버튼을 보이는 상태 = 승급 문 앞(레벨은 됐고 카드·골드·증표만 남음).
const Set<PromoteStatus> _atGate = {PromoteStatus.ok, PromoteStatus.cards, PromoteStatus.gold, PromoteStatus.tokens};

/// 선원 한 명: 이름·등급 테두리와 별·레벨·카드 수·출전 표시·승급 버튼.
class CrewCard extends ConsumerWidget {
  const CrewCard({required this.def, required this.owned, super.key});

  final CrewDef def;
  final bool owned;

  String get crewId => def.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final (level, cards, deployed, status) = ref.watch(
      gameStateProvider.select((s) {
        final crew = s.crews[def.id];
        return (
          crew?.level,
          crew?.cards,
          s.battle?.fleet.any((f) => f.crewId == def.id) ?? false,
          promoteStatus(s, tables, def.id),
        );
      }),
    );
    final rarity = level == null
        ? tables.rarities.rarities.firstWhere((r) => r.id == def.baseRarity)
        : rarityOfLevel(tables.rarities, level);
    final small = Theme.of(context).textTheme.labelSmall;
    final color = rarityColor(rarity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PortraitBox(
          def: def,
          color: color,
          owned: owned,
          rarity: rarity,
          level: level,
          cards: cards,
          // 승급은 카드 안 오른쪽 아래 작은 도트 버튼 (빈 줄을 차지하지 않게).
          promote: _atGate.contains(status) ? _PromoteButton(crewId: def.id, ready: status == PromoteStatus.ok) : null,
        ),
        // 짧은 이름 한 줄 (별명은 상세 창에서, layout-v2-brief).
        Text(
          shortCrewName(l10n, def),
          key: Key('crew.name.${def.id}'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: owned ? small : small?.copyWith(color: PixelPalette.textDim),
        ),
        if (deployed)
          Text(
            l10n.uiCrewDeployed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: small?.copyWith(color: PixelPalette.accent),
          ),
      ],
    );
  }
}

/// 등급색 두꺼운 도트 테두리 안의 정사각 초상 (등급색을 옅게 깐 바탕, 아래 별, 출전이면 위 띠).
/// 미보유는 어두운 단색 실루엣 — 테두리·별은 그대로 보여 무엇을 모을지 알 수 있다.
class _PortraitBox extends StatelessWidget {
  const _PortraitBox({
    required this.def,
    required this.color,
    required this.owned,
    required this.rarity,
    required this.level,
    required this.cards,
    this.promote,
  });

  final CrewDef def;
  final Color color;
  final bool owned;
  final RarityDef rarity;
  final int? level;
  final int? cards;
  final Widget? promote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return AspectRatio(
      aspectRatio: 1,
      child: PixelFrame(
        border: color,
        fill: Color.lerp(PixelPalette.navy, color, owned ? 0.35 : 0.18)!,
        highlight: null,
        borderDots: 2,
        child: LayoutBuilder(
          builder: (context, box) {
            // 초상은 실제 픽셀의 정수배로만 키운다(최근접 확대가 고르게).
            final scale = math.max(1, (box.maxWidth * dpr / _portraitDots).floor());
            final portrait = CrewPortrait(crew: def, size: scale * _portraitDots / dpr);
            return Stack(
              alignment: Alignment.center,
              children: [
                if (owned)
                  portrait
                else
                  ColorFiltered(colorFilter: const ColorFilter.mode(_silhouette, BlendMode.srcIn), child: portrait),
                Positioned(left: 0, bottom: 0, child: _Stars(rarity: rarity)),
                if (promote case final p?) Positioned(right: 0, bottom: 0, width: kMinTap, height: kMinTap, child: p),
                // 레벨(왼쪽 위)·카드 수(오른쪽 위) 작은 도트 배지.
                if (level case final lv?)
                  Positioned(left: 0, top: 0, child: _Badge(l10n.uiLevel(lv), key: Key('crew.level.${def.id}'))),
                if (cards case final c?)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _Badge(l10n.uiCrewCardBadge(c), key: Key('crew.cards.${def.id}')),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 초상 위 작은 도트 배지 (윤곽색 바탕, 글자는 본문보다 작은 도트 정수배).
class _Badge extends StatelessWidget {
  const _Badge(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: PixelPalette.outline,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          color: PixelPalette.text,
          fontSize: pixelFontSize(MediaQuery.devicePixelRatioOf(context), _badgeMinDp),
          height: 1.1,
        ),
      ),
    ),
  );
}

/// 등급 별: 별 그림 하나 + 개수 (16px 별 5개는 초상 폭을 넘는다). 숫자는 등급 색.
class _Stars extends StatelessWidget {
  const _Stars({required this.rarity});

  final RarityDef rarity;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: PixelPalette.outline,
    child: Row(
      key: const Key('crew.stars'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const PixelSprite(UiSprites.star, dots: 16, scale: 1),
        Padding(
          padding: const EdgeInsets.only(left: 1, right: 2),
          child: Text(
            rarity.stars.toString(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: rarityColor(rarity), height: 1),
          ),
        ),
      ],
    ),
  );
}

class _PromoteButton extends ConsumerWidget {
  const _PromoteButton({required this.crewId, required this.ready});

  final String crewId;
  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = AppLocalizations.of(context).uiCrewPromote;
    final button = Tooltip(
      message: label,
      child: PixelButton(
        key: Key('crew.promote.$crewId'),
        primary: true,
        compact: true,
        semanticLabel: label,
        onPressed: ready ? () => ref.read(commandSinkProvider).send(PromoteCrew(crewId)) : null,
        child: PixelBitmap(PixelBitmaps.up, color: ready ? PixelPalette.text : PixelPalette.textDim),
      ),
    );
    if (!ready) return button;
    // 빨간 점은 지금 눌러서 이득일 때만 (설계서 4.9) — 도트 네모 점.
    return Stack(
      children: [
        Positioned.fill(child: button),
        Positioned(
          right: 0,
          bottom: 22,
          child: SizedBox(
            key: Key('crew.dot.$crewId'),
            width: 6,
            height: 6,
            child: const ColoredBox(color: PixelPalette.danger),
          ),
        ),
      ],
    );
  }
}
