import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';
import 'package:pirate_dot/ui/widgets/crew_portrait.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

/// 결과 카드 한 줄에 몇 장 (10연 = 2줄 × 5장).
const _perRow = 5;

/// 카드 가로:세로.
const _cardAspect = 0.45;

/// 카드 뒤집기 시간.
const _flip = Duration(milliseconds: 250);

/// 튜토리얼에서 소환을 배우는 단계 — 결과 창을 닫으면 끝난다 (설계서 4.12 표).
const _summonTutorialStep = 4;

/// `lastSummon`이 생기면 소환 결과 창을 하나 띄운다 (설계서 4.12 팝업 3가지 중 ‘소환 결과’).
class SummonResultGate extends ConsumerStatefulWidget {
  const SummonResultGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SummonResultGate> createState() => _SummonResultGateState();
}

class _SummonResultGateState extends ConsumerState<SummonResultGate> {
  var _open = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(gameStateProvider.select((s) => s.lastSummon), (_, results) => _show(results));
    // 시작할 때 이미 결과가 있으면(복원 직후 등) 첫 프레임 뒤에 띄운다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(ref.read(gameStateProvider).lastSummon));
  }

  void _show(List<SummonResult>? results) {
    if (_open || results == null || results.isEmpty || !mounted) return;
    _open = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SummonResultDialog(results: results),
      ).whenComplete(() => _open = false),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 카드 뒤집기: 눌러서 한 장씩 또는 ‘모두 뒤집기’. 다 뒤집으면 확인 → AckSummonResult.
class SummonResultDialog extends ConsumerStatefulWidget {
  const SummonResultDialog({required this.results, super.key});

  final List<SummonResult> results;

  @override
  ConsumerState<SummonResultDialog> createState() => _SummonResultDialogState();
}

class _SummonResultDialogState extends ConsumerState<SummonResultDialog> {
  late final List<bool> _revealed = List.filled(widget.results.length, false);

