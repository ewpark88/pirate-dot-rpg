import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/dock/upgrade_all.dart' show canUpgradeAnyProvider;
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/guide/guide_spots.dart';
import 'package:pirate_dot/ui/guide/guide_talk.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 가리킨 자리를 다시 읽는 간격 — 시트를 끌거나 탭을 굴려도 따라간다. 바뀔 때만 다시 그린다.
const _track = Duration(milliseconds: 150);

/// 새 말이 나오기 전 쉼 (S1: 앞 행동의 결과가 끝나고 0.5~1초 뒤).
const _pause = Duration(milliseconds: 700);

/// 반응('좋아요! …')이 머무는 시간.
const _reactionFor = Duration(milliseconds: 1500);

/// 전투 중 말이 초상만 남게 접히기까지.
const _collapseAfter = Duration(seconds: 3);

/// 가이드 v3 층: 홈 화면 위에 옥토 선장 말풍선 + 누를 곳 빛 테두리·손가락. 튜토리얼 누를 곳 단계는 밝은 곳 밖 누름을 막는다.
/// 창(소환 결과 등)은 이 층 위 경로라 가리지 않는다.
class GuideLayer extends ConsumerStatefulWidget {
  const GuideLayer({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GuideLayer> createState() => _GuideLayerState();
}

class _GuideLayerState extends ConsumerState<GuideLayer> {
  final GlobalKey _box = GlobalKey();
  Timer? _tracker;
  Timer? _pauseTimer;
  Timer? _reactionTimer;
  Timer? _collapse;
  StreamSubscription<RecordedTick>? _sub;

  /// 가리킬 수 있는 id → 지금 화면 자리(층 좌표).
  Map<String, List<Rect>> _rects = const {};

  /// 지금 보이는 말의 key (쉼이 끝나야 채워진다).
  String? _shown;
  String? _pending;
  String? _reaction;
  int _taps = 0;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _tracker = Timer.periodic(_track, (_) => _refresh());
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      final step = ref.read(tutorialStepProvider);
      if (step == null || step > 3) return;
      for (final e in tick.events) {
        if (e is PartUpgraded && mounted) _react(e);
      }
    });
  }

  @override
  void dispose() {
    _tracker?.cancel();
    _pauseTimer?.cancel();
    _reactionTimer?.cancel();
    _collapse?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  /// 강화하면 짧게 칭찬하고(초록), 그 뒤 다음 말.
  void _react(PartUpgraded e) {
    final l10n = AppLocalizations.of(context);
    final def = ref.read(tablesProvider).shipParts.byId(e.part);
    _reactionTimer?.cancel();
    setState(() => _reaction = l10n.uiTalkNice(tableText(l10n, def.nameKey), e.level));
    _reactionTimer = Timer(_reactionFor, () {
      if (mounted) setState(() => _reaction = null);
    });
  }

  void _refresh() {
    if (!mounted) return;
    final box = _box.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final ids = {...ref.read(guidePointedProvider), ?ref.read(guideLineProvider)?.spot};
    final next = {
      for (final id in ids)
        id: [
          for (final r in guideSpotRects([id]))
            Rect.fromPoints(box.globalToLocal(r.topLeft), box.globalToLocal(r.bottomRight)),
        ],
    };
    if (!_sameRects(next, _rects)) setState(() => _rects = next);
  }

  static bool _sameRects(Map<String, List<Rect>> a, Map<String, List<Rect>> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null || o.length != e.value.length) return false;
      for (var i = 0; i < o.length; i++) {
        if ((o[i].topLeft - e.value[i].topLeft).distance > 0.5 ||
            (o[i].size - e.value[i].size as Offset).distance > 0.5) {
          return false;
        }
      }
    }
    return true;
  }

  /// 말이 바뀌면 잠깐 쉬었다가 보인다. 전투 말은 3초 뒤 접힌다.
  void _onTalk(GuideTalk? talk) {
    final key = talk?.key;
    if (key == _pending) return;
    _pending = key;
    _pauseTimer?.cancel();
    _collapse?.cancel();
    _collapsed = false;
    _shown = null;
    if (talk == null) return;
    _pauseTimer = Timer(_pause, () {
      if (!mounted) return;
      setState(() {
        _shown = talk.key;
        _taps++;
      });
      if (talk.battle) {
        _collapse = Timer(_collapseAfter, () {
          if (mounted) setState(() => _collapsed = true);
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _ack() {
    final step = ref.read(tutorialStepProvider);
    if (step != null) {
      ref.read(commandSinkProvider).send(TutorialAck(step));
    } else {
      ref.read(guideQueueProvider.notifier).close();
    }
  }

  Future<void> _skip() async {
    final l10n = AppLocalizations.of(context);
    final off = await showDialog<bool>(
      context: context,
      builder: (_) => GuideSkipDialog(l10n: l10n),
    );
    if (off != true || !mounted) return;
    if (ref.read(tutorialStepProvider) != null) {
      ref.read(commandSinkProvider).send(const SkipTutorial());
    } else {
      ref.read(guideQueueProvider.notifier).skipAll();
    }
  }

  bool _visible(String id) => _rects[id]?.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step = ref.watch(tutorialStepProvider);
    final id = ref.watch(guideQueueProvider);
    final line = ref.watch(guideLineProvider);
    final farming = ref.watch(gameStateProvider.select((s) => s.progress.farming));
    final canUpgrade = ref.watch(canUpgradeAnyProvider);
    final scene = (
      shipOpen: _visible('ship.upgrade.cannon'),
      summonOpen: _visible('summon.ten'),
      crewOpen: _visible('crew.mergeAll'),
      farming: farming,
      canUpgrade: canUpgrade,
    );
    // 덧씌운 말(스토리보드·운영자)이 먼저, 그다음 튜토리얼·시스템 안내.
    final talk = line != null
        ? (
            key: 'line:${line.text}',
            text: line.text,
            spots: [?line.spot],
            ack: false,
            block: false,
            battle: false,
            dim: line.dim,
          )
        : guideTalkFor(l10n, scene: scene, step: step, id: id);
    _onTalk(talk);
    final showing = talk != null && _shown == talk.key && _reaction == null;
    final holes = !showing || talk.battle ? const <Rect>[] : [for (final s in talk.spots) ...?_rects[s]];
    final calm =
        MediaQuery.disableAnimationsOf(context) || !ref.watch(gameStateProvider.select((s) => s.settings.flash));
    // 누를 곳이 화면에 없으면(시트가 닫혀 버튼이 안 보임 등) 막지 않는다 — 갇히지 않게.
    final block = showing && talk.block && holes.isNotEmpty;
    final dim = showing && talk.dim ? 0.35 : 0.0;
    final layer = _box.currentContext?.findRenderObject() as RenderBox?;
    final text = _reaction ?? (showing ? talk.text : null);
    return Stack(
      key: _box,
      children: [
        widget.child,
        if (dim > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DimPainter(holes: holes, alpha: dim),
              ),
            ),
          ),
        if (block)
          Positioned.fill(
            child: _HoleBlocker(holes: holes, onBlocked: () => setState(() => _taps++)),
          ),
        // 시스템 안내: 누를 곳을 누르면(했다) 닫는다. 누름은 그대로 아래로 간다.
        if (showing && !block && step == null && line == null && holes.isNotEmpty)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                if (holes.any((h) => h.contains(e.localPosition))) ref.read(guideQueueProvider.notifier).close();
              },
            ),
          ),
        // 누를 곳만 살짝 빛나는 금빛 테두리 + 톡톡 손가락.
        for (final (i, h) in holes.indexed)
          Positioned.fromRect(
            rect: h.inflate(4),
            child: IgnorePointer(
              child: DecoratedBox(
                key: Key('talk.glow.$i'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD84A), width: 3),
                  boxShadow: const [BoxShadow(color: Color(0xAAFFD84A), blurRadius: 12, spreadRadius: 2)],
                ),
              ),
            ),
          ),
        if (holes.isNotEmpty) GuideFinger(at: holes.first, taps: _taps, calm: calm),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              final bottom = talkBottom(context, box.biggest, holes.isEmpty ? null : holes.first, layer: layer);
              return Stack(
                children: [
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: bottom,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      // 모션 기준: 아래에서 살짝 올라오며 페이드(200ms, ease-out).
                      child: AnimatedSwitcher(
                        duration: calm ? Duration.zero : talkMotion,
                        switchInCurve: Curves.easeOut,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a),
                            child: child,
                          ),
                        ),
                        child: text == null
                            ? const SizedBox.shrink()
                            : GuideTalkBubble(
                                key: ValueKey(text),
                                text: text,
                                reaction: _reaction != null,
                                collapsed: _collapsed && _reaction == null,
                                tapHint: _reaction == null && talk!.ack && step != null,
                                onTap: _reaction != null || line != null
                                    ? null
                                    : (_collapsed
                                          ? () => setState(() => _collapsed = false)
                                          : (talk!.ack ? _ack : null)),
                                onSkip: _reaction != null || line != null || _collapsed
                                    ? null
                                    : () => unawaited(_skip()),
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 전체를 [alpha]만큼 어둡게, [holes]만 밝게(둥근 구멍).
class _DimPainter extends CustomPainter {
  _DimPainter({required this.holes, required this.alpha});

  final List<Rect> holes;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()..addRect(Offset.zero & size);
    for (final h in holes) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addRRect(RRect.fromRectAndRadius(h.inflate(6), const Radius.circular(12))),
      );
    }
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.alpha != alpha || old.holes != holes;
}

