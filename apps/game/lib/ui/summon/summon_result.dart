import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/summon/summon_card.dart';
import 'package:pirate_dot/ui/summon/summon_cutin.dart';
import 'package:pirate_dot/ui/summon/summon_fx.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 결과 격자 열 수 범위 (10연은 3~5열 중 카드가 가장 큰 것).
const _minColumns = 3;
const _maxColumns = 5;

/// 튜토리얼에서 소환을 배우는 단계 — 결과 창을 닫으면 끝난다 (설계서 4.12 표).
const _summonTutorialStep = 4;

/// 카드가 날아와 깔리는 시간(장마다 [_landStagger]씩 늦게), 뒷면 기대감, 뒤집기 시간.
const _landEach = Duration(milliseconds: 380);
const _landStagger = Duration(milliseconds: 70);
const _hint = Duration(milliseconds: 1200);
const _flip = Duration(milliseconds: 820);

/// 소환 연출: 카드가 날아와 뒷면으로 깔림 → 등급 기대감 → 탭(또는 모두 열기)으로 3D 뒤집기 → 전설·신화 컷인 → 결과.
class SummonResultDialog extends ConsumerStatefulWidget {
  const SummonResultDialog({required this.results, super.key});

  final List<SummonResult> results;

  @override
  ConsumerState<SummonResultDialog> createState() => _SummonResultDialogState();
}

class _SummonResultDialogState extends ConsumerState<SummonResultDialog> with TickerProviderStateMixin {
  late final int _n = widget.results.length;
  late final AnimationController _hintCtl = AnimationController(vsync: this, duration: _hint);
  late final AnimationController _land = AnimationController(vsync: this, duration: _landEach + _landStagger * _n);
  late final List<AnimationController> _flips = [
    for (var i = 0; i < _n; i++) AnimationController(vsync: this, duration: _flip),
  ];
  late final List<bool> _revealed = List.filled(_n, false);

  /// 뒤집힌 뒤 보여 줄 전설·신화 컷인 줄.
  final _cutIns = <int>[];

  @override
  void initState() {
    super.initState();
    unawaited(_land.forward().whenComplete(() => _hintCtl.forward()));
  }

  @override
  void dispose() {
    _land.dispose();
    _hintCtl.dispose();
    for (final f in _flips) {
      f.dispose();
    }
    super.dispose();
  }

  /// [i]번 카드 착지 진행 (0→1, 장마다 조금씩 늦게).
  double _landFor(int i) {
    final total = _land.duration!.inMilliseconds;
    final start = (_landStagger * i).inMilliseconds / total;
    final end = start + _landEach.inMilliseconds / total;
    return Curves.easeOutBack.transform(((_land.value - start) / (end - start)).clamp(0, 1).toDouble());
  }

  int _tier(RarityTable r, int i) => r.rarities.indexWhere((x) => x.id == widget.results[i].rarity);

  void _reveal(int i) {
    if (_revealed[i]) return;
    final tier = _tier(ref.read(tablesProvider).rarities, i);
    setState(() => _revealed[i] = true);
    unawaited(
      _flips[i].forward().whenComplete(() {
        if (mounted && tier >= Tier.legend) setState(() => _cutIns.add(i));
      }),
    );
    // 등장음: 일반·희귀 pop, 영웅 작은 팡파르, 전설·신화 팡파르 (fx_map sfx id).
    ref
        .read(audioPortProvider)
        ?.playSfx(tier >= Tier.legend ? 'fanfare' : (tier >= Tier.hero ? 'fanfare_small' : 'pop'));
  }

  void _revealAll() {
    for (var i = 0; i < _n; i++) {
      _reveal(i);
    }
  }

  void _ack() {
    final sink = ref.read(commandSinkProvider)..send(const AckSummonResult());
    if (ref.read(tutorialStepProvider) == _summonTutorialStep) {
      sink.send(const TutorialAck(_summonTutorialStep));
    }
  }

  void _close() {
    _ack();
    Navigator.of(context).pop();
  }

