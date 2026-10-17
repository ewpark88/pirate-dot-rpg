import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

// 설정 '도움말' (S1 2026-10-18): 새 시스템 짧은 설명 — 탑·러시·던전·업적·패스·필살기·피버(칸을 누르면 펼침) + 큰 수 단위(E11).

class HelpSection extends StatelessWidget {
  const HelpSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = [
      ('tower', UiSprites.flag, l.uiHelpTower, l.uiHelpTowerBody),
      ('rush', UiSprites.trophy, l.uiHelpRush, l.uiHelpRushBody),
      ('dungeon', UiSprites.tabMap, l.uiHelpDungeon, l.uiHelpDungeonBody),
      ('achievements', UiSprites.trophy, l.uiHelpAchievements, l.uiHelpAchievementsBody),
      ('pass', UiSprites.star, l.uiHelpPass, l.uiHelpPassBody),
      ('ultimate', UiSprites.tailwind, l.uiHelpUltimate, l.uiHelpUltimateBody),
      ('fever', UiSprites.star, l.uiHelpFever, l.uiHelpFeverBody),
    ];
    return Column(
      children: [
        for (final (id, icon, title, body) in items)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: Key('help.$id'),
              leading: SkinIcon(icon, size: 28),
              title: Text(title, style: Skin.bold(15)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedAlignment: Alignment.centerLeft,
              children: [Text(body, style: Skin.text(14, color: Skin.sub))],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l.uiNumberUnits, style: Skin.text(13, color: Skin.sub)),
        ),
      ],
    );
  }
}