  void _close() {
    final sink = ref.read(commandSinkProvider)..send(const AckSummonResult());
    if (ref.read(tutorialStepProvider) == _summonTutorialStep) {
      sink.send(const TutorialAck(_summonTutorialStep));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rarities = ref.watch(tablesProvider).rarities;
    final allRevealed = _revealed.every((r) => r);
    return PixelDialog(
      title: l10n.uiSummonResultTitle,
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: widget.results.length < _perRow ? widget.results.length : _perRow,
          childAspectRatio: _cardAspect,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < widget.results.length; i++)
              GestureDetector(
                onTap: () => setState(() => _revealed[i] = true),
                child: AnimatedSwitcher(
                  duration: _flip,
                  child: _revealed[i]
                      ? _Face(index: i, result: widget.results[i], rarities: rarities)
                      : _Back(key: Key('summon.card.$i.back')),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (allRevealed)
          PixelButton(
            key: const Key('summon.result.ok'),
            primary: true,
            onPressed: _close,
            child: Text(l10n.uiSummonResultOk),
          )
        else
          PixelButton(
            key: const Key('summon.revealAll'),
            onPressed: () => setState(() => _revealed.fillRange(0, _revealed.length, true)),
            child: Text(l10n.uiSummonRevealAll),
          ),
      ],
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({super.key});

  @override
  Widget build(BuildContext context) => const PixelFrame(
    fill: PixelPalette.action,
    child: Center(child: PixelSprite(UiSprites.cardBack, dots: 32, scale: 1)),
  );
}

/// 등장 연출 길이: 기본 + 등급 순번마다 더 (높은 등급일수록 길게).
const _revealBaseMs = 200;
const _revealStepMs = 120;

/// 등급 순번별 번쩍임 최대 세기 (일반 → 신화).
const _flashPeak = [0.3, 0.5, 0.7, 0.9, 0.9];

/// 테두리 빛을 받는 등급 수 (위에서부터: 전설·신화).
const _glowTiers = 2;

/// 번쩍임은 4단계로 끊어서 줄인다 (부드러운 페이드 대신 도트 느낌).
const _flashSteps = 4;

/// 앞면: 등급 색 도트 테두리 안 정수배 초상 · 이름 · 별. 처음 그려질 때 등급별 도트 번쩍임,
/// 전설·신화는 테두리가 깜빡인 뒤 바깥 1칸 빛 테두리가 남는다. 설정 ‘번쩍임’이 꺼져 있으면 번쩍이지 않는다.
class _Face extends ConsumerStatefulWidget {
  const _Face({required this.index, required this.result, required this.rarities});

  final int index;
  final SummonResult result;
  final RarityTable rarities;

  @override
  ConsumerState<_Face> createState() => _FaceState();
}

class _FaceState extends ConsumerState<_Face> with SingleTickerProviderStateMixin {
  late final int _tier = widget.rarities.rarities.indexWhere((r) => r.id == widget.result.rarity);
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _revealBaseMs + _revealStepMs * _tier),
  )..forward();

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final flashOn = ref.watch(gameStateProvider.select((s) => s.settings.flash));
    final rarities = widget.rarities;
    final rarity = rarities.rarities[_tier];
    final order = rarities.rarities.map((r) => r.id).toList();
    // 천장 등급(영웅) 이상은 강조 — 10연 확정 카드가 눈에 띄게.
    final highlight = _tier >= order.indexOf(rarities.pityMinRarity);
    final glow = _tier >= rarities.rarities.length - _glowTiers;
    final color = rarityColor(rarity);
    final crew = tables.crews.byId(widget.result.crewId);
    final small = Theme.of(context).textTheme.labelSmall;
    final u = pixelUnit(context);
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) {
        final t = _reveal.value;
        // 전설·신화: 연출 동안 테두리가 흰색과 등급 색을 3번 오간다.
        final blinkWhite = glow && t < 1 && (t * 6).floor().isEven;
        final flash = flashOn && t < 1
            ? _flashPeak[_tier.clamp(0, _flashPeak.length - 1)] * ((1 - t) * _flashSteps).ceil() / _flashSteps
            : 0.0;
        final card = PixelFrame(
          key: Key('summon.card.${widget.index}.face'),
          border: blinkWhite ? PixelPalette.text : color,
          fill: Color.lerp(PixelPalette.navy, color, 0.3)!,
          highlight: null,
          borderDots: highlight ? 2 : 1,
          padding: highlight ? 3 : 2,
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (highlight) SizedBox.shrink(key: Key('summon.card.${widget.index}.highlight')),
                  if (widget.result.isNew)
                    Text(
                      l10n.uiSummonNew,
                      style: small?.copyWith(color: PixelPalette.danger, fontWeight: FontWeight.bold),
                    ),
                  // 초상: 카드 폭 안에서 실제 픽셀 정수배로 가장 크게.
                  LayoutBuilder(
                    builder: (context, box) {
                      final scale = (box.maxWidth * dpr / 32).floor().clamp(1, 1 << 10);
                      return CrewPortrait(crew: crew, size: scale * 32 / dpr);
                    },
                  ),
                  // 별 줄을 이름 위로, 이름은 짧은 이름 한 줄 (요청서 platform-ui-store-shots).
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PixelSprite(UiSprites.star, dots: 16, scale: 1),
                      Text(rarity.stars.toString(), style: small?.copyWith(color: color)),
                    ],
                  ),
                  Text(
                    shortCrewName(l10n, crew),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: small,
                  ),
                ],
              ),
              if (flash > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: PixelPalette.text.withValues(alpha: flash)),
                  ),
                ),
            ],
          ),
        );
        if (!glow) return card;
        // 테두리 빛: 바깥 1칸 등급 색(밝게) 테두리.
        return DecoratedBox(
          key: Key('summon.card.${widget.index}.glow'),
          decoration: BoxDecoration(color: Color.lerp(color, PixelPalette.text, 0.35)),
          child: Padding(padding: EdgeInsets.all(u), child: card),
        );
      },
    );
  }
}
