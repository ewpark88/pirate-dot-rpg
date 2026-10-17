import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 창·시트 최대 폭(dp) — 태블릿에서 가운데에 알맞은 크기로.
const _dialogMaxWidth = 480.0;
const _sheetMaxWidth = 640.0;

/// 창 폭 (팝업 기준, S1 2026-10-17 '창이 작고 여백이 많다'): 폰은 화면 폭의 85%, 태블릿은 480dp 상한.
double popupWidth(BuildContext context) => math.min(MediaQuery.sizeOf(context).width * 0.85, _dialogMaxWidth);

/// 창 크기: 폭을 [popupWidth]로 고정한다. Dialog의 `constraints`나 창 안 ConstrainedBox에 쓴다.
BoxConstraints popupConstraints(BuildContext context) => BoxConstraints.tightFor(width: popupWidth(context));

/// 창 바깥 여백 — 85% 폭이 들어가게 좌우는 좁게.
const popupInset = EdgeInsets.symmetric(horizontal: 8, vertical: 16);

/// 창 열고 닫기 (모션 기준: 살짝 커지며 페이드 200ms ease-out, 닫기 180ms). 모든 대화 창은 이것으로 띄운다.
Future<T?> showSkinDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierColor: barrierColor ?? Colors.black54,
  animationStyle: const AnimationStyle(
    duration: Duration(milliseconds: 200),
    reverseDuration: Duration(milliseconds: 180),
    curve: Curves.easeOut,
  ),
  builder: (context) => SkinPopIn(child: builder(context)),
);

/// 창 (스킨 r1): 둥근 흰 판 안에 [icon] · 제목 · 내용 · 오른쪽 아래 버튼 줄.
class PixelDialog extends StatelessWidget {
  const PixelDialog({required this.content, this.title, this.icon, this.actions = const [], super.key});

  final Widget? icon;
  final String? title;
  final Widget content;

  /// 보통 `PixelButton`들. 오른쪽 정렬, 좁으면 다음 줄로.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: popupInset,
    constraints: popupConstraints(context),
    child: PixelFrame(
      padding: 9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (icon case final i?) ...[Center(child: i), const SizedBox(height: 8)],
          if (title case final t?) ...[
            Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
          ],
          // 본문 16sp (팝업 기준).
          Flexible(
            child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 16), child: content),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    ),
  );
}

/// 창·시트가 열릴 때 92% → 100% + 흐림 → 선명 (스킨 r2 ④). 자기를 띄운 경로(route)의 열림 애니메이션을 따른다.
class SkinPopIn extends StatelessWidget {
  const SkinPopIn({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.animation;
    if (route == null) return child;
    final a = CurvedAnimation(parent: route, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(a),
      child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(a), child: child),
    );
  }
}

/// 하단 시트 틀 (스킨 r1): 둥근 흰 판. [showPixelSheet]로 띄운다.
class PixelSheet extends StatelessWidget {
  const PixelSheet({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SkinPopIn(child: PixelFrame(padding: 7, child: child));
}

/// 도트 하단 시트를 띄운다. 높이는 화면의 [maxHeight] 비율까지 (전장을 가리지 않게).
Future<T?> showPixelSheet<T>(BuildContext context, {required WidgetBuilder builder, double maxHeight = 0.7}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * maxHeight, maxWidth: _sheetMaxWidth),
      builder: (context) => PixelSheet(child: builder(context)),
    );

/// 빨간 점 지름(dp).
const _dotSize = 12.0;

/// 빨간 점 (스킨 r1: 흰 테두리 동그란 점): [child] 오른쪽 위. 지금 눌러서 이득일 때만 쓴다 (설계서 4.9).
class PixelDot extends StatelessWidget {
  const PixelDot({required this.child, this.show = true, this.dotKey, this.count, this.isNew = false, super.key});

  final Widget child;
  final bool show;

  /// 점 자체의 키 (보일 때만 있다 — 테스트용).
  final Key? dotKey;

  /// 숫자 뱃지 (스킨 r2 결정: 선원·퀘스트만). null이면 점.
  final int? count;

  /// 'NEW' 알약.
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    final label = isNew ? 'NEW' : (count == null ? null : (count! > 9 ? '9+' : '$count'));
    // 스킨 r2 뱃지 통일 (② — 점·숫자·NEW 모두 같은 빨간 알약, 같은 자리, 처음 나타날 때 한 번 통).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: label == null ? -3 : -6,
          top: label == null ? -3 : -6,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              key: dotKey,
              constraints: BoxConstraints(
                minWidth: label == null ? _dotSize : 20,
                minHeight: label == null ? _dotSize : 20,
              ),
              padding: EdgeInsets.symmetric(horizontal: label != null && label.length > 1 ? 5 : 0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE23A50), Color(0xFFC0122E)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x40F0384F), blurRadius: 4, offset: Offset(0, 1))],
              ),
              child: label == null
                  ? null
                  : Text(
                      label,
                      style: Skin.text(11, color: Colors.white, weight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
