import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show BossPortrait, bossName;
import 'package:pirate_dot/ui/guide/guide_cards.dart' show GuideHold, guideHoldProvider;
import 'package:pirate_dot/ui/guide/guide_talk.dart' show talkBottom;
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/story/opening_screen.dart';
import 'package:pirate_dot/ui/story/story_data.dart';

// 시나리오 층 (사용자 2026-10-17): ① 처음 시작하면 오프닝 컷(한 번) ② 보스가 처음 나오면 아래쪽 작은 대화창 —
// 보스·옥토 초상 + 리본 이름표 + 글, 2.8초마다 저절로 넘어가고 톡 하면 바로 다음, [건너뛰기]. 전투는 그동안 계속(누름은
// 대화창 밖으로 통과). 가이드 말과 겹치지 않게 대화 동안 가이드를 접는다. 본 기록은 세이브 hints(story.*).

class StoryLayer extends ConsumerStatefulWidget {
  const StoryLayer({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StoryLayer> createState() => _StoryLayerState();
}

class _StoryLayerState extends ConsumerState<StoryLayer> {
  final GlobalKey _box = GlobalKey();
  StreamSubscription<RecordedTick>? _sub;
  Timer? _next;

  /// 지금 대화 (보스 id, 줄들, 몇째 줄). null이면 없음.
  (String, List<StoryLine>, int)? _talk;

  // dispose에서 ref를 쓸 수 없어 미리 잡아 둔다.
  late final GuideHold _hold;

  @override
  void initState() {
    super.initState();
    _hold = ref.read(guideHoldProvider.notifier);
    if (!ref.read(storyEnabledProvider)) return;
    final st = ref.read(gameStateProvider);
    // 오프닝은 막 시작한 게임에서만(최고 스테이지 1 이하) — 이미 하던 세이브(업데이트)엔 띄우지 않는다.
    if (!st.settings.hints.contains(storyOpeningHint) && st.progress.bestStage <= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_opening()));
    }
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      if (tick.frame.fastSail != null || tick.frame.bounty != null) return;
      for (final e in tick.events) {
        if (e is BossSpawned) _bossIntro(e.kind);
      }
    });
  }

  Future<void> _opening() async {
    if (!mounted) return;
    ref.read(commandSinkProvider).send(const MarkHint(storyOpeningHint));
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const OpeningScreen(),
        transitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _bossIntro(String bossId) {
    if (!mounted || _talk != null) return;
    final hint = storyBossHint(bossId);
    if (ref.read(gameStateProvider).settings.hints.contains(hint)) return;
    final lines = ref.read(storyScriptProvider).bossIntro(AppLocalizations.of(context), bossId);
    if (lines.isEmpty) return;
    ref.read(commandSinkProvider).send(MarkHint(hint));
    _hold.hold(storyLineFor * lines.length);
    setState(() => _talk = (bossId, lines, 0));
    _schedule();
  }

  void _schedule() {
    _next?.cancel();
    _next = Timer(storyLineFor, _advance);
  }

  void _advance() {
    final t = _talk;
    if (!mounted || t == null) return;
    final (id, lines, i) = t;
    if (i + 1 >= lines.length) {
      _close();
    } else {
      setState(() => _talk = (id, lines, i + 1));
      _schedule();
    }
  }

  void _close() {
    _next?.cancel();
    if (mounted) setState(() => _talk = null);
  }

  @override
  void dispose() {
    _hold.release();
    _next?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _talk;
    return Stack(
      key: _box,
      children: [
        widget.child,
        if (t != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                final layer = _box.currentContext?.findRenderObject() as RenderBox?;
                final bottom = talkBottom(context, box.biggest, null, layer: layer);
                final (bossId, lines, i) = t;
                return Stack(
                  children: [
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: bottom,
                      child: _DialogueBox(
                        bossId: bossId,
                        line: lines[i],
                        onTap: _advance,
                        onSkip: _close,
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

/// 아래쪽 작은 대화창: 초상(보스는 오른쪽, 옥토는 왼쪽) + 리본 이름표 + 글 + [건너뛰기].
class _DialogueBox extends ConsumerWidget {
  const _DialogueBox({required this.bossId, required this.line, required this.onTap, required this.onSkip});

  final String bossId;
  final StoryLine line;
  final VoidCallback onTap;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boss = line.who == Speaker.boss;
    final face = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: boss ? const Color(0xFF3A1A24) : const Color(0xFFBFE6FF),
        border: Border.all(color: Skin.outline, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: boss
          ? BossPortrait(bossId: bossId)
          : Image.asset(pbPortrait('octo'), fit: BoxFit.cover, width: 64, height: 64),
    );
    final name = boss ? bossName(l10n, ref, bossId) : l10n.uiTalkName;
    final body = Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
        decoration: Skin.inset(fill: boss ? const Color(0xFFFFE3E8) : Skin.insetFill, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.text, key: const Key('story.text'), maxLines: 3, style: Skin.bold(16)),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                key: const Key('story.skip'),
                behavior: HitTestBehavior.opaque,
                onTap: onSkip,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
                  child: Center(
                    child: Text(l10n.uiStorySkip, style: Skin.text(13, color: Skin.sub)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        key: const Key('story.dialogue'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: boss ? [body, const SizedBox(width: 6), face] : [face, const SizedBox(width: 6), body],
              ),
            ),
            // 리본 이름표 (말하는 쪽 위).
            Positioned(
              top: 0,
              left: boss ? null : 76,
              right: boss ? 76 : null,
              child: Container(
                key: const Key('story.name'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Skin.ribbonTop, Skin.ribbonBottom],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Skin.outline, width: 2),
                ),
                child: OutlineText(name, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
