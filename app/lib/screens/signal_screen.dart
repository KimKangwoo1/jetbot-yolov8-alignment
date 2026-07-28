import 'package:flutter/material.dart';

import '../data/live_data.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets.dart';

// 방향 키(north/…) → 한글 라벨.
String _dirLabelKo(String key) => switch (key) {
      'north' => '북(N)',
      'east' => '동(E)',
      'south' => '남(S)',
      'west' => '서(W)',
      _ => key,
    };

// 4방향 신호 중 우선순위 높은 제어 모드.
String _overallMode(LiveData d) {
  final modes = d.signals.values.map((s) => s.controlMode).toSet();
  if (modes.contains('EMERGENCY')) return 'EMERGENCY';
  if (modes.contains('CONGESTION')) return 'CONGESTION';
  return 'NORMAL';
}

String _modeLabel(String m) => switch (m) {
      'EMERGENCY' => '긴급 우선',
      'CONGESTION' => '혼잡 대응',
      _ => '정상',
    };

Color _modeColor(String m) => switch (m) {
      'EMERGENCY' => AppColors.danger,
      'CONGESTION' => AppColors.warn,
      _ => AppColors.ok,
    };

class SignalScreen extends StatefulWidget {
  const SignalScreen({super.key});

  @override
  State<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends State<SignalScreen> {
  static const _stepDirs = ['N', 'E', 'S', 'W', 'N', 'E', 'S', 'W'];

  // Operator-driven control state. The actual controller phase/timing comes
  // from the Jetson backend; until connected we only preview the operator's
  // manual selection (no simulated "live" countdown).
  int _step = 1;
  bool _autoMode = true;
  bool _running = false;

  String get _activeDir => _stepDirs[(_step - 1).clamp(0, 7)];

  String get _activeDirLabel => switch (_activeDir) {
        'N' => '북(N)',
        'E' => '동(E)',
        'S' => '남(S)',
        'W' => '서(W)',
        _ => '-',
      };

  void _setStep(int next) {
    setState(() {
      _step = ((next - 1) % 8 + 8) % 8 + 1;
    });
  }

  void _jumpToDirection(String dir) {
    final idx = _stepDirs.indexOf(dir);
    if (idx == -1) return;
    _setStep(idx + 1);
    showActionSnack(context, '$dir 방향으로 강제 진입', icon: Icons.swap_horiz);
  }

  void _prev() {
    _setStep(_step - 1);
    showActionSnack(context, '이전 단계로 이동: $_step단계', icon: Icons.skip_previous);
  }

  void _next() {
    _setStep(_step + 1);
    showActionSnack(context, '다음 단계로 이동: $_step단계', icon: Icons.skip_next);
  }

  void _togglePause() {
    setState(() => _running = !_running);
    showActionSnack(
      context,
      _running ? '신호 진행 재개' : '신호 정지',
      icon: _running ? Icons.play_arrow : Icons.pause,
    );
  }

  void _forceChange() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('강제 신호 변경',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        content: const Text(
          '현재 진행 중인 신호를 즉시 종료하고 다음 단계로 전환합니다.\n계속하시겠습니까?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _next();
            },
            child: const Text('변경', style: TextStyle(color: AppColors.warn)),
          ),
        ],
      ),
    );
  }

  void _allStop() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('전체 정지',
            style: TextStyle(color: AppColors.danger, fontSize: 14)),
        content: const Text(
          '모든 방향을 적색으로 변경합니다. 일반 통행이 중단됩니다.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _running = false;
                _autoMode = false;
              });
              showActionSnack(context, '전체 정지 — MANUAL 모드',
                  icon: Icons.do_not_disturb_on);
            },
            child: const Text('정지', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _emergencyMode() {
    NavScope.of(context).goTo(3); // → 긴급차량 우선 화면
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 380,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: _IntersectionPanel(
                    step: _step,
                    onDirTap: _jumpToDirection,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ControlModePanel(
                        step: _step,
                        auto: _autoMode,
                        running: _running,
                        activeDir: _activeDirLabel,
                        onModeChange: (v) => setState(() => _autoMode = v),
                      ),
                      const SizedBox(height: 10),
                      const Expanded(child: _LiveLogPanel()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _DecisionTracePanel(),
          const SizedBox(height: 10),
          _PhaseRow(step: _step, onTap: _setStep),
          const SizedBox(height: 10),
          _ManualControls(
            running: _running,
            onPrev: _prev,
            onNext: _next,
            onTogglePause: _togglePause,
            onForce: _forceChange,
            onStop: _allStop,
            onEmergency: _emergencyMode,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Intersection schematic with 4 traffic light boxes in a cross
// ============================================================
class _IntersectionPanel extends StatelessWidget {
  final int step;
  final ValueChanged<String> onDirTap;
  const _IntersectionPanel({required this.step, required this.onDirTap});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: ListenableBuilder(
        listenable: LiveData.instance,
        builder: (context, _) {
          final d = LiveData.instance;
          final connected = d.signals.isNotEmpty;
          final activeDir = _activeDirFor(step);
          SignalLive? lv(String k) => connected ? d.signals[k] : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHeader(
                title: connected ? '교차로 신호 상태' : '교차로 신호 - 수동 미리보기',
                icon: Icons.account_tree_outlined,
                trailing: connected ? const LiveBadge() : null,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  return Stack(
                    children: [
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: AppColors.stroke, width: 1),
                          ),
                          child: const Center(
                            child: Icon(Icons.add_road_outlined,
                                size: 28, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: _SignalBox(
                          label: '북(N)',
                          color: AppColors.north,
                          active: activeDir == 'N',
                          live: lv('north'),
                          onTap: () => onDirTap('N'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _SignalBox(
                          label: '남(S)',
                          color: AppColors.south,
                          active: activeDir == 'S',
                          live: lv('south'),
                          onTap: () => onDirTap('S'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _SignalBox(
                          label: '동(E)',
                          color: AppColors.east,
                          active: activeDir == 'E',
                          live: lv('east'),
                          onTap: () => onDirTap('E'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _SignalBox(
                          label: '서(W)',
                          color: AppColors.west,
                          active: activeDir == 'W',
                          live: lv('west'),
                          onTap: () => onDirTap('W'),
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                    connected
                        ? '실시간 신호 상태 — 노트북(YOLO) → Supabase'
                        : '박스 클릭 시 해당 방향으로 강제 진입',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _activeDirFor(int step) {
    const order = ['N', 'E', 'S', 'W', 'N', 'E', 'S', 'W'];
    final i = (step - 1).clamp(0, 7);
    return order[i];
  }
}

class _SignalBox extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  /// Supabase 실시간 신호. null 이면 수동 미리보기(active) 모드.
  final SignalLive? live;
  final VoidCallback onTap;
  const _SignalBox({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
    this.live,
  });

  @override
  Widget build(BuildContext context) {
    final live = this.live;
    final state = live?.signalState;
    final isGreen = live != null ? state == 'GREEN' : active;
    final emergency = live?.controlMode == 'EMERGENCY';

    final List<LightState> states = live != null
        ? switch (state) {
            'GREEN' => const [
                LightState.off,
                LightState.off,
                LightState.green,
                LightState.leftArrow
              ],
            'YELLOW' => const [
                LightState.off,
                LightState.yellow,
                LightState.off,
                LightState.off
              ],
            _ => const [
                LightState.red,
                LightState.off,
                LightState.off,
                LightState.off
              ],
          }
        : (active
            ? const [
                LightState.off,
                LightState.off,
                LightState.green,
                LightState.leftArrow
              ]
            : const [
                LightState.red,
                LightState.off,
                LightState.off,
                LightState.off
              ]);

    String statusText;
    Color statusColor;
    IconData statusIcon;
    if (live != null) {
      switch (state) {
        case 'GREEN':
          statusText = '진행';
          statusColor = AppColors.ok;
          statusIcon = Icons.arrow_upward;
        case 'YELLOW':
          statusText = '주의';
          statusColor = AppColors.warn;
          statusIcon = Icons.warning_amber_rounded;
        default:
          statusText = '정지';
          statusColor = AppColors.danger;
          statusIcon = Icons.block;
      }
    } else {
      statusText = active ? '진행' : '정지';
      statusColor = active ? AppColors.ok : AppColors.textMuted;
      statusIcon = active ? Icons.arrow_upward : Icons.block;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: kMotionFast,
        curve: kMotionCurve,
        width: 130,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: isGreen ? color.withValues(alpha: 0.10) : AppColors.panelAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: emergency
                ? AppColors.danger.withValues(alpha: 0.7)
                : (isGreen ? color.withValues(alpha: 0.6) : AppColors.stroke),
            width: emergency ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                if (emergency) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.priority_high,
                      size: 12, color: AppColors.danger),
                ],
              ],
            ),
            const SizedBox(height: 6),
            TrafficLightDots(states: states),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 3),
                Text(
                  statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
                if (live != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${live.remainTime}초',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Right top: control mode panel
// ============================================================
class _ControlModePanel extends StatelessWidget {
  final int step;
  final bool auto;
  final bool running;
  final String activeDir;
  final ValueChanged<bool> onModeChange;
  const _ControlModePanel({
    required this.step,
    required this.auto,
    required this.running,
    required this.activeDir,
    required this.onModeChange,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_input_component,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              const Text('신호 제어 모드',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              _ModeBadge(auto: auto, onTap: () => onModeChange(!auto)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5), width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$step',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.0)),
                    const SizedBox(height: 2),
                    const Text('선택 단계',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListenableBuilder(
                  listenable: LiveData.instance,
                  builder: (context, _) {
                    final d = LiveData.instance;
                    final connected = d.signals.isNotEmpty;
                    final greens = d.signals.entries
                        .where((e) => e.value.signalState == 'GREEN')
                        .toList();
                    final go = connected ? greens.isNotEmpty : running;
                    final activeLabel = connected
                        ? (greens.isEmpty
                            ? '없음'
                            : greens.map((e) => _dirLabelKo(e.key)).join(', '))
                        : activeDir;
                    final remain = connected && greens.isNotEmpty
                        ? '${greens.first.value.remainTime}초'
                        : '—';
                    final mode = _overallMode(d);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StatLine(
                          label: '실행 상태',
                          value: go ? '진행 중' : '정지됨',
                          valueColor: go ? AppColors.ok : AppColors.danger,
                        ),
                        const StatLine(label: '경과 시간', value: '—'),
                        StatLine(label: '잔여 시간', value: remain),
                        StatLine(label: '활성 방향', value: activeLabel),
                        if (connected)
                          StatLine(
                            label: 'AI 제어모드',
                            value: _modeLabel(mode),
                            valueColor: _modeColor(mode),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final bool auto;
  final VoidCallback onTap;
  const _ModeBadge({required this.auto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = auto ? AppColors.ok : AppColors.warn;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: kMotionFast,
        curve: kMotionCurve,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          auto ? 'AUTO' : 'MANUAL',
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5),
        ),
      ),
    );
  }
}

// ============================================================
// Right bottom: live event log (waiting for live data)
// ============================================================
class _LiveLogPanel extends StatelessWidget {
  const _LiveLogPanel();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          PanelHeader(
            title: '실시간 신호 변화',
            icon: Icons.history_outlined,
            trailing: LiveBadge(),
          ),
          SizedBox(height: 6),
          Expanded(child: WaitingBox(icon: Icons.history_outlined, label: '기록 없음')),
        ],
      ),
    );
  }
}

// ============================================================
// Phase chips 1..8
// ============================================================
class _PhaseRow extends StatelessWidget {
  final int step;
  final ValueChanged<int> onTap;
  const _PhaseRow({required this.step, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.linear_scale, size: 16, color: AppColors.accent),
              SizedBox(width: 6),
              Text('신호 단계 선택',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Spacer(),
              Text('전체 8단계 사이클',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 8; i++) ...[
                Expanded(
                  child: _PhaseChip(
                    n: i,
                    active: i == step,
                    onTap: () => onTap(i),
                  ),
                ),
                if (i < 8) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final int n;
  final bool active;
  final VoidCallback onTap;
  const _PhaseChip({
    required this.n,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg, fg, border;
    if (active) {
      bg = AppColors.accent.withValues(alpha: 0.18);
      fg = AppColors.accent;
      border = AppColors.accent;
    } else {
      bg = AppColors.panelAlt;
      fg = AppColors.textSecondary;
      border = AppColors.stroke;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: kMotionFast,
        curve: kMotionCurve,
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          '$n',
          style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ============================================================
// Decision trace — populated by the AI engine once connected
// ============================================================
class _DecisionTracePanel extends StatelessWidget {
  const _DecisionTracePanel();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Row(
            children: [
              Icon(Icons.psychology_alt_outlined,
                  size: 16, color: AppColors.accent),
              SizedBox(width: 6),
              Text('현재 결정 — 왜 이 신호인가?',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Spacer(),
              Text('AI 엔진 연결 시 표시',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: WaitingBox(
              icon: Icons.psychology_alt_outlined,
              label: '판단 근거 대기 중',
              hint: 'Jetson AI 엔진이 연결되면 현재 신호 결정의 근거가 표시됩니다.',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Manual control buttons
// ============================================================
class _ManualControls extends StatelessWidget {
  final bool running;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onTogglePause;
  final VoidCallback onForce;
  final VoidCallback onStop;
  final VoidCallback onEmergency;
  const _ManualControls({
    required this.running,
    required this.onPrev,
    required this.onNext,
    required this.onTogglePause,
    required this.onForce,
    required this.onStop,
    required this.onEmergency,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          const Icon(Icons.tune, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          const Text('수동 제어',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          _CtrlButton(icon: Icons.skip_previous, label: '이전', onTap: onPrev),
          const SizedBox(width: 6),
          _CtrlButton(
            icon: running ? Icons.pause : Icons.play_arrow,
            label: running ? '정지' : '재개',
            tone: running ? AppColors.warn : AppColors.ok,
            onTap: onTogglePause,
          ),
          const SizedBox(width: 6),
          _CtrlButton(icon: Icons.skip_next, label: '다음', onTap: onNext),
          const Spacer(),
          _CtrlButton(
              icon: Icons.swap_horiz,
              label: '강제 변경',
              tone: AppColors.warn,
              onTap: onForce),
          const SizedBox(width: 6),
          _CtrlButton(
              icon: Icons.do_not_disturb_on,
              label: '전체 정지',
              tone: AppColors.danger,
              onTap: onStop),
          const SizedBox(width: 6),
          _CtrlButton(
              icon: Icons.priority_high,
              label: '긴급 모드',
              tone: AppColors.violet,
              onTap: onEmergency),
        ],
      ),
    );
  }
}

class _CtrlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tone;
  final VoidCallback? onTap;
  const _CtrlButton({
    required this.icon,
    required this.label,
    this.tone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = tone ?? AppColors.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withValues(alpha: 0.45), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: c, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
