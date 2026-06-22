import 'package:flutter/material.dart';

import '../widgets.dart';
import '../widgets/cctv_player.dart';
import '../widgets/intersection_selector.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _TopRow(),
          SizedBox(height: 10),
          _BottomRow(),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(flex: 5, child: _TrackingCctv()),
          SizedBox(width: 10),
          Expanded(
              flex: 4,
              child: _WaitingPanel(
                title: '긴급차량 정보',
                icon: Icons.directions_car_filled,
                label: '감지된 긴급차량 없음',
              )),
          SizedBox(width: 10),
          Expanded(
              flex: 5,
              child: _WaitingPanel(
                title: '경로 진행 상황 — ETA',
                icon: Icons.route_outlined,
                label: '추적 중인 경로 없음',
              )),
        ],
      ),
    );
  }
}

class _TrackingCctv extends StatelessWidget {
  const _TrackingCctv();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(
            title: '실시간 긴급차량 추적',
            icon: Icons.local_hospital_outlined,
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
            child: ListenableBuilder(
              listenable: IntersectionRegistry.instance,
              builder: (context, _) {
                return CctvPlayer(
                  youtubeId: IntersectionRegistry.instance.selectedPrimaryUrl,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Bottom: lane status + log (waiting for live data)
// ============================================================
class _BottomRow extends StatelessWidget {
  const _BottomRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(
              flex: 7,
              child: _WaitingPanel(
                title: '일반 교통 신호 조정 현황',
                icon: Icons.alt_route_outlined,
              )),
          SizedBox(width: 10),
          Expanded(
              flex: 5,
              child: _WaitingPanel(
                title: '긴급차량 로그',
                icon: Icons.history_outlined,
                label: '기록 없음',
              )),
        ],
      ),
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final String label;
  const _WaitingPanel({
    required this.title,
    required this.icon,
    this.label = '연결 대기 중',
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: title, icon: icon),
          const SizedBox(height: 8),
          Expanded(child: WaitingBox(icon: icon, label: label, compact: true)),
        ],
      ),
    );
  }
}