  void _again() {
    _ack();
    Navigator.of(context).pop();
    ref.read(commandSinkProvider).send(Summon(count: _n));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final (shakeOn, flashOn) = ref.watch(gameStateProvider.select((s) => (s.settings.shake, s.settings.flash)));
    final canAgain = ref.watch(gameStateProvider.select((s) => canSummon(s, tables, _n)));
    final rarities = tables.rarities;
    final tiers = [for (var i = 0; i < _n; i++) _tier(rarities, i)];
    final best = tiers.reduce(math.max);
    final allRevealed = _revealed.every((r) => r);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([_land, _hintCtl]),
        builder: (context, _) {
          final hint = _hintCtl.value;
          // 화면 흔들림(전설 이상)·번쩍(신화) — 설정의 흔들림·번쩍임 끄기를 따른다.
          final shake = shakeOn && best >= Tier.legend ? math.sin(hint * math.pi * 20) * 4 * (1 - hint) : 0.0;
          final flash = flashOn && best >= Tier.mythic ? math.max(0, 1 - (hint - 0.5).abs() * 6) : 0.0;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [const Color(0xFF243565), Skin.night.withValues(alpha: 0.97)],
                      radius: 1.1,
                    ),
                  ),
                ),
              ),
              if (best >= Tier.mythic) Positioned.fill(child: AuroraSweep(t: hint)),
              if (best >= Tier.legend)
                Positioned.fill(
                  child: SparkBurst(t: hint, rainbow: best >= Tier.mythic),
                ),
              SafeArea(
                child: Transform.translate(
                  offset: Offset(shake, 0),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(l10n.uiSummonResultTitle, style: Skin.text(24, color: Colors.white)),
                      Expanded(child: _grid(l10n, tables, tiers, hint)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: allRevealed ? _resultButtons(l10n, canAgain: canAgain) : _revealAllButton(l10n),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (flash > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: Colors.white.withValues(alpha: flash * 0.8)),
                  ),
                ),
              if (_cutIns.isNotEmpty)
                Positioned.fill(
                  child: SummonCutIn(
                    key: ValueKey(_cutIns.first),
                    crew: tables.crews.byId(widget.results[_cutIns.first].crewId),
                    rarity: rarities.rarities[tiers[_cutIns.first]],
                    tier: tiers[_cutIns.first],
                    onDone: () => setState(() => _cutIns.removeAt(0)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _revealAllButton(AppLocalizations l10n) => SkinButton(
    key: const Key('summon.revealAll'),
    height: 56,
    onPressed: _revealAll,
    child: Text(l10n.uiSummonRevealAll),
  );

  Widget _resultButtons(AppLocalizations l10n, {required bool canAgain}) => Row(
    children: [
      Expanded(
        child: SkinButton(
          key: const Key('summon.again'),
          tone: SkinTone.gold,
          height: 56,
          onPressed: canAgain ? _again : null,
          child: Text(l10n.uiSummonAgain),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SkinButton(
          key: const Key('summon.result.ok'),
          height: 56,
          onPressed: _close,
          child: Text(l10n.uiSummonResultOk),
        ),
      ),
    ],
  );

  /// 카드 격자: 화면 폭·높이에 맞춰 가장 크게 (10연 2×5, 1회 1장).
  Widget _grid(AppLocalizations l10n, GameTables tables, List<int> tiers, double hint) => LayoutBuilder(
    builder: (context, box) {
      // 열 수 3~5 중 카드가 가장 크게 나오는 것 (세로 화면은 3~4열, 태블릿·가로는 5열).
      const gap = 10.0;
      double widthFor(int cols) {
        final rows = (_n / cols).ceil();
        final maxW = (box.maxWidth - 32 - gap * (cols - 1)) / cols;
        // 카드 아래 특색 줄 높이를 뺀다.
        final maxH = (box.maxHeight - 24 - gap * (rows - 1)) / rows - summonCaptionHeight;
        return math.min(maxW, maxH * pbCardAspect);
      }

      final options = _n <= _maxColumns ? [_n] : [for (var c = _minColumns; c <= _maxColumns; c++) c];
      final best = options.reduce((a, b) => widthFor(b) > widthFor(a) ? b : a);
      final w = widthFor(best).clamp(40.0, _n == 1 ? 260.0 : 180.0);
      return Center(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _n; i++)
              SizedBox(
                width: w,
                child: SummonRevealCard(
                  index: i,
                  result: widget.results[i],
                  tier: tiers[i],
                  hint: hint,
                  land: _landFor(i),
                  flip: _flips[i],
                  onTap: () => _reveal(i),
                ),
              ),
          ],
        ),
      );
    },
  );
}
