import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';

// 선원 줄 오른쪽 버튼이 무엇인지 한눈에 (사용자 질문 2026-10-16 "동그라미로 떠 있는 슬롯은 뭐냐", "새로고침 버튼 같은 건 뭐냐").
// 궁극기: 그림(선장 초상)은 렌더, UI는 '궁극기' 꼬리표·함성 원형 게이지 + %·가득 차면 금빛 맥박·'탭!'·발동 띠·처음 말풍선.
// 보스 도전: 새로고침 화살표 대신 해역 보스 초상 + '보스 도전!' 빨강·금 버튼, 칼 교차, 맥박, 처음 말풍선.

/// 이번 실행에서 안내를 보인 횟수 (탭! 손가락 3회 · 말풍선 1회). 세이브에는 남기지 않는다.
final hudHintsProvider = NotifierProvider<HudHints, Map<String, int>>(HudHints.new);

class HudHints extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  /// 세이브에 남기는 '처음 1회' 안내 (Settings.hints · MarkHint — 앱을 다시 켜도 다시 안 뜬다).
  static const persistent = {'ult.bubble', 'boss.bubble', 'rebirth.bubble', 'rebirth.seen'};

  /// 본 횟수: 이번 실행 수, 세이브에 본 기록이 있으면 최소 1.
  int count(String id) {
    final n = state[id] ?? 0;
    final saved = persistent.contains(id) && ref.read(gameStateProvider).settings.hints.contains(id);
    return saved && n == 0 ? 1 : n;
  }

  void shown(String id) {
    state = {...state, id: (state[id] ?? 0) + 1};
    if (persistent.contains(id)) ref.read(commandSinkProvider).send(MarkHint(id));
  }

  /// 켜짐/꺼짐 표시 (말풍선이 지금 떠 있는지 — 한 번에 하나만).
  void set(String id, {required bool on}) => state = {...state, id: on ? 1 : 0};
}

/// 궁극기 표시 (투명 버튼 아래에 그림만 — 누름은 기존 _UltimateButton). [rect] = 렌더 궁극기 원 자리(전장 상자 dp).
class UltimateHud extends ConsumerStatefulWidget {
  const UltimateHud({required this.rect, super.key});

  final Rect rect;

  @override
  ConsumerState<UltimateHud> createState() => _UltimateHudState();
}

class _UltimateHudState extends ConsumerState<UltimateHud> {
  StreamSubscription<RecordedTick>? _sub;
  Timer? _bannerTimer;
  Timer? _bubbleTimer;
  String? _banner;
  bool _wasFull = false;

