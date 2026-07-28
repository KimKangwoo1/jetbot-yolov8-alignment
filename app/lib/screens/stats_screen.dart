import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/stats_repository.dart';
import '../theme.dart';
import '../widgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _preset = '1주';
  late DateTime _start;
  late DateTime _end;

  StatsData? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _end = DateTime(now.year, now.month, now.day);
    _start = _end.subtract(const Duration(days: 6));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await StatsRepository.instance.fetch(_start, _end);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[StatsScreen] load failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyPreset(String p) {
    final now = DateTime.now();
    setState(() {
      _preset = p;
      switch (p) {
        case '오늘':
          _start = DateTime(now.year, now.month, now.day);
          _end = _start;
          break;
        case '1주':
          _end = DateTime(now.year, now.month, now.day);
          _start = _end.subtract(const Duration(days: 6));
          break;
        case '1개월':
          _end = DateTime(now.year, now.month, now.day);
          _start = DateTime(_end.year, _end.month - 1, _end.day);
          break;
      }
    });
    _load();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.black,
            surface: AppColors.panel,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
          if (_end.isBefore(_start)) _end = _start;
        } else {
          _end = picked;
          if (_start.isAfter(_end)) _start = _end;
        }
        _preset = '사용자정의';
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RangeBar(
            start: _start,
            end: _end,
            preset: _preset,
            loading: _loading,
            onPickStart: () => _pickDate(true),
            onPickEnd: () => _pickDate(false),
            onPreset: _applyPreset,
            onRefresh: _load,
          ),
          const SizedBox(height: 10),
          // KPI strip
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Kpi(
                    icon: Icons.directions_car_filled,
                    color: AppColors.north,
                    label: '총 통과 차량',
                    value: d == null ? null : '${d.totalVehicles}',
                    unit: '대',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Kpi(
                    icon: Icons.donut_large_outlined,
                    color: d == null
                        ? AppColors.accent
                        : AppColors.forCongestion(d.avgCongestion / 100),
                    label: '평균 혼잡도',
                    value: d?.avgCongestion.toStringAsFixed(0),
                    unit: '%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Kpi(
                    icon: Icons.auto_graph_outlined,
                    color: AppColors.ok,
                    label: '신호 효율',
                    value: d?.signalEfficiency.toStringAsFixed(0),
                    unit: '%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Kpi(
                    icon: Icons.local_hospital_outlined,
                    color: (d?.totalAmbulance ?? 0) > 0
                        ? AppColors.danger
                        : AppColors.textSecondary,
                    label: '긴급차량 감지',
                    value: d == null ? null : '${d.totalAmbulance}',
                    unit: '회',
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _KpiNa(
                    icon: Icons.speed_outlined,
                    label: '평균 속도',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 250,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ChartPanel(
                    title: '시간대별 교통량 추이',
                    icon: Icons.area_chart_outlined,
                    loading: _loading,
                    empty: d?.isEmpty ?? true,
                    child: d == null ? null : _VolumeChart(data: d),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChartPanel(
                    title: '방향별 혼잡도 추이',
                    icon: Icons.timeline,
                    loading: _loading,
                    empty: d?.isEmpty ?? true,
                    child: d == null ? null : _CongChart(data: d),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: _NaPanel(
                    title: '시간대별 평균 속도',
                    icon: Icons.bar_chart_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 240,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  flex: 4,
                  child: _NaPanel(
                    title: '긴급차량 대응 시간 분석',
                    icon: Icons.local_hospital_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: _ChartPanel(
                    title: '신호 효율성 분석',
                    icon: Icons.tune,
                    loading: _loading,
                    empty: d?.isEmpty ?? true,
                    child: d == null ? null : _EfficiencyPanel(data: d),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: _ChartPanel(
                    title: '방향별 주요 지표',
                    icon: Icons.table_view_outlined,
                    loading: _loading,
                    empty: d?.isEmpty ?? true,
                    child: d == null ? null : _DirTable(data: d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// KPI cards
// ============================================================
class _Kpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? value; // null → 로딩/대기
  final String unit;
  const _Kpi({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return _KpiNa(icon: icon, label: label, waiting: true);
    }
    return KpiCard(
      icon: icon,
      iconColor: color,
      label: label,
      value: value!,
      unit: unit,
    );
  }
}

/// 값이 없거나(로딩) 스키마에 데이터가 없는 KPI.
class _KpiNa extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool waiting; // true=로딩 대기, false=스키마 미지원
  const _KpiNa({required this.icon, required this.label, this.waiting = false});

  @override
  Widget build(BuildContext context) {
    final color = waiting ? AppColors.textMuted : AppColors.textMuted;
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
            children: [
              if (waiting) ...[
                const PulseDot(color: AppColors.textMuted, size: 6),
                const SizedBox(width: 6),
              ],
              const Text('—',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.0)),
              const SizedBox(width: 8),
              Text(waiting ? '불러오는 중' : '데이터 없음',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Chart panel wrapper — header + (loading / empty / child)
// ============================================================
class _ChartPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool loading;
  final bool empty;
  final Widget? child;
  const _ChartPanel({
    required this.title,
    required this.icon,
    required this.loading,
    required this.empty,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (child == null || loading) {
      body = const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accent),
        ),
      );
    } else if (empty) {
      body = WaitingBox(
        icon: icon,
        label: '데이터 없음',
        hint: '선택한 기간에 기록이 없습니다.',
      );
    } else {
      body = child!;
    }
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: title, icon: icon),
          const SizedBox(height: 10),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// 현재 스키마로는 채울 데이터가 없는 패널(속도·대응시간).
class _NaPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  const _NaPanel({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(title: title, icon: icon),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22, color: AppColors.strokeDim),
                    const SizedBox(height: 8),
                    const Text('데이터 없음',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('현재 수집 스키마 미지원 항목',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 시간대별 교통량 추이 (area line)
// ============================================================
class _VolumeChart extends StatelessWidget {
  final StatsData data;
  const _VolumeChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final buckets = data.buckets;
    final maxV = buckets.fold<int>(0, (a, b) => b.totalVehicles > a ? b.totalVehicles : a);
    final maxY = (maxV * 1.25).clamp(4, double.infinity).toDouble();
    final spots = [
      for (var i = 0; i < buckets.length; i++)
        FlSpot(i.toDouble(), buckets[i].totalVehicles.toDouble()),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (buckets.length - 1).clamp(0, double.infinity).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: _grid(maxY / 4),
        borderData: FlBorderData(show: false),
        titlesData: _titles(buckets, data.hourly, maxY / 4),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: AppColors.accent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 방향별 혼잡도 추이 (multi-line, 0..100%)
// ============================================================
class _CongChart extends StatelessWidget {
  final StatsData data;
  const _CongChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final buckets = data.buckets;
    final dirColor = {
      'north': AppColors.north,
      'south': AppColors.south,
      'east': AppColors.east,
      'west': AppColors.west,
    };
    final bars = <LineChartBarData>[];
    for (final dir in kDirections) {
      final spots = <FlSpot>[];
      for (var i = 0; i < buckets.length; i++) {
        final v = buckets[i].congByDir[dir];
        if (v != null) spots.add(FlSpot(i.toDouble(), v));
      }
      if (spots.isEmpty) continue;
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.2,
        color: dirColor[dir],
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (buckets.length - 1).clamp(0, double.infinity).toDouble(),
              minY: 0,
              maxY: 100,
              gridData: _grid(25),
              borderData: FlBorderData(show: false),
              titlesData: _titles(buckets, data.hourly, 25),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: bars,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            LegendDot(color: AppColors.north, label: '북'),
            LegendDot(color: AppColors.south, label: '남'),
            LegendDot(color: AppColors.east, label: '동'),
            LegendDot(color: AppColors.west, label: '서'),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// 신호 효율성 분석 — 큰 효율 % + 혼잡 단계 분포
// ============================================================
class _EfficiencyPanel extends StatelessWidget {
  final StatsData data;
  const _EfficiencyPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.rowCount;
    double ratio(int c) => total == 0 ? 0 : c / total;
    final eff = data.signalEfficiency;
    final effColor = eff >= 70
        ? AppColors.ok
        : eff >= 45
            ? AppColors.warn
            : AppColors.danger;

    Widget bar(String label, int count, Color color) {
      final r = ratio(count);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                LegendDot(color: color, label: label),
                const Spacer(),
                Text('$count회 · ${(r * 100).round()}%',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            MiniBar(value: r, color: color),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(eff.toStringAsFixed(0),
                style: TextStyle(
                    color: effColor,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.0)),
            const SizedBox(width: 3),
            Text('% 효율',
                style: TextStyle(color: effColor, fontSize: 13)),
            const Spacer(),
            const Text('혼잡 단계 분포',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        bar('원활', data.levelSmooth, AppColors.ok),
        bar('보통', data.levelNormal, AppColors.warn),
        bar('혼잡', data.levelJam, AppColors.danger),
      ],
    );
  }
}

// ============================================================
// 방향별 주요 지표 (table)
// ============================================================
class _DirTable extends StatelessWidget {
  final StatsData data;
  const _DirTable({required this.data});

  static const _kr = {
    'north': '북(N)',
    'south': '남(S)',
    'east': '동(E)',
    'west': '서(W)',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            SizedBox(
                width: 54,
                child: Text('방향',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 10))),
            Expanded(
                child: Text('누적차량',
                    textAlign: TextAlign.end,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 10))),
            Expanded(
                child: Text('평균혼잡',
                    textAlign: TextAlign.end,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 10))),
            Expanded(
                child: Text('구급차',
                    textAlign: TextAlign.end,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 10))),
          ],
        ),
        const Divider(color: AppColors.stroke, height: 14),
        for (final d in data.dirs) ...[
          _row(d),
          const SizedBox(height: 2),
        ],
      ],
    );
  }

  Widget _row(DirStat d) {
    final cong = d.avgCongestion;
    final color = AppColors.forCongestion(cong / 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(_kr[d.direction] ?? d.direction,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text('${d.vehicles}대',
                textAlign: TextAlign.end,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ),
          Expanded(
            child: Text('${cong.toStringAsFixed(0)}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text('${d.ambulance}',
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: d.ambulance > 0
                        ? AppColors.danger
                        : AppColors.textSecondary,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// fl_chart shared helpers
// ============================================================
FlGridData _grid(double interval) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval <= 0 ? 1 : interval,
      getDrawingHorizontalLine: (_) =>
          const FlLine(color: AppColors.strokeDim, strokeWidth: 1),
    );

FlTitlesData _titles(List<StatsBucket> buckets, bool hourly, double yInterval) {
  final step = (buckets.length / 5).ceil().clamp(1, 9999);
  return FlTitlesData(
    show: true,
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 30,
        interval: yInterval <= 0 ? 1 : yInterval,
        getTitlesWidget: (value, meta) => Text(
          value.toInt().toString(),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final i = value.round();
          if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
          if (i % step != 0) return const SizedBox.shrink();
          final b = buckets[i];
          final label =
              hourly ? '${b.start.hour}시' : DateFormat('M/d').format(b.start);
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 9)),
          );
        },
      ),
    ),
  );
}

// ============================================================
// Range filter bar
// ============================================================
class _RangeBar extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final String preset;
  final bool loading;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<String> onPreset;
  final VoidCallback onRefresh;
  const _RangeBar({
    required this.start,
    required this.end,
    required this.preset,
    required this.loading,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPreset,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('yyyy-MM-dd');
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          const Text('기간 선택',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          _DateInput(value: f.format(start), onTap: onPickStart),
          const SizedBox(width: 6),
          const Text('~',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(width: 6),
          _DateInput(value: f.format(end), onTap: onPickEnd),
          const SizedBox(width: 14),
          _RangeBtn(
              label: '오늘',
              active: preset == '오늘',
              onTap: () => onPreset('오늘')),
          const SizedBox(width: 4),
          _RangeBtn(
              label: '1주',
              active: preset == '1주',
              onTap: () => onPreset('1주')),
          const SizedBox(width: 4),
          _RangeBtn(
              label: '1개월',
              active: preset == '1개월',
              onTap: () => onPreset('1개월')),
          const SizedBox(width: 4),
          _RangeBtn(
              label: '사용자정의',
              active: preset == '사용자정의',
              onTap: onPickStart),
          const Spacer(),
          InkWell(
            onTap: loading ? null : onRefresh,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: loading
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  else
                    const Icon(Icons.refresh, size: 14, color: Colors.black),
                  const SizedBox(width: 4),
                  const Text('업데이트',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateInput extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _DateInput({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.stroke, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(width: 6),
            const Icon(Icons.calendar_today,
                size: 12, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _RangeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RangeBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: AnimatedContainer(
        duration: kMotionFast,
        curve: kMotionCurve,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.stroke,
            width: 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
