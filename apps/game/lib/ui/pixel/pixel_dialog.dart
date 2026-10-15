import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';

/// 창·시트 최대 폭(dp) — 태블릿에서 가운데에 알맞은 크기로.
const _dialogMaxWidth = 480.0;
const _sheetMaxWidth = 640.0;

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
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    // 태블릿에서 창이 화면 끝까지 늘어나지 않게.
    constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
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
          Flexible(child: content),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    ),
  );
}

/// 하단 시트 틀 (스킨 r1): 둥근 흰 판. [showPixelSheet]로 띄운다.
class PixelSheet extends StatelessWidget {
  const PixelSheet({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => PixelFrame(padding: 7, child: child);
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
  const PixelDot({required this.child, this.show = true, this.dotKey, super.key});

  final Widget child;
  final bool show;

  /// 점 자체의 키 (보일 때만 있다 — 테스트용).
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -3,
          top: -3,
          child: DecoratedBox(
            key: dotKey,
            decoration: BoxDecoration(
              color: PixelPalette.danger,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const SizedBox.square(dimension: _dotSize),
          ),
        ),
      ],
    );
  }
}
