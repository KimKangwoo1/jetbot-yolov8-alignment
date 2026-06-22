import 'package:flutter/material.dart';

import '../data/live_data.dart';
import '../nav.dart';
import '../theme.dart';
import '../web_helpers.dart';
import '../widgets.dart';
import '../widgets/cctv_player.dart';
import '../widgets/intersection_selector.dart';
import '../widgets/webcam_feed.dart';

// 효준 노트북 스트리머 주소 (detect_stream.py 출력 IP).
// IP가 바뀌면 여기만 고치세요. 같은 와이파이 필수.
const String kHyojunMjpegUrl = 'http://192.168.0.116:8080/stream';
const String kHyojunWsUrl = 'ws://192.168.0.116:8765';

// 방향 키 → (라벨, 색상). 화면 표기 순서: 북·동·남·서.
const List<(String, String, Color)> _dirMeta = [
  ('north', '북(N)', AppColors.north),
  ('east', '동(E)', AppColors.east),
  ('south', '남(S)', AppColors.south),
  ('west', '서(W)', AppColors.west),
];

DirectionLive? _dirData(LiveData d, String key) => switch (key) {
      'north' => d.north,
      'east' => d.east,
      'south' => d.south,
      'west' => d.west,
      _ => null,
    };

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        // CCTV가 남는 세로 공간을 모두 차지하도록 확장
        Expanded(child: _TopRow()),
        SizedBox(height: 10),
        _DirectionStatsRow(),
      ],
    );
  }
}

// ============================================================
// Tappable wrapper that navigates on tap
// ============================================================
class _LinkPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _LinkPanel({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}

// ============================================================
// Top: CCTV (left) + side panels (right)
// ============================================================
class _TopRow extends StatelessWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        Expanded(flex: 5, child: _MainCctvPanel()),
        SizedBox(width: 10),
        Expanded(flex: 3, child: _RightColumn()),
      ],
    );
  }
}

class _MainCctvPanel extends StatefulWidget {
  const _MainCctvPanel();

  @override
  State<_MainCctvPanel> createState() => _MainCctvPanelState();
}

class _MainCctvPanelState extends State<_MainCctvPanel> {
  bool _aiOverlay = true;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: '실시간 CCTV',
            icon: Icons.videocam_outlined,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CctvUrlEditButton(isPrimary: true),
                SizedBox(width: 6),
                LiveBadge(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            // 효준 노트북 웹캠 실시간 영상 + 감지됨 배지
            child: Stack(
              fit: StackFit.expand,
              children: [
                const WebcamFeed(
                  mjpegUrl: kHyojunMjpegUrl,
                  wsUrl: kHyojunWsUrl,
                ),
                if (_aiOverlay) ...const [
                  Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child:
                          _DirLabel('북(N)', AppColors.north, alignTop: true)),
                  Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: _DirLabel('동(E)', AppColors.east,
                          alignTop: false, vertical: true)),
                  Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child:
                          _DirLabel('남(S)', AppColors.south, alignTop: false)),
                  Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: _DirLabel('서(W)', AppColors.west,
                          alignTop: false, vertical: true)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CctvToggleChip(
                icon: Icons.crop_din,
                label: '방향 라벨',
                active: _aiOverlay,
                onTap: () => setState(() => _aiOverlay = !_aiOverlay),
              ),
              const Spacer(),
              _CctvToggleChip(
                icon: Icons.fullscreen,
                label: '',
                active: false,
                onTap: () async {
                  await toggleFullscreen();
                  if (context.mounted) {
                    showActionSnack(context,
                        isFullscreen() ? '전체화면 모드' : '전체화면 종료',
                        icon: isFullscreen()
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool alignTop;
  final bool vertical;
  const _DirLabel(this.text, this.color,
      {this.alignTop = false, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
    if (vertical) {
      return Center(child: chip);
    }
    return Align(
      alignment: alignTop ? Alignment.topCenter : Alignment.bottomCenter,
      child: chip,
    );
  }
}

class _CctvToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CctvToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: kMotionFast,
        curve: kMotionCurve,
        padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? 7 : 9, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.10)
              : AppColors.panelAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.stroke,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Right column: congestion + sub CCTV + overall + emergency
// ============================================================
class _RightColumn extends StatelessWidget {
  const _RightColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(flex: 3, child: _DirectionGaugesPanel()),
              SizedBox(width: 10),
              Expanded(flex: 2, child: _SubCctvPanel()),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(flex: 3, child: _OverallCongestionPanel()),
              SizedBox(width: 10),
              Expanded(flex: 2, child: _EmergencyPanel()),
            ],
          ),
        ),
      ],
    );
  }
}

class _DirectionGaugesPanel extends StatelessWidget {
  const _DirectionGaugesPanel();

