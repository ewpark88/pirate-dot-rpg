import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 알림 권한을 좋은 때에 (S1 2026-10-18, Android 13+ POST_NOTIFICATIONS): 첫 실행 즉시가 아니라 첫 복귀 보상을 받은 직후 옥토가
// '돌아오면 알려 줄까요?' — [좋아요] = 시스템 권한 창, [나중에]. 거절(나중에·시스템 거절)이면 7일 뒤 한 번만 다시. 설정 알림을
// 켤 때도 권한을 묻는다. 묻는 기록은 세이브 hints('notify.ask@yyyy-MM-dd' · 'notify.ask2' · 'notify.granted').
// 실제 권한 호출은 앱이 [notifyPermissionProvider]를 플랫폼 어댑터로 덮을 때만(없으면 묻지 않는다).

/// 시스템 권한 창을 띄우고 허락했는지 돌려준다. null = 이 빌드엔 알림 없음(묻지 않음).
final notifyPermissionProvider = Provider<Future<bool> Function()?>((_) => null);

const notifyAskPrefix = 'notify.ask@';
const notifyAskAgain = 'notify.ask2';
const notifyGranted = 'notify.granted';

/// 거절 뒤 다시 묻기까지.
const notifyAskAgainAfter = Duration(days: 7);

DateTime? _firstAsked(GameState s) {
  for (final h in s.settings.hints) {
    if (h.startsWith(notifyAskPrefix)) return DateTime.tryParse(h.substring(notifyAskPrefix.length));
  }
  return null;
}

/// 지금 물어도 되나: 알림 설정이 켜져 있고, 허락 기록이 없고, 처음이거나 첫 거절 7일 뒤 한 번.
bool shouldAskNotify(GameState s, DateTime now) {
  final h = s.settings.hints;
  if (!s.settings.notifications || h.contains(notifyGranted) || h.contains(notifyAskAgain)) return false;
  final first = _firstAsked(s);
  return first == null || now.difference(first) >= notifyAskAgainAfter;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 시스템 권한 창 → 허락이면 기록.
Future<void> requestNotify(BuildContext context) async {
  final c = ProviderScope.containerOf(context, listen: false);
  final ask = c.read(notifyPermissionProvider);
  if (ask == null) return;
  if (await ask()) c.read(commandSinkProvider).send(const MarkHint(notifyGranted));
}

/// 복귀 보상을 받은 뒤: 물을 때면 옥토 창(묻는 순간 기록 — 앱이 꺼져도 다시 안 뜬다).
Future<void> maybeAskNotify(BuildContext context) async {
  final c = ProviderScope.containerOf(context, listen: false);
  if (c.read(notifyPermissionProvider) == null) return;
  final s = c.read(gameStateProvider);
  final now = c.read(clockProvider).now();
  if (!shouldAskNotify(s, now)) return;
  c.read(commandSinkProvider).send(MarkHint(_firstAsked(s) == null ? '$notifyAskPrefix${_ymd(now)}' : notifyAskAgain));
  final yes = await showSkinDialog<bool>(context, builder: (_) => const NotifyAskDialog());
  if ((yes ?? false) && context.mounted) await requestNotify(context);
}

class NotifyAskDialog extends StatelessWidget {
  const NotifyAskDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PixelDialog(
      key: const Key('notify.ask'),
      title: l10n.uiNotifyAskTitle,
      icon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFBFE6FF),
          border: Border.all(color: Skin.outline, width: 2.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          pbPortrait('octo'),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.notifications_active_rounded, size: 36),
        ),
      ),
      content: Text(l10n.uiNotifyAskBody, textAlign: TextAlign.center, style: Skin.text(16)),
      actions: [
        SkinButton(
          key: const Key('notify.later'),
          tone: SkinTone.plain,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.uiNotifyAskLater),
        ),
        SkinButton(
          key: const Key('notify.yes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.uiNotifyAskYes),
        ),
      ],
    );
  }
}