/// 구멍 밖 누름을 삼키고 [onBlocked]를 부른다. 구멍 안은 아래 위젯이 받는다.
class _HoleBlocker extends LeafRenderObjectWidget {
  const _HoleBlocker({required this.holes, required this.onBlocked});

  final List<Rect> holes;
  final VoidCallback onBlocked;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHoleBlocker(holes, onBlocked);

  @override
  void updateRenderObject(BuildContext context, _RenderHoleBlocker r) => r
    ..holes = holes
    ..onBlocked = onBlocked;
}

class _RenderHoleBlocker extends RenderBox {
  _RenderHoleBlocker(this.holes, this.onBlocked);

  List<Rect> holes;
  VoidCallback onBlocked;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => !holes.any((h) => h.inflate(6).contains(position));

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) onBlocked();
  }
}

/// 가리킨 곳 오른쪽 아래 모서리에 큰 손가락 — 3번 톡톡 누르고 멈춘다([taps]가 바뀌면 다시). 동작 줄이기면 가만히.
class GuideFinger extends StatelessWidget {
  const GuideFinger({required this.at, required this.taps, required this.calm, super.key});

  final Rect at;
  final int taps;
  final bool calm;

  @override
  Widget build(BuildContext context) => Positioned(
    // 글자(탭 이름 등)를 덮지 않게 오른쪽 아래 모서리.
    left: at.right - 24,
    top: at.bottom - 28,
    child: IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(taps),
        tween: Tween(begin: 0, end: calm ? 0 : 3),
        duration: const Duration(milliseconds: 2400),
        builder: (_, v, child) {
          // 한 번 톡 = 0.8초: 아래로 눌렀다 올라옴.
          final t = v - v.floor();
          final press = v >= 3 ? 0.0 : (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Transform.translate(offset: Offset(0, -8 * press), child: child);
        },
        child: const Icon(
          Icons.touch_app_rounded,
          key: Key('guide.finger'),
          size: 40,
          color: Colors.white,
          shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
      ),
    ),
  );
}
