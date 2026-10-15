import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/proto/proto_painter.dart';
import 'package:pirate_dot/proto/proto_sim.dart';
import 'package:pirate_dot/proto/proto_sprites.dart';

/// 탑다운 전투 시험판 화면(세로 전체). `--dart-define=PROTO=true` 빌드의 첫 화면(main.dart).
/// 시뮬은 고정 1/60초 걸음, 그리기는 화면 폭 180도트 × 물리 픽셀 정수배(도트 선명).
class ProtoScreen extends StatefulWidget {
  const ProtoScreen({this.seed = 1, super.key});

  final int seed;

  @override
  State<ProtoScreen> createState() => _ProtoScreenState();
}

class _ProtoScreenState extends State<ProtoScreen> with SingleTickerProviderStateMixin {
  static const _viewWidth = 180.0;
  static const double _dt = 1 / 60;

  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  ProtoSim? _sim;
  ProtoAtlas? _atlas;
  Duration _last = Duration.zero;
  double _acc = 0;
  int _round = 0;

  @override
  void initState() {
    super.initState();
    unawaited(
      ProtoAtlas.build().then((a) {
        if (mounted) setState(() => _atlas = a);
      }),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final sim = _sim;
    if (sim == null) return;
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    _acc += dt.clamp(0, 0.1);
    var steps = 0;
    while (_acc >= _dt && steps < 4) {
      sim.step(_dt);
      _acc -= _dt;
      steps++;
    }
    _repaint.value++;
    if (sim.over) {
      _ticker.stop();
      setState(() {});
    }
  }

  void _start(Size physical) {
    final k = math.max(1, (physical.width / _viewWidth).floor());
    _sim = ProtoSim(seed: widget.seed + _round, viewHeight: physical.height / k);
    _last = Duration.zero;
    _acc = 0;
    if (!_ticker.isActive) unawaited(_ticker.start());
  }

  @override
  Widget build(BuildContext context) {
    final atlas = _atlas;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF2F8CD8),
      body: LayoutBuilder(
        builder: (context, box) {
          final physical = Size(box.maxWidth * dpr, box.maxHeight * dpr);
          if (atlas == null) return const SizedBox.expand();
          if (_sim == null) _start(physical);
          final sim = _sim!;
          final k = math.max(1, (physical.width / _viewWidth).floor());
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: ProtoPainter(sim, atlas, scale: k / dpr, repaint: _repaint),
                ),
              ),
              Positioned(top: MediaQuery.paddingOf(context).top + 6, left: 0, right: 0, child: _Hud(sim, _repaint)),
              if (sim.over)
                _Result(
                  sim,
                  onAgain: () => setState(() {
                    _round++;
                    _start(physical);
                  }),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud(this.sim, this.repaint);

  final ProtoSim sim;
  final Listenable repaint;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repaint,
    builder: (context, _) {
      final left = math.max(0, ProtoSim.duration - sim.time).ceil();
      final time = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
      const style = TextStyle(
        color: Colors.white,
        fontSize: 18,
        shadows: [Shadow(offset: Offset(1, 1))],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(time, style: style),
            const Spacer(),
            const Icon(Icons.close, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(sim.kills.toString(), style: style),
            const SizedBox(width: 12),
            const Icon(Icons.circle, color: Color(0xFFF2C94C), size: 14),
            const SizedBox(width: 4),
            Text(sim.gold.toString(), style: style),
            const SizedBox(width: 12),
            const Icon(Icons.keyboard_double_arrow_up, color: Colors.white, size: 16),
            Text(sim.powerLevel.toString(), style: style),
          ],
        ),
      );
    },
  );
}

class _Result extends StatelessWidget {
  const _Result(this.sim, {required this.onAgain});

  final ProtoSim sim;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.platformProtoTitle, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              l10n.platformProtoResult(sim.kills, sim.gold),
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('proto.again'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E78BE)),
              onPressed: onAgain,
              child: Text(l10n.platformProtoAgain),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시험판 앱(지역화만 갖춘 최소 MaterialApp).
class ProtoApp extends StatelessWidget {
  const ProtoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(fontFamily: 'Galmuri11'),
    home: const ProtoScreen(),
  );
}