  @override
  Widget build(BuildContext context) {
    return _LinkPanel(
      onTap: () => NavScope.of(context).goTo(1), // → 교통 현황
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PanelHeader(
              title: '방향별 혼잡도',
              icon: Icons.donut_small_outlined,
              trailing: _LinkHint(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: LiveData.instance,
                builder: (context, _) {
                  final d = LiveData.instance;
                  if (!d.hasDirections) {
                    return const WaitingBox(compact: true);
                  }
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final m in _dirMeta)
                        _CongestionRow(
                          label: m.$2,
                          color: m.$3,
                          data: _dirData(d, m.$1)!,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubCctvPanel extends StatefulWidget {
  const _SubCctvPanel();

  @override
  State<_SubCctvPanel> createState() => _SubCctvPanelState();
}

class _SubCctvPanelState extends State<_SubCctvPanel> {
  static const _sources = <String>[
    'CCTV-A (북측)',
    'CCTV-B (동측)',
    'CCTV-C (남측)',
    'CCTV-D (서측)'
  ];
  String _selected = 'CCTV-A (북측)';

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader(
            title: '보조 CCTV',
            icon: Icons.videocam_outlined,
            trailing: LiveBadge(),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListenableBuilder(
              listenable: IntersectionRegistry.instance,
              builder: (context, _) {
                return CctvPlayer(
                  youtubeId: IntersectionRegistry.instance.selectedSubUrl,
                  borderRadius: BorderRadius.circular(6),
                  overlays: [
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.bg.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _selected,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _SourceMenu(
                current: _selected,
                options: _sources,
                onPick: (v) => setState(() => _selected = v),
              ),
              const SizedBox(width: 6),
              const CctvUrlEditButton(isPrimary: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceMenu extends StatelessWidget {
  final String current;
  final List<String> options;
  final ValueChanged<String> onPick;
  const _SourceMenu({
    required this.current,
    required this.options,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '소스 선택',
      color: AppColors.panel,
      offset: const Offset(0, 24),
      onSelected: onPick,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<String>(
            value: o,
            child: Row(
              children: [
                Icon(
                  o == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 14,
                  color: o == current ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(o,
                    style: TextStyle(
                        color: o == current
                            ? AppColors.accent
                            : AppColors.textPrimary,
                        fontSize: 12)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.stroke, width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 12, color: AppColors.textSecondary),
            SizedBox(width: 3),
            Text('소스',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _OverallCongestionPanel extends StatelessWidget {
  const _OverallCongestionPanel();

  @override
  Widget build(BuildContext context) {
    return _LinkPanel(
      onTap: () => NavScope.of(context).goTo(5), // → 통계 분석
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            PanelHeader(
              title: '전체 혼잡도',
              icon: Icons.speed_outlined,
              trailing: _LinkHint(),
            ),
            SizedBox(height: 4),
            Expanded(child: WaitingBox(compact: true)),
            SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _EmergencyPanel extends StatelessWidget {
  const _EmergencyPanel();

  @override
  Widget build(BuildContext context) {
    return _LinkPanel(
      onTap: () => NavScope.of(context).goTo(3), // → 긴급차량 우선
      child: Panel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Row(
              children: [
                Icon(Icons.local_hospital_outlined,
                    size: 16, color: AppColors.textMuted),
                SizedBox(width: 6),
                Text('긴급차량 감지',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Spacer(),
                _LinkHint(),
              ],
            ),
            SizedBox(height: 8),
            Expanded(
              child: WaitingBox(
                icon: Icons.local_hospital_outlined,
                label: '감지된 긴급차량 없음',
                hint: 'Jetson 연결 시 실시간으로 표시됩니다.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkHint extends StatelessWidget {
  const _LinkHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('상세',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          SizedBox(width: 2),
          Icon(Icons.chevron_right, size: 13, color: AppColors.accent),
        ],
      ),
    );
  }
}

// ============================================================
// Middle: per-direction stats (waiting for live data)
// ============================================================
class _DirectionStatsRow extends StatelessWidget {
  const _DirectionStatsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 158,
      child: _LinkPanel(
        onTap: () => NavScope.of(context).goTo(1),
        child: Panel(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PanelHeader(
                title: '방향별 교통 현황 (북/동/남/서)',
                icon: Icons.swap_horiz_outlined,
                trailing: _LinkHint(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListenableBuilder(
                  listenable: LiveData.instance,
                  builder: (context, _) {
                    final d = LiveData.instance;
                    if (!d.hasDirections) {
                      return const WaitingBox();
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _dirMeta.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _DirCountCard(
                              label: _dirMeta[i].$2,
                              color: _dirMeta[i].$3,
                              data: _dirData(d, _dirMeta[i].$1)!,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 방향별 혼잡도 한 줄 (라벨 · 바 · 퍼센트) — live
// ============================================================
class _CongestionRow extends StatelessWidget {
  final String label;
  final Color color;
  final DirectionLive data;
  const _CongestionRow({
    required this.label,
    required this.color,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forCongestion(data.congestion);
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        Expanded(child: MiniBar(value: data.congestion, color: c)),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${data.congestionPercent.round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 방향별 차량 수 카드 (전체 + 일반/구급/정차 분해) — live
// ============================================================
class _DirCountCard extends StatelessWidget {
  final String label;
  final Color color;
  final DirectionLive data;
  const _DirCountCard({
    required this.label,
    required this.color,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forCongestion(data.congestion);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              StatusDotPill(label: data.congestionLevel, color: c, dense: true),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${data.vehicleCount}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 3),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text('대',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            ],
          ),
          Row(
            children: [
              _MiniStat(
                  label: '일반',
                  value: '${data.normalCount}',
                  color: AppColors.textSecondary),
              const SizedBox(width: 10),
              _MiniStat(
                label: '구급',
                value: '${data.ambulanceCount}',
                color: data.ambulanceCount > 0
                    ? AppColors.danger
                    : AppColors.textSecondary,
              ),
              const Spacer(),
              _MiniStat(
                  label: '정차',
                  value: '${data.waitingCount}',
                  color: AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

