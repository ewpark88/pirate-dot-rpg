import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/power/power_channel.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/power_policy.dart';
import 'package:pirate_dot/render/preview/crew_preview_view.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 미리보기 아트 팩 — 본 전투(Flame)의 것을 빌린다(같은 그림을 두 번 읽지 않게). 없으면 플레이스홀더. 시험은 덮어쓴다.
final previewSpritesProvider = Provider<SpriteBank?>(
  (ref) => ref.watch(hasBattleGameProvider) ? ref.read(battleGameProvider).spriteBank : null,
);

/// 미리보기를 움직일지 — UI 시험 하네스가 끈다(첫 장면만, pumpAndSettle이 끝나게).
final crewPreviewPlayProvider = Provider<bool>((_) => true);

/// 상세 창 공격 미리보기(S1 2026-10-17 '넣으면 어떻게 공격하는지 알 수 있게'): 16:9 작은 전장 + 등급 탭
/// (지금 / 다음 / 전설 / 신화 — 같은 등급은 한 번만). 지금 탭은 보유면 지금 레벨, 아니면 기본 등급 첫 레벨, 나머지는 그 등급 첫 레벨.
/// 장면은 공용 하네스(CrewPreview — 저장·진행에 안 닿음). 창이 닫히면 위젯과 함께 멈춘다.
class CrewPreviewPanel extends ConsumerStatefulWidget {
  const CrewPreviewPanel({required this.def, super.key});

  final CrewDef def;

  @override
  ConsumerState<CrewPreviewPanel> createState() => _CrewPreviewPanelState();
}

class _CrewPreviewPanelState extends ConsumerState<CrewPreviewPanel> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    if (!CrewPreview.enabled(tables)) return const SizedBox.shrink();
    final level = ref.watch(gameStateProvider.select((s) => s.crews[widget.def.id]?.level));
    final rarities = tables.rarities.rarities;
    final now = level == null
        ? rarities.indexWhere((r) => r.id == widget.def.baseRarity)
        : rarities.indexOf(rarityOfLevel(tables.rarities, level));
    // (등급 순번, 레벨, 지금 탭인가). 다음 → 전설 → 신화, 지금보다 낮거나 같은 등급은 뺀다.
    final legend = rarities.indexWhere((r) => r.id == 'legend');
    final tabs = <(int, int, bool)>[
      (now, level ?? rarities[now].levelMin, true),
      for (final i in {now + 1, legend, rarities.length - 1})
        if (i > now && i < rarities.length) (i, rarities[i].levelMin, false),
    ];
    final pick = tabs[_tab.clamp(0, tabs.length - 1)];
    final sprites = ref.watch(previewSpritesProvider);
    final lite =
        ref.watch(gameStateProvider.select((s) => s.settings.powerSave)) ||
        ref.watch(thermalLevelProvider).index >= ThermalLevel.moderate.index;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.uiPreviewTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CrewPreviewView(
                key: Key('crew.preview.${widget.def.id}'),
                tables: tables,
                crewId: widget.def.id,
                level: pick.$2,
                sprites: sprites,
                lite: lite,
                play: ref.watch(crewPreviewPlayProvider),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final (i, (rarity, _, isNow)) in tabs.indexed)
                ChoiceChip(
                  key: Key('crew.preview.tab.${rarities[rarity].id}'),
                  label: Text(
                    isNow
                        ? '${l10n.uiPreviewNow} · ${tableText(l10n, rarities[rarity].nameKey)}'
                        : tableText(l10n, rarities[rarity].nameKey),
                    style: Skin.text(13),
                  ),
                  selected: pick == tabs[i],
                  selectedColor: rarityColor(rarities[rarity]).withValues(alpha: 0.3),
                  side: BorderSide(color: rarityColor(rarities[rarity])),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _tab = i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
