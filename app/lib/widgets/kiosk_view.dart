import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';
import '../widgets.dart';

/// Public-display / 상황실 키오스크 모드. 사이드바와 운영 헤더를 숨기고
/// 시민/임원이 봐도 즉시 이해되는 대형 라이브 뷰만 보여줌.
class KioskView extends StatefulWidget {
  final VoidCallback onExit;
  const KioskView({super.key, required this.onExit});

  @override
  State<KioskView> createState() => _KioskViewState();
}

class _KioskViewState extends State<KioskView> {
  late Timer _ticker;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1),
        (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(now: _now, onExit: widget.onExit),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: _MainCctv()),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: _OverallGauge()),
                          const SizedBox(height: 14),
                          Expanded(flex: 4, child: _SignalStripPanel()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(height: 130, child: _DirectionsRow()),
              const SizedBox(height: 14),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime now;
  final VoidCallback onExit;
  const _Header({required this.now, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accent, Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.hub, size: 24, color: Colors.black),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('AI 스마트 교통 신호 제어 시스템',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('실시간 운영 현황',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
        const Spacer(),
        const StatusDotPill(label: '연결 대기', color: AppColors.textMuted),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('yyyy.MM.dd').format(now),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm:ss').format(now),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(width: 18),
        ElevatedButton.icon(
          onPressed: onExit,
          icon: const Icon(Icons.fullscreen_exit,
              size: 16, color: Colors.black),
          label: const Text('일반 모드',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

class _MainCctv extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.videocam_outlined,
                  size: 18, color: AppColors.accent),
              SizedBox(width: 8),
              Text('실시간 교차로',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              Spacer(),
              LiveBadge(),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.panelAlt, AppColors.panel],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.videocam_off_outlined,
                          size: 80, color: AppColors.textMuted),
                    ),
                  ),
                  const _DirOverlay(text: '북(N)', align: Alignment.topCenter, color: AppColors.north),
                  const _DirOverlay(text: '동(E)', align: Alignment.centerRight, color: AppColors.east),
                  const _DirOverlay(text: '남(S)', align: Alignment.bottomCenter, color: AppColors.south),
                  const _DirOverlay(text: '서(W)', align: Alignment.centerLeft, color: AppColors.west),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirOverlay extends StatelessWidget {
  final String text;
  final Alignment align;
  final Color color;
  const _DirOverlay({
    required this.text,
    required this.align,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
          ),
          child: Text(text,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _OverallGauge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.speed_outlined, size: 18, color: AppColors.accent),
              SizedBox(width: 8),
              Text('전체 혼잡도',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const Expanded(child: WaitingBox(compact: true)),
        ],
      ),
    );
  }
}

class _SignalStripPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.traffic_outlined,
                  size: 18, color: AppColors.accent),
              SizedBox(width: 8),
              Text('현재 신호',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          const Expanded(
              child: WaitingBox(icon: Icons.traffic_outlined, compact: true)),
        ],
      ),
    );
  }
}

class _DirectionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Panel(
      child: Center(
        child: WaitingBox(label: '방향별 현황 — 연결 대기 중', compact: true),
      ),
    );
  }
}

// ignore: unused_element
class _DirCard extends StatelessWidget {
  final String label;
  final int count;
  final int queue;
  final String wait;
  final Color color;
  const _DirCard({
    required this.label,
    required this.count,
    required this.queue,
    required this.wait,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_upward, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$count',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.0)),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('대',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('대기 $queue · 평균 $wait',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.stroke, width: 1),
      ),
      child: Row(
        children: const [
          Icon(Icons.shield_outlined, size: 13, color: AppColors.ok),
          SizedBox(width: 6),
          Text('Edge AI · 100% 로컬 운영 · 클라우드 미사용',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          Spacer(),
          Icon(Icons.access_time, size: 13, color: AppColors.textMuted),
          SizedBox(width: 6),
          Text('마지막 업데이트: —',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
