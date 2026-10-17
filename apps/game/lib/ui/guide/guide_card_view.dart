import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/dock/home_dock.dart' show kDockHeight;
import 'package:pirate_dot/ui/guide/guide_cards.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';

// 가이드 v2 카드 생김새 (스펙 2·3절): 제목 22 · 왜 18 · 버튼 56dp, 흰 카드 + 금 테두리. 누를 곳을 가리지 않게 그 위나 아래에 놓는다.

/// 카드 최대 폭(태블릿 가운데).
const _maxWidth = 440.0;

/// 가리킨 곳과 카드 사이.
const _gap = 16.0;

/// 카드를 놓는다: 가리킨 곳이 아래쪽이면 그 위, 위쪽이면 그 아래, 없으면 도크 위. 접힌 전투 카드는 오른쪽 위 알약.
class GuideCardPlacer extends StatelessWidget {
  const GuideCardPlacer({
    required this.card,
    required this.holes,
    required this.collapsed,
    required this.nudge,
    required this.onSkip,
    required this.onExpand,
    this.onAck,
    super.key,
  });

  final GuideCard card;
  final List<Rect> holes;
  final bool collapsed;
  final bool nudge;
  final VoidCallback? onAck;
  final VoidCallback onSkip;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    // 이 층은 Scaffold 밖(홈 화면 위)이라 잉크·글자 기본값을 위해 투명 Material을 깐다.
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: LayoutBuilder(
          builder: (context, box) {
            if (collapsed) {
              return Stack(
                children: [
                  Positioned(
                    right: 12,
                    top: pad.top + 104,
                    child: _Pill(card: card, onTap: onExpand),
                  ),
                ],
              );
            }
            final view = Align(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GuideCardView(card: card, nudge: nudge, onAck: onAck, onSkip: onSkip),
                ),
              ),
            );
            final h = box.maxHeight;
            // 전투 카드(피버·보스)는 늘 도크 위 — 화면 가운데·위쪽 연출('FEVER!'·보스 이름표)을 가리지 않게.
            final hole = holes.isEmpty || card.battle ? null : holes.first;
            // 위에 놓을 자리가 넉넉하면(가리킨 곳이 화면 아래쪽) 위, 아니면 아래.
            final above = hole != null && hole.center.dy > h / 2;
            return Stack(
              children: [
                if (hole == null)
                  Positioned(left: 0, right: 0, bottom: kDockHeight + pad.bottom + 24, child: view)
                else if (above)
                  Positioned(left: 0, right: 0, bottom: h - hole.top + _gap, child: view)
                else
                  Positioned(left: 0, right: 0, top: hole.bottom + _gap, child: view),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 카드 본문: 아이콘 · 제목 · 건너뛰기 / 왜 한 줄 / ('여기를 눌러요') / [알겠어요].
class GuideCardView extends StatelessWidget {
  const GuideCardView({required this.card, required this.nudge, required this.onSkip, this.onAck, super.key});

  final GuideCard card;
  final bool nudge;
  final VoidCallback? onAck;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('guide.card'),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        decoration: BoxDecoration(
          color: Skin.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Skin.goldBottom, width: 3),
          boxShadow: Skin.shadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(card.icon, size: 34, color: Skin.primaryEdge),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(card.title, key: const Key('guide.title'), style: Skin.text(22)),
                  ),
                ),
                // 건너뛰기: 작은 글자, 누름 영역 48dp.
                Semantics(
                  button: true,
                  child: InkWell(
                    key: const Key('guide.skip'),
                    onTap: onSkip,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(l10n.uiGuideSkip, style: Skin.text(14, color: Skin.sub)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                card.why,
                key: const Key('guide.why'),
                style: Skin.text(18, color: Skin.sub),
              ),
            ),
            if (nudge)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  key: const Key('guide.nudge'),
                  children: [
                    const Icon(Icons.touch_app_rounded, color: Skin.danger, size: 24),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(l10n.uiGuideTapHere, style: Skin.text(18, color: Skin.danger)),
                    ),
                  ],
                ),
              ),
            if (onAck != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: SkinButton(
                    key: const Key('guide.ok'),
                    tone: SkinTone.gold,
                    height: 56,
                    onPressed: onAck,
                    child: Text(l10n.uiGuideOk, style: Skin.text(18)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 접힌 전투 카드: 오른쪽 위 작은 알약(아이콘 + 제목) — 누르면 다시 펼친다.
class _Pill extends StatelessWidget {
  const _Pill({required this.card, required this.onTap});

  final GuideCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('guide.pill'),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Skin.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Skin.goldBottom, width: 2),
        boxShadow: Skin.shadowSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(card.icon, size: 22, color: Skin.primaryEdge),
          const SizedBox(width: 6),
          Text(card.title, style: Skin.text(16)),
          const SizedBox(width: 4),
          const Icon(Icons.help_outline_rounded, size: 20, color: Skin.sub),
        ],
      ),
    ),
  );
}

/// '안내를 끌까요? [계속 보기] [끄기]' — 끄기면 true.
class GuideSkipDialog extends StatelessWidget {
  const GuideSkipDialog({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('guide.skip.dialog'),
    title: Text(l10n.uiGuideSkipAsk, style: Skin.text(20)),
    actions: [
      SkinButton(
        key: const Key('guide.skip.keep'),
        tone: SkinTone.gold,
        onPressed: () => Navigator.of(context).pop(false),
        child: Text(l10n.uiGuideSkipKeep, style: Skin.text(16)),
      ),
      SkinButton(
        key: const Key('guide.skip.off'),
        tone: SkinTone.plain,
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(l10n.uiGuideSkipOff, style: Skin.text(16)),
      ),
    ],
  );
}
