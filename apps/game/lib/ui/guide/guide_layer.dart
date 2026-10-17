import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/guide/guide_card_view.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/guide/guide_spots.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

/// 가리킨 자리를 다시 읽는 간격 — 시트를 끌거나 탭을 굴려도 구멍이 따라간다. 바뀔 때만 다시 그린다.
const _track = Duration(milliseconds: 150);

/// 전투 카드가 알약으로 접히기까지.
const _collapseAfter = Duration(seconds: 3);

/// 가이드 v2 층 (docs/specs/ui-guide-v2.md): 홈 화면 위에 카드 하나 + 가리킨 곳만 밝게 + 큰 손가락.
/// 튜토리얼 단계는 밝은 곳 밖 누름을 막고(어두운 곳을 누르면 손가락이 다시 톡톡 + '여기를 눌러요'),
/// 처음 만나는 시스템 카드는 막지 않는다. 창(소환 결과 등)은 이 층 위 경로라 가리지 않는다.
class GuideLayer extends ConsumerStatefulWidget {
  const GuideLayer({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GuideLayer> createState() => _GuideLayerState();
}

class _GuideLayerState extends ConsumerState<GuideLayer> {
  final GlobalKey _box = GlobalKey();
  Timer? _tracker;
  Timer? _collapse;
  List<Rect> _holes = const [];

  /// 손가락 톡톡을 다시 시작하는 번호(카드가 바뀌거나 어두운 곳을 눌렀을 때).
  int _taps = 0;
  bool _nudge = false;
  bool _collapsed = false;
  String? _shownKey;

  @override
  void initState() {
    super.initState();
    _tracker = Timer.periodic(_track, (_) => _refresh());
  }

  @override
  void dispose() {
    _tracker?.cancel();
    _collapse?.cancel();
    super.dispose();
  }

  List<String> _spots() {
    final step = ref.read(tutorialStepProvider);
    if (step != null) return [...?tutorialSpots[step]];
    return [...?guideSpots[ref.read(guideQueueProvider)]];
  }

  void _refresh() {
    if (!mounted) return;
    final box = _box.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final local = [
      for (final r in guideSpotRects(_spots()))
        Rect.fromPoints(box.globalToLocal(r.topLeft), box.globalToLocal(r.bottomRight)),
    ];
    if (!_same(local, _holes)) setState(() => _holes = local);
  }

  static bool _same(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].topLeft - b[i].topLeft).distance > 0.5 || (a[i].size - b[i].size as Offset).distance > 0.5) {
        return false;
      }
    }
    return true;
  }

  /// 카드가 바뀌면 손가락을 다시 톡톡, 전투 카드면 3초 뒤 접기.
  void _onCard(GuideCard? card) {
    if (card?.key == _shownKey) return;
    _shownKey = card?.key;
    _collapse?.cancel();
    _taps++;
    _nudge = false;
    _collapsed = false;
    if (card != null && card.battle) {
      _collapse = Timer(_collapseAfter, () {
        if (mounted) setState(() => _collapsed = true);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _blocked() => setState(() {
    _taps++;
    _nudge = true;
  });

  void _ack(GuideCard card) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step = ref.watch(tutorialStepProvider);
    final id = ref.watch(guideQueueProvider);
    final card = guideCardFor(l10n, step: step, id: id);
    _onCard(card);
    final calm =
        MediaQuery.disableAnimationsOf(context) || !ref.watch(gameStateProvider.select((s) => s.settings.flash));
    // 누를 곳이 화면에 없으면(시트가 닫혀 탭 안 버튼이 안 보임 등) 막지 않는다 — 갇히지 않게.
    final block = card != null && card.block && _holes.isNotEmpty;
    final dim = card == null || card.battle ? 0.0 : (card.block ? 0.45 : 0.25);
    return Stack(
      key: _box,
      children: [
        widget.child,
        if (card != null) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DimPainter(holes: _holes, alpha: dim),
              ),
            ),
          ),
          if (block)
            Positioned.fill(
              child: _HoleBlocker(holes: _holes, onBlocked: _blocked),
            ),
          // 시스템 카드: 밝은 곳을 누르면(했다) 카드를 닫는다. 누름은 그대로 아래로 간다.
          if (!block && step == null)
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (_holes.any((h) => h.contains(e.localPosition))) ref.read(guideQueueProvider.notifier).close();
                },
              ),
            ),
          if (_holes.isNotEmpty && !_collapsed) GuideFinger(at: _holes.first, taps: _taps, calm: calm),
          GuideCardPlacer(
            card: card,
            holes: _holes,
            collapsed: _collapsed,
            nudge: _nudge,
            onAck: card.ack ? () => _ack(card) : null,
            onSkip: () => unawaited(_skip()),
            onExpand: () => setState(() => _collapsed = false),
          ),
        ],
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
    if (alpha <= 0) return;
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

/// 가리킨 곳 아래쪽에 큰 손가락 — 3번 톡톡 누르고 멈춘다([taps]가 바뀌면 다시). 동작 줄이기면 가만히.
class GuideFinger extends StatelessWidget {
  const GuideFinger({required this.at, required this.taps, required this.calm, super.key});

  final Rect at;
  final int taps;
  final bool calm;

  @override
  Widget build(BuildContext context) => Positioned(
    // 가리킨 곳 오른쪽 아래 모서리 — 글자(탭 이름 등)를 덮지 않게.
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
