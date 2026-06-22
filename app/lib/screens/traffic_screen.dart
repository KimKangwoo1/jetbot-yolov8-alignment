import 'package:flutter/material.dart';

import '../data/live_data.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/cctv_player.dart';
import '../widgets/intersection_selector.dart';

class TrafficScreen extends StatelessWidget {
  const TrafficScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _KpiRow(),
          SizedBox(height: 10),
          _MiddleRow(),
          SizedBox(height: 10),
          _BottomRow(),
        ],
      ),
    );
  }
}

// ============================================================
// Top: KPI strip (waiting for live data)
// ============================================================
class _KpiRow extends StatelessWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListenableBuilder(
        listenable: LiveData.instance,
        builder: (context, _) {
          final d = LiveData.instance;
          final k = d.kpis;

          if (k == null) {
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: _WaitingKpi(
                        icon: Icons.directions_car_filled,
                        color: AppColors.north,
                        label: '전체 차량 수')),
                SizedBox(width: 10),
                Expanded(
                    child: _WaitingKpi(
                        icon: Icons.timer_outlined,
                        color: AppColors.warn,
                        label: '평균 정차 시간')),
                SizedBox(width: 10),
                Expanded(
                    child: _WaitingKpi(
                        icon: Icons.local_hospital_outlined,
                        color: AppColors.danger,
                        label: '구급차 감지')),
                SizedBox(width: 10),
                Expanded(
                    child: _WaitingKpi(
                        icon: Icons.donut_large_outlined,
                        color: AppColors.accent,
                        label: '전체 혼잡도')),
              ],
            );
          }

          final amb = [d.north, d.east, d.south, d.west]
              .whereType<DirectionLive>()
              .fold<int>(0, (a, b) => a + b.ambulanceCount);
          final congPct = (k.overallCongestion * 100).round();
          final congColor = AppColors.forCongestion(k.overallCongestion);

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: KpiCard(
                  icon: Icons.directions_car_filled,
                  iconColor: AppColors.north,
                  label: '전체 차량 수',
                  value: '${k.totalVehicles}',
                  unit: '대',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiCard(
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.warn,
                  label: '평균 정차 시간',
                  value: k.avgWaitSec.toStringAsFixed(1),
                  unit: '초',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiCard(
                  icon: Icons.local_hospital_outlined,
                  iconColor:
                      amb > 0 ? AppColors.danger : AppColors.textSecondary,
                  label: '구급차 감지',
                  value: '$amb',
                  unit: '대',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KpiCard(
                  icon: Icons.donut_large_outlined,
                  iconColor: congColor,
                  label: '전체 혼잡도',
                  value: '$congPct',
                  unit: '%',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A KPI card placeholder — shows the metric label and a "—" until the
/// backend sends a value.
class _WaitingKpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _WaitingKpi({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border:
                      Border.all(color: color.withValues(alpha: 0.35), width: 1),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: const [
              PulseDot(color: AppColors.textMuted, size: 6),
              SizedBox(width: 6),
              Text('—',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.0)),
              SizedBox(width: 8),
              Text('연결 대기',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Middle: intersection CCTV + per-direction stats grid
// ============================================================
class _MiddleRow extends StatelessWidget {
  const _MiddleRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(flex: 6, child: _IntersectionCctv()),
          SizedBox(width: 10),
          Expanded(flex: 6, child: _DirectionGrid()),
        ],
      ),
    );
  }
}

class _IntersectionCctv extends StatelessWidget {
  const _IntersectionCctv();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: '교차로 현황 (실시간)',
            icon: Icons.videocam_outlined,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => NavScope.of(context).goTo(0),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_new,
                            size: 12, color: AppColors.textMuted),
                        SizedBox(width: 3),
                        Text('모니터링',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const CctvUrlEditButton(isPrimary: true),
                const SizedBox(width: 6),
                const LiveBadge(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListenableBuilder(
              listenable: IntersectionRegistry.instance,
              builder: (context, _) {
                return CctvPlayer(
                  youtubeId: IntersectionRegistry.instance.selectedPrimaryUrl,
                  overlays: const [
                    _DirOverlay('북(N)', AppColors.north, Alignment.topCenter),
                    _DirOverlay('동(E)', AppColors.east, Alignment.centerRight),
                    _DirOverlay(
                        '남(S)', AppColors.south, Alignment.bottomCenter),
                    _DirOverlay('서(W)', AppColors.west, Alignment.centerLeft),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DirOverlay extends StatelessWidget {
  final String label;
  final Color color;
  final Alignment align;
  const _DirOverlay(this.label, this.color, this.align);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _DirectionGrid extends StatelessWidget {
  const _DirectionGrid();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          PanelHeader(
            title: '방향별 교통 현황',
            icon: Icons.swap_horiz_outlined,
          ),
          SizedBox(height: 8),
          Expanded(child: WaitingBox()),
        ],
      ),
    );
  }
}

// ============================================================
// Bottom: ranking + trend (waiting for live data)
// ============================================================
class _BottomRow extends StatelessWidget {
  const _BottomRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(flex: 6, child: _WaitingPanel(
            title: '혼잡도 순위',
            icon: Icons.format_list_numbered,
          )),
          SizedBox(width: 10),
          Expanded(flex: 6, child: _WaitingPanel(
            title: '혼잡도 트렌드 (전체)',
            icon: Icons.show_chart,
          )),
        ],
      ),
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  const _WaitingPanel({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: title, icon: icon),
          const SizedBox(height: 8),
          Expanded(child: WaitingBox(icon: icon)),
        ],
      ),
    );
  }
}
