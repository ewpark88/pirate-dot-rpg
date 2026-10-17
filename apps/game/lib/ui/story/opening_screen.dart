import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show BossPortrait;
import 'package:pirate_dot/ui/ship/ship_look.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cuts = ref.watch(storyScriptProvider).opening(l10n);
    final cut = cuts[_i];
    void next() => _i + 1 < cuts.length ? setState(() => _i++) : Navigator.of(context).maybePop();
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
                    Text(cut.text, textAlign: TextAlign.center, style: Skin.bold(18)),
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

/// 컷 그림 (임시 — 지금 있는 그림으로).
class _CutArt extends StatelessWidget {
  const _CutArt(this.art);

  final OpeningArt art;

  @override
  Widget build(BuildContext context) {
    final center = switch (art) {
      OpeningArt.sea => const Icon(Icons.map_rounded, size: 120, color: Color(0xFFFFD84A)),
      OpeningArt.octo => Image.asset(pbCharacter('octo'), height: 300, fit: BoxFit.contain),
      OpeningArt.bosses => const Wrap(
        spacing: 12,
        children: [
          BossPortrait(bossId: 'kraken', size: 110),
          BossPortrait(bossId: 'sea_croc', size: 90),
        ],
      ),
      OpeningArt.crew => Wrap(
        spacing: 8,
        children: [
          for (final id in const ['octo', 'bones', 'pang', 'manta'])
            ClipOval(child: Image.asset(pbPortrait(id), width: 72, height: 72, fit: BoxFit.cover)),
        ],
      ),
      OpeningArt.sail => const ShipLookPreview(size: 200),
    };
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B2A5A), Color(0xFF2E6FB0), Color(0xFF123B6B)],
        ),
      ),
      child: Align(alignment: const Alignment(0, -0.25), child: center),
    );
  }
}
