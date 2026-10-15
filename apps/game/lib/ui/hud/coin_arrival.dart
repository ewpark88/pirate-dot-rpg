import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/state/battle_providers.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 코인 도착 (S1 지시, 렌더 coinFlow 계약): 처치 코인이 상단 바 골드 아이콘으로 날아오고, 닿을 때마다
// 아이콘이 통 튀며 '+금액'이 뜬다. 표시 골드는 도착한 만큼 오른다(지갑은 처치 순간 이미 올라 있다).

/// 연달아 닿은 금액을 합치는 시간 — 이 안에 또 닿으면 '+금액'이 커진다.
const _mergeTicks = 12; // 0.6초 (틱 50ms)

/// 날아오는 중인 골드를 붙잡아 두는 최대 시간 — 코인이 안 닿아도(화면 밖 등) 이만큼 지나면 표시를 지갑에 맞춘다.
const _holdTicks = 24; // 1.2초

/// 상단 바 골드 아이콘 자리를 찾는 키 (전장 상자 기준 좌표로 바꿔 렌더에 준다).
final GlobalKey topGoldIconKey = GlobalKey(debugLabel: 'top.gold.icon');

@immutable
class CoinFx {
  const CoinFx({required this.merged, required this.seq, required this.pending, required this.lastArriveTick});

  static const none = CoinFx(merged: BigNum.zero, seq: 0, pending: BigNum.zero, lastArriveTick: -1000);

  /// 지금 떠 있는 '+금액' (연달아 닿은 합).
  final BigNum merged;

  /// 닿을 때마다 1씩 — 아이콘이 이 값이 바뀔 때 통 튄다.
  final int seq;

  /// 지갑에는 들어왔지만 아직 날아오는 중인 골드.
  final BigNum pending;
  final int lastArriveTick;

  CoinFx copyWith({BigNum? merged, int? seq, BigNum? pending, int? lastArriveTick}) => CoinFx(
    merged: merged ?? this.merged,
    seq: seq ?? this.seq,
    pending: pending ?? this.pending,
    lastArriveTick: lastArriveTick ?? this.lastArriveTick,
  );
}

final coinFxProvider = NotifierProvider<CoinArrivals, CoinFx>(CoinArrivals.new);

/// 코인 도착·표시 골드. 타이머 없이 전장 틱으로 시간을 잰다(테스트에 남는 타이머 없음).
class CoinArrivals extends Notifier<CoinFx> {
  int _lastIncreaseTick = -1000;

  int get _tick => ref.read(gameStateProvider).battle?.tick ?? 0;

  @override
  CoinFx build() {
    // 실제 전장(Flame)이 있을 때만 붙잡는다 — 테스트의 빈 전장이나 오프라인 보상은 바로 보인다.
    final live = ref.watch(hasBattleGameProvider);
    ref
      ..listen(gameStateProvider.select((s) => s.wallet.gold), (before, after) {
        if (!live || before == null || after <= before) return;
        _lastIncreaseTick = _tick;
        state = state.copyWith(pending: state.pending + (after - before));
      })
      ..listen(gameStateProvider.select((s) => s.battle?.tick ?? 0), (_, tick) {
        // 코인이 한동안 안 닿으면 붙잡은 골드를 놓는다.
        if (state.pending.isZero) return;
        final last = state.lastArriveTick > _lastIncreaseTick ? state.lastArriveTick : _lastIncreaseTick;
        if (tick - last > _holdTicks) state = state.copyWith(pending: BigNum.zero);
      });
    return CoinFx.none;
  }

  /// 렌더가 부른다: 이번 프레임에 닿은 코인 금액 합.
  void arrive(BigNum amount) {
    final tick = _tick;
    final merge = tick - state.lastArriveTick <= _mergeTicks;
    final left = state.pending - amount;
    state = CoinFx(
      merged: merge ? state.merged + amount : amount,
      seq: state.seq + 1,
      pending: left.isNegative ? BigNum.zero : left,
      lastArriveTick: tick,
    );
  }
}

/// 상단 바에 보일 골드 = 지갑 − 날아오는 중.
final displayGoldProvider = Provider<BigNum>((ref) {
  final gold = ref.watch(gameStateProvider.select((s) => s.wallet.gold));
  final pending = ref.watch(coinFxProvider.select((f) => f.pending));
  final shown = gold - pending;
  return shown.isNegative ? BigNum.zero : shown;
});

/// 전장 상자 안에 둔다: 상단 바 골드 아이콘 중심을 상자 기준 dp로 바꿔 렌더에 알리고, 도착 콜백을 잇는다.
/// 상자 크기가 바뀌면(시트 끌기) 다시 계산한다.
class CoinLink extends ConsumerStatefulWidget {
  const CoinLink({super.key});

  @override
  ConsumerState<CoinLink> createState() => _CoinLinkState();
}

class _CoinLinkState extends ConsumerState<CoinLink> {
  Offset? _sent;

  void _sync() {
    if (!mounted || !ref.read(hasBattleGameProvider)) return;
    final box = context.findRenderObject() as RenderBox?;
    final icon = topGoldIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || icon == null || !box.attached || !icon.attached) return;
    final target = box.globalToLocal(icon.localToGlobal(icon.size.center(Offset.zero)));
    final game = ref.read(battleGameProvider);
    if (target != _sent) {
      _sent = target;
      game.goldTargetDp = target;
    }
    game.onCoinArrive ??= ref.read(coinFxProvider.notifier).arrive;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _sync());
      return const SizedBox.expand();
    },
  );
}

/// 상단 바 골드 아이콘: 코인이 닿을 때마다 1 → 1.25 → 1 (180ms) 통 튀고 반짝, 옆에 '+금액'이 0.6초 떠오른다.
class CoinPulseIcon extends ConsumerStatefulWidget {
  const CoinPulseIcon({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CoinPulseIcon> createState() => _CoinPulseIconState();
}

class _CoinPulseIconState extends ConsumerState<CoinPulseIcon> with TickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    ref.listenManual(coinFxProvider.select((f) => f.seq), (before, after) {
      if (before == null || after == before) return;
      _bounce.forward(from: 0).ignore();
      _float.forward(from: 0).ignore();
    });
  }

  @override
  void dispose() {
    _bounce.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merged = ref.watch(coinFxProvider.select((f) => f.merged));
    return AnimatedBuilder(
      animation: Listenable.merge([_bounce, _float]),
      builder: (context, child) {
        final b = _bounce.value;
        final scale = 1 + 0.25 * (b < 0.5 ? b * 2 : (1 - b) * 2);
        final f = _float.value;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 반짝: 닿을 때 금빛 원이 퍼지며 사라진다.
            if (_bounce.isAnimating)
              IgnorePointer(
                child: Container(
                  width: 18 + 18 * b,
                  height: 18 + 18 * b,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFE27A).withValues(alpha: 0.55 * (1 - b)),
                  ),
                ),
              ),
            Transform.scale(
              scale: scale,
              child: KeyedSubtree(key: topGoldIconKey, child: child!),
            ),
            if (_float.isAnimating && !merged.isZero)
              Positioned(
                top: 22 + 10 * f,
                left: 4,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - f * f).clamp(0, 1).toDouble(),
                    child: Text(
                      '+${merged.format()}',
                      key: const Key('top.gold.plus'),
                      softWrap: false,
                      style: const TextStyle(
                        fontFamily: 'Jua',
                        fontSize: 14,
                        color: Color(0xFF8A5A00),
                        shadows: [Shadow(color: Colors.white, blurRadius: 3)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
