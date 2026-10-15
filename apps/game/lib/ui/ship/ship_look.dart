import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/render/top/ship_preview.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/summon/summon_fx.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 배 미리보기 (S1 지시): 그림은 렌더(S3) ShipPreview — 전장과 같은 층 그림·같은 스킨 색 바꾸기.

/// 지금 배 그림에 필요한 값: 등급 그림(명예 포함), 부위별 외형 단계(명예 포함), 스킨.
typedef ShipLookVm = ({String tier, Map<String, int> look, String? skin});

final shipLookProvider = Provider<ShipLookVm>((ref) {
  final t = ref.watch(tablesProvider);
  // 지도는 ==가 없어서 글자 열쇠로 바뀔 때만 다시 만든다.
  final key = ref.watch(
    gameStateProvider.select((s) {
      final look = partLook(s, t);
      final tier = s.battle?.shipTierLook ?? t.shipTiers.tierAt(s.progress.stage).id;
      return '$tier|${s.ship.skin}|${[for (final p in t.shipParts.parts) look[p.id] ?? 0].join(',')}';
    }),
  );
  final [tier, skin, stages] = key.split('|');
  final values = stages.split(',').map(int.parse).toList();
  return (
    tier: tier,
    look: {for (final (i, p) in t.shipParts.parts.indexed) p.id: values[i]},
    skin: skin == 'null' ? null : skin,
  );
});

/// 스킨 팔레트 (렌더 계약 전 임시 위치: fx_map topShip.skinPreview.(id)). 없으면 null.
JsonReader? skinPalette(GameTables t, String? id) {
  if (id == null) return null;
  final top = t.fxMap.raw.obj('topShip');
  if (!top.has('skinPreview')) return null;
  final all = top.obj('skinPreview');
  return all.has(id) ? all.obj(id) : null;
}

/// 지금 배 그림. [skin]을 주면(스킨 고르기) 그 스킨으로, [look]을 주면(다음 외형) 그 단계로 그린다.
class ShipLookPreview extends ConsumerWidget {
  const ShipLookPreview({
    this.size = 120,
    this.skin,
    this.useSkin = false,
    this.look,
    this.glowPart,
    this.glow = 0,
    super.key,
  });

  final double size;

  /// [useSkin]이 true면 지금 장착 스킨 대신 이 스킨(null = 기본 배).
  final String? skin;
  final bool useSkin;
  final Map<String, int>? look;
  final String? glowPart;
  final double glow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tablesProvider);
    final now = ref.watch(shipLookProvider);
    final id = useSkin ? skin : now.skin;
    return SizedBox.square(
      dimension: size,
      child: ShipPreview(
        tables: t,
        tier: now.tier,
        look: look ?? now.look,
        skin: id,
        skinPalette: skinPalette(t, id),
        size: size,
        glowPart: glowPart,
        glow: glow,
      ),
    );
  }
}

/// [def]의 Lv[level] 다음 외형이 바뀌는 레벨 (더 없으면 null).
int? nextLookLevel(ShipPartDef def, int level) {
  for (final v in def.visualStages) {
    if (v > level) return v;
  }
  return null;
}

/// 부위 외형이 바뀌면(ShipLookChanged) 축하 팝업: 새 배를 크게, 바뀐 부위가 흰빛으로 빛났다 사라진다.
class ShipLookCelebrationGate extends ConsumerStatefulWidget {
  const ShipLookCelebrationGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ShipLookCelebrationGate> createState() => _ShipLookCelebrationGateState();
}

class _ShipLookCelebrationGateState extends ConsumerState<ShipLookCelebrationGate> {
  StreamSubscription<RecordedTick>? _sub;
  var _open = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is ShipLookChanged) _show(e);
      }
    });
  }

  void _show(ShipLookChanged e) {
    // 길게 눌러 연속 강화할 때 여러 번 와도 창은 하나 (피로).
    if (_open || !mounted) return;
    _open = true;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => ShipLookCelebration(part: e.part, stage: e.stage),
      ).whenComplete(() => _open = false),
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ShipLookCelebration extends ConsumerStatefulWidget {
  const ShipLookCelebration({required this.part, required this.stage, super.key});

  final String part;
  final int stage;

  @override
  ConsumerState<ShipLookCelebration> createState() => _ShipLookCelebrationState();
}

class _ShipLookCelebrationState extends ConsumerState<ShipLookCelebration> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final def = ref.watch(tablesProvider).shipParts.byId(widget.part);
    return Dialog(
      key: const Key('ship.look.celebrate'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: Skin.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Skin.goldBottom, width: 3),
            boxShadow: Skin.shadow,
          ),
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final v = _t.value;
              // 처음 0.4초 커지며 등장, 부위 흰빛은 0.3초에 가장 밝았다가 사라진다.
              final pop = Curves.easeOutBack.transform((v / 0.3).clamp(0, 1).toDouble());
              final glow = v < 0.3 ? v / 0.3 : (1 - (v - 0.3) / 0.7).clamp(0.0, 1.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.uiShipLookTitle, style: Skin.text(22, color: Skin.primaryEdge)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.uiShipLookPart(tableText(l10n, def.nameKey), widget.stage + 1),
                    style: Skin.text(15, color: Skin.sub),
                  ),
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(child: SparkBurst(t: v.clamp(0, 0.99).toDouble(), rainbow: false)),
                        Transform.scale(
                          scale: 0.6 + 0.4 * pop,
                          child: ShipLookPreview(size: 180, glowPart: widget.part, glow: glow),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: SkinButton(
                      key: const Key('ship.look.ok'),
                      tone: SkinTone.gold,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.uiOk),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
