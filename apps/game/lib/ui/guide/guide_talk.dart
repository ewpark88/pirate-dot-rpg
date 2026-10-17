import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/dock/home_dock.dart' show kDockHeight;
import 'package:pirate_dot/ui/hud/hp_bars.dart' show shipHpAnchor;
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';

// 가이드 v3 (S1 승인 2026-10-17): 옥토 선장(PB 초상)이 아래에서 쏙 올라와 말풍선으로 말한다 — 짧은 해요체(2줄 안팎).
// 누를 곳은 금빛 빛 테두리 + 톡톡 손가락(GuideLayer), 행동하면 초록 반응 말풍선.

/// 말풍선 자리 높이(초상 72 + 여유) — 누를 곳과 겹치는지 볼 때.
const talkHeight = 110.0;

/// 말풍선이 나오고 들어가는 시간 (모션 기준: 살짝 커지며 페이드 180~220ms, ease-out).
const talkMotion = Duration(milliseconds: 200);

/// 말풍선 아랫변 자리(아래에서 떨어진 거리): 배 체력 막대 바로 위(선원 줄·하단 글자를 가리지 않게), 없으면 도크 위.
/// 누를 곳 [hole]이 그 자리와 겹치면 누를 곳 위로 올린다.
double talkBottom(BuildContext context, Size box, Rect? hole, {required RenderBox? layer}) {
  final pad = MediaQuery.paddingOf(context);
  var bottom = kDockHeight + pad.bottom + 8;
  final anchor = shipHpAnchor.currentContext?.findRenderObject();
  if (layer != null && anchor is RenderBox && anchor.attached && anchor.hasSize) {
    final top = layer.globalToLocal(anchor.localToGlobal(Offset.zero)).dy;
    if (top > box.height * 0.4 && top < box.height) bottom = box.height - top + 6;
  }
  final zoneTop = box.height - bottom - talkHeight;
  if (hole != null && hole.bottom > zoneTop && hole.top < box.height - bottom) return box.height - hole.top + 12;
  return bottom;
}

/// 초상(원) + 말풍선(꼬리). [reaction]이면 초록 테두리. [collapsed]면 초상만(누르면 펼침).
class GuideTalkBubble extends StatelessWidget {
  const GuideTalkBubble({
    required this.text,
    this.reaction = false,
    this.collapsed = false,
    this.tapHint = false,
    this.onTap,
    this.onSkip,
    super.key,
  });

  final String text;
  final bool reaction;
  final bool collapsed;

  /// '톡 눌러 계속' 작은 글 (확인 단계).
  final bool tapHint;
  final VoidCallback? onTap;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final edge = reaction ? Skin.mint : const Color(0xFFFFC53D);
    final face = Container(
      width: collapsed ? 52 : 72,
      height: collapsed ? 52 : 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFBFE6FF),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: Skin.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        pbPortrait('octo'),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.face, size: 40),
      ),
    );
    // 홈 화면 위 층(Scaffold 밖)이라 잉크·글자 기본값을 위해 투명 Material.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        liveRegion: true,
        label: '${l10n.uiTalkName}: $text',
        child: GestureDetector(
          key: Key(collapsed ? 'talk.mini' : 'talk'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: collapsed
              ? face
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      face,
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                          decoration: BoxDecoration(
                            color: Skin.card,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                              bottomRight: Radius.circular(18),
                              bottomLeft: Radius.circular(4),
                            ),
                            border: Border.all(color: edge, width: 2.5),
                            boxShadow: Skin.shadow,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(text, key: const Key('talk.text'), maxLines: 3, style: Skin.text(18)),
                              if (tapHint || onSkip != null)
                                Wrap(
                                  spacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (tapHint)
                                      Text(
                                        l10n.uiTalkTapNext,
                                        key: const Key('talk.next'),
                                        style: Skin.text(13, color: Skin.sub),
                                      ),
                                    if (onSkip != null)
                                      // 건너뛰기: 작은 글자, 누름 영역 48dp.
                                      InkWell(
                                        key: const Key('guide.skip'),
                                        onTap: onSkip,
                                        borderRadius: BorderRadius.circular(12),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
                                          child: Center(
                                            child: Text(l10n.uiGuideSkip, style: Skin.text(13, color: Skin.sub)),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// '안내를 끌까요? [계속 보기] [끄기]' — 끄기면 true.
class GuideSkipDialog extends StatelessWidget {
  const GuideSkipDialog({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('guide.skip.dialog'),
    insetPadding: popupInset,
    constraints: popupConstraints(context),
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

/// 한 마디 (스토리보드·운영자용 덧씌우기 — 흐름 안내는 GuideLayer가 직접 고른다).
typedef GuideLine = ({String text, String? spot, bool reaction, bool dim});

/// 덧씌울 말 (null = 없음). 스토리보드 테스트와 운영자가 넣는다.
final guideLineProvider = NotifierProvider<GuideLineNotifier, GuideLine?>(GuideLineNotifier.new);

class GuideLineNotifier extends Notifier<GuideLine?> {
  @override
  GuideLine? build() => null;

  // 말을 바꾸는 동작이라 메서드로 둔다.
  // ignore: use_setters_to_change_properties
  void say(GuideLine? line) => state = line;
}
