import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart' show guidesEnabledProvider;
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/shop/shop_data.dart';
import 'package:pirate_dot/ui/shop/shop_sheet.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 맛보기 (사용자 2026-10-17, 경제 S2 meta.trials · ClaimTrial): 받을 수 있게 되면 큰 카드 팝업(체험 전/후 한 줄 ·
// [무료로 써 보기] · [나중에]). 체험 중 남은 시간은 순풍 배지·자동 강화 칩(크게)이 보여 준다. 끝나면 '광고로 10분 더'
// (+ 상점이 열려 있으면 '영구로 갖기'). [나중에]는 이번 실행에서만 다시 묻지 않는다. 한 실행에 권하기 1번, 조용한 45초 뒤. 시험에선 [trialsEnabledProvider]로 끈다.

/// 받을 수 있는 맛보기(경제 trialsReady와 같은 조건 — game_core가 export하기 전 임시 어댑터, S2 요청).
List<String> trialsReadyUi(GameState s, GameTables t) {
  final m = t.meta.raw;
  if (!m.has('trials')) return const [];
  final p = s.progress;
  return [
    for (final k in m.obj('trials').raw.keys)
      if (!p.trialsUsed.contains(k) &&
          p.bestStage >= (m.obj('trials').obj(k).intOrNull('atStage') ?? 0) &&
          p.bossFails >= (m.obj('trials').obj(k).intOrNull('afterBossFails') ?? 0))
        k,
  ];
}

/// 맛보기 팝업을 켤지(안내를 끄면 같이 꺼짐) — UI 시험은 끈다(샘플이 조건을 넘어 모든 화면에 뜨기 때문, 맛보기 시험만 켠다).
final trialsEnabledProvider = Provider<bool>((ref) => ref.watch(guidesEnabledProvider));

/// 이번 실행에서 이미 물은 맛보기 — 게이트가 다시 만들어져도 남게(앱 전체 한 벌).
final trialAskedProvider = Provider<Set<String>>((_) => <String>{});

/// 체험이 끝났는지 볼 간격.
const _check = Duration(seconds: 1);

/// 권하기 전 조용한 시간(초) — 앱 시작·다른 창이 닫힌 뒤 이만큼 아무 창 없이 지나야 권한다(S1 실기기 ③: 켜자마자 창 4개).
const trialQuietSec = 45;

class TrialGate extends ConsumerStatefulWidget {
  const TrialGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TrialGate> createState() => _TrialGateState();
}

class _TrialGateState extends ConsumerState<TrialGate> {
  Timer? _tick;
  final _was = <String, bool>{};
  bool _open = false;

  /// 아무 창 없이 지난 초.
  int _quiet = 0;

  @override
  void initState() {
    super.initState();
    if (!ref.read(trialsEnabledProvider)) return;
    _tick = Timer.periodic(_check, (_) => _poll());
  }

  Duration _left(GameState s, String kind) {
    final now = ref.read(clockProvider).now();
    return kind == 'speed' ? tailwindRemaining(s, now) : autoUpgradeRemaining(s, now);
  }

  Future<void> _poll() async {
    // 다른 창·시트(오프라인 보상·퀘스트 등)가 떠 있으면 기다린다 — 겹쳐 뜨지 않게. 닫힌 뒤에도 조용한 시간을 센다.
    if (!mounted) return;
    if (_open || !(ModalRoute.of(context)?.isCurrent ?? true)) {
      _quiet = 0;
      return;
    }
    _quiet++;
    final s = ref.read(gameStateProvider);
    final t = ref.read(tablesProvider);
    // 끝난 체험: 쓰던 버프가 0이 되는 순간 한 번.
    for (final kind in s.progress.trialsUsed) {
      final on = _left(s, kind) > Duration.zero;
      final was = _was[kind] ?? false;
      _was[kind] = on;
      if (was && !on) return _show(TrialEndDialog(kind: kind));
    }
    // 한 실행에 하나만 — 두 번째 체험은 다음 실행에서(조건이 맞는 순간).
    final asked = ref.read(trialAskedProvider);
    if (asked.isNotEmpty || _quiet < trialQuietSec) return;
    final ready = trialsReadyUi(s, t).firstOrNull;
    if (ready != null) {
      asked.add(ready);
      await _show(TrialOfferDialog(kind: ready));
    }
  }

  Future<void> _show(Widget dialog) async {
    _open = true;
    await showSkinDialog<void>(context, builder: (_) => dialog);
    _open = false;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 체험 권하기: 큰 아이콘 칸 · 전/후 한 줄 · [무료로 써 보기] · [나중에].
class TrialOfferDialog extends ConsumerWidget {
  const TrialOfferDialog({required this.kind, super.key});

  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final speed = kind == 'speed';
    return PixelDialog(
      key: Key('trial.offer.$kind'),
      title: speed ? l10n.uiTrialSpeedTitle : l10n.uiTrialAutoTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconCell(
            color: speed ? partCellColors[0] : partCellColors[2],
            size: 88,
            child: SkinIcon(speed ? UiSprites.tailwind : UiSprites.rebirth, size: 60),
          ),
          const SizedBox(height: 10),
          Text(
            speed ? l10n.uiTrialSpeedCompare : l10n.uiTrialAutoCompare,
            textAlign: TextAlign.center,
            style: Skin.bold(17),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SkinButton(
              key: const Key('trial.try'),
              tone: SkinTone.gold,
              height: 56,
              onPressed: () {
                ref.read(commandSinkProvider).send(ClaimTrial(kind));
                Navigator.of(context).pop();
              },
              child: Text(l10n.uiTrialTry),
            ),
          ),
          TextButton(
            key: const Key('trial.later'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.uiTrialLater, style: Skin.text(14, color: Skin.sub)),
          ),
        ],
      ),
    );
  }
}

/// 체험 끝: '광고 보고 10분 더' (+ 상점이 열려 있으면 '영구로 갖기').
class TrialEndDialog extends ConsumerWidget {
  const TrialEndDialog({required this.kind, super.key});

  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final placement = kind == 'speed' ? AdPlacement.tailwind : AdPlacement.autoUpgrade;
    return PixelDialog(
      key: Key('trial.end.$kind'),
      title: l10n.uiTrialEndTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.uiTrialEndAsk, textAlign: TextAlign.center, style: Skin.text(16)),
          const SizedBox(height: 12),
          if (ref.watch(adOfferProvider(placement)))
            SizedBox(
              width: double.infinity,
              child: SkinButton(
                key: const Key('trial.ad'),
                tone: SkinTone.gold,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(watchAd(ref, placement));
                },
                child: Text(l10n.uiTrialAdMore),
              ),
            ),
          if (ref.watch(shopOpenProvider)) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SkinButton(
                key: const Key('trial.buy'),
                tone: SkinTone.plain,
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(showShop(context));
                },
                child: Text(l10n.uiTrialBuy),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
