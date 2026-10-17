import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_text.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

/// 항해 탭 해역 이름 옆 칭호 띠 (칭호가 하나라도 있으면). 누르면 칭호 목록.
class TitleChip extends ConsumerWidget {
  const TitleChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = ref.watch(titleProvider);
    if (titles.owned.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final text = titles.selected == null ? l10n.uiTitle : titleName(l10n, titles.selected!);
    return Semantics(
      button: true,
      label: '${l10n.uiTitle}: $text',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('title.chip'),
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showPixelSheet<void>(context, builder: (_) => const TitleSheet())),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Skin.goldTop, Skin.goldBottom]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
            ),
            child: Text(text, style: Skin.bold(13, color: Skin.goldInk)),
          ),
        ),
      ),
    );
  }
}

/// 칭호 목록: 가진 것은 고르기, 없는 것은 '환생 N회'.
class TitleSheet extends ConsumerWidget {
  const TitleSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final titles = ref.watch(titleProvider);
    final control = ref.read(rebirthV2Provider);
    Widget row(String? id, String name, {required bool owned, int? need}) {
      final selected = titles.selected == id;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          button: owned,
          selected: selected,
          label: name,
          excludeSemantics: true,
          child: GestureDetector(
            key: Key('title.${id ?? 'none'}'),
            behavior: HitTestBehavior.opaque,
            onTap: owned ? () => control.selectTitle(id) : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // k2: 굵은 외곽선 줄(고른 것 = 파랑 테, 잠김 = 옅은 회보라).
              decoration: Skin.inset(
                fill: owned ? Skin.insetFill : const Color(0xFFD3D1EA),
                border: selected ? Skin.primaryBottom : Skin.outline,
                radius: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(name, style: Skin.text(17, color: owned ? Skin.ink : Skin.sub)),
                  ),
                  if (need != null && !owned) ...[
                    const SkinIcon(UiSprites.lock),
                    const SizedBox(width: 4),
                    Text(l10n.uiTitleLocked(need), style: Skin.text(14, color: Skin.sub)),
                  ] else if (selected)
                    const SkinIcon(UiSprites.check),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      key: const Key('title.sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubRibbon(l10n.uiTitle),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                row(null, l10n.uiTitleNone, owned: true),
                for (final (id, n) in titleDefs)
                  row(id, titleName(l10n, id), owned: titles.owned.contains(id), need: n),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