  /// 이번 '가득'에서 탭! 손가락을 보일지 (처음 3회).
  bool _tapHint = false;
  bool _bubble = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is UltimateCast && mounted) _showBanner(e);
      }
    });
  }

  void _showBanner(UltimateCast e) {
    final l10n = AppLocalizations.of(context);
    final crew = ref.read(tablesProvider).crews.crews.where((c) => c.id == e.crewId).firstOrNull;
    final name = crew == null ? '' : shortCrewName(l10n, crew);
    _bannerTimer?.cancel();
    setState(() {
      _banner = l10n.uiUltBanner(name, ultimateName(l10n, e.ultimateId));
      _tapHint = false;
    });
    _hideBubble();
    _bannerTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  void _hideBubble() {
    if (!mounted) return;
    setState(() => _bubble = false);
    ref.read(hudHintsProvider.notifier).set('ult.on', on: false);
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _bannerTimer?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final max = ref.watch(tablesProvider).skills.rageMax;
    final (rage, tick, flashOn) = ref.watch(
      gameStateProvider.select((s) => (((s.progress.rage / max) * 100).floor(), s.battle?.tick ?? 0, s.settings.flash)),
    );
    final full = rage >= 100;
    if (full && !_wasFull) {
      // 가득 찬 순간: 처음 3회만 '탭!', 처음 1회만 말풍선.
      final hints = ref.read(hudHintsProvider.notifier);
      _tapHint = hints.count('ult.tap') < 3;
      _bubble = hints.count('ult.bubble') < 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_tapHint) hints.shown('ult.tap');
        if (_bubble) {
          hints
            ..shown('ult.bubble')
            ..set('ult.on', on: true);
        }
      });
      if (_bubble) {
        _bubbleTimer?.cancel();
        _bubbleTimer = Timer(const Duration(seconds: 4), _hideBubble);
      }
    }
    if (!full) _tapHint = false;
    _wasFull = full;
    final calm = MediaQuery.disableAnimationsOf(context);
    final pulse = full && flashOn && !calm ? 0.5 + 0.5 * math.sin(tick / 2.5) : 0.0;
    final r = widget.rect;
    final ring = r.inflate(5);
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 함성 원형 게이지 (+ 가득 차면 금빛 맥박).
          Positioned.fromRect(
            rect: ring,
            child: CustomPaint(key: const Key('hud.ult.ring'), painter: _RagePainter(rage / 100, pulse)),
          ),
          // '궁극기' 꼬리표 (원 위).
          Positioned(
            left: ring.center.dx - 40,
            width: 80,
            top: ring.top - 18,
            child: Center(
              child: Container(
                key: const Key('hud.ult.tag'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: full ? Skin.goldBottom : Skin.ink.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(l10n.uiUltTag, style: Skin.text(11, color: full ? Skin.goldInk : Colors.white)),
              ),
            ),
          ),
          // % (원 아래 오른쪽).
          Positioned(
            left: ring.center.dx - 22,
            width: 44,
            top: ring.bottom - 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Skin.ink.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$rage%',
                key: const Key('hud.ult.percent'),
                style: Skin.text(11, color: Colors.white),
              ),
            ),
          ),
          // '탭!' 손가락 (가득 찼을 때, 처음 3회).
          if (full && _tapHint)
            Positioned(
              left: ring.left - 44,
              top: ring.center.dy - 14,
              child: Row(
                key: const Key('hud.ult.tap'),
                children: [
                  Text(l10n.uiUltTap, style: Skin.text(16, color: const Color(0xFFFFD84A))),
                  Transform.translate(
                    offset: Offset(4 * pulse, 0),
                    child: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          // 처음 1회 말풍선.
          if (full && _bubble)
            Positioned(
              right: 4,
              bottom: (r.top - 26).clamp(0, double.infinity) > 0 ? null : 0,
              top: r.top - 74,
              child: HudBubble(key: const Key('hud.ult.bubble'), text: l10n.uiUltHint),
            ),
          // 발동 띠: 선장 · 궁극기 이름.
          if (_banner != null)
            Positioned(
              right: 4,
              top: r.top - 48,
              child: Container(
                key: const Key('hud.ult.banner'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD84A), Color(0xFFFF8A2A)]),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1B2A4A), width: 2),
                ),
                child: Text(_banner!, style: Skin.text(15, color: const Color(0xFF1B2A4A))),
              ),
            ),
        ],
      ),
    );
  }
}

String ultimateName(AppLocalizations l, String id) => switch (id) {
  'ult_cannon_rain' => l.uiUltCannonRain,
  'ult_volley' => l.uiUltVolley,
  'ult_harpoon_storm' => l.uiUltHarpoonStorm,
  'ult_tidal_wave' => l.uiUltTidalWave,
  'ult_kraken' => l.uiUltKraken,
  'ult_thunderstorm' => l.uiUltThunderstorm,
  'ult_ghost_charge' => l.uiUltGhostCharge,
  _ => l.uiUltGreatWave,
};

class _RagePainter extends CustomPainter {
  _RagePainter(this.value, this.pulse);

  final double value;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (value >= 1) {
      canvas.drawCircle(
        c,
        r + 2 + 4 * pulse,
        Paint()
          ..color = const Color(0xFFFFD84A).withValues(alpha: 0.35 + 0.35 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    final rect = Rect.fromCircle(center: c, radius: r - 2);
    canvas
      ..drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0x661B2A4A),
      )
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = value >= 1 ? const Color(0xFFFFD84A) : const Color(0xFFFF8A2A),
      );
  }

  @override
  bool shouldRepaint(_RagePainter old) => old.value != value || old.pulse != pulse;
}

class HudBubble extends StatelessWidget {
  const HudBubble({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 220),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: Skin.shadow,
      border: Border.all(color: Skin.goldBottom, width: 2),
    ),
    child: Text(text, style: Skin.text(13)),
  );
}
