import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/hd/hd_opening.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show BossPortrait;
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/story/story_data.dart';

// 오프닝 컷 (사용자 2026-10-17 '세계관 오프닝 4~5컷, 아래 [건너뛰기]'): 화면 가득 그림 + 아래 글 판, 톡 하면 다음 컷,
// 오른쪽 위 [건너뛰기]. 그림은 지금 있는 것(옥토 카드·배·보스 초상·선원)으로 — S3 오프닝 그림이 오면 바꾼다.

class OpeningScreen extends ConsumerStatefulWidget {
  const OpeningScreen({super.key});

  @override
  ConsumerState<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends ConsumerState<OpeningScreen> {
  int _i = 0;
  Timer? _auto;

  /// 컷이 바뀔 때마다 표의 한 컷 시간 뒤 저절로 다음(누르면 바로).
  void _schedule(int count, Duration cutFor) {
    _auto?.cancel();
    _auto = Timer(cutFor, () {
      if (!mounted) return;
      if (_i + 1 < count) {
        setState(() => _i++);
        _schedule(count, cutFor);
      } else {
        unawaited(Navigator.of(context).maybePop());
      }
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final script = ref.watch(storyScriptProvider);
    final cuts = script.opening(l10n);
    final cut = cuts[_i];
    _auto ?? _schedule(cuts.length, script.cutFor);
    void next() {
      if (_i + 1 < cuts.length) {
        setState(() => _i++);
        _schedule(cuts.length, script.cutFor);
      } else {
        unawaited(Navigator.of(context).maybePop());
      }
    }

    return Scaffold(
      backgroundColor: Skin.night,
      body: GestureDetector(
        key: const Key('opening'),
        behavior: HitTestBehavior.opaque,
        onTap: next,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 컷이 바뀌면 그림이 살짝 커지며 나타난다(모션 기준 220ms).
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(a), child: child),
              ),
              child: KeyedSubtree(key: ValueKey(_i), child: _CutArt(cut.art)),
            ),
            // 아래 글 판 (연보라 + 외곽선) + 컷 점.
            Positioned(
              left: 16,
              right: 16,
              bottom: 32 + MediaQuery.paddingOf(context).bottom,
              child: Container(
                key: Key('opening.cut.$_i'),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: Skin.inset(radius: Skin.radiusCard),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cut.lines.join('\n'), textAlign: TextAlign.center, style: Skin.bold(18)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var k = 0; k < cuts.length; k++)
                          Container(
                            width: k == _i ? 18 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: k == _i ? Skin.goldBottom : Skin.plainEdge,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.uiStoryTapNext, style: Skin.text(13, color: Skin.sub)),
                  ],
                ),
              ),
            ),
            // 오른쪽 위 [건너뛰기] (누름 48dp).
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 12,
              child: GestureDetector(
                key: const Key('opening.skip'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: Center(child: OutlineText(l10n.uiStorySkip)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 컷 그림: S3 HD 배경(HdOpeningBackdrop) 위에 컷마다 얹는 그림 — 0·4는 배경만(지도·출항 배가 그림 안).
class _CutArt extends StatelessWidget {
  const _CutArt(this.art);

  final int art;

  @override
  Widget build(BuildContext context) {
    final calm = MediaQuery.disableAnimationsOf(context);
    final front = switch (art) {
      // 낡은 배(화면 62% 높이) 위에 옥토.
      1 => Align(
        alignment: const Alignment(0, 0.02),
        child: Image.asset(pbCharacter('octo'), height: 150, fit: BoxFit.contain),
      ),
      // 촉수 앞에 해역 보스 초상 하나.
      2 => const Align(
        alignment: Alignment(0, 0.2),
        child: BossPortrait(bossId: 'kraken', size: 96),
      ),
      // 노을 갑판 위 동료들.
      3 => Align(
        alignment: const Alignment(0, 0.1),
        child: Wrap(
          spacing: 8,
          children: [
            for (final id in const ['octo', 'bones', 'pang', 'manta'])
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Skin.outline, width: 2.5),
                ),
                child: ClipOval(child: Image.asset(pbPortrait(id), width: 72, height: 72, fit: BoxFit.cover)),
              ),
          ],
        ),
      ),
      _ => const SizedBox.shrink(),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        HdOpeningBackdrop(cut: art.clamp(0, 4), animate: !calm),
        front,
      ],
    );
  }
}
