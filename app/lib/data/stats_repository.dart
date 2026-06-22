import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

// ============================================================
// 통계 분석 화면 데이터 소스.
//
// 실시간(traffic/signal/emergency)과 달리 통계는 "기간 조회"입니다.
// congestion_history(시간대별 기록) 를 기간으로 한 번 조회해서 KPI/차트용으로
// 집계합니다. realtime 구독이 아니라 기간을 바꿀 때마다 fetch 합니다.
//
// congestion_history 컬럼:
//   direction, vehicle_count, normal_count, ambulance_count,
//   congestion_percent, congestion_level(원활/보통/혼잡), created_at
// (속도·정차시간·대응시간 컬럼은 스키마에 없음 → 통계 화면에서 N/A 처리)
// ============================================================

double _d(Object? v) => v == null
    ? 0
    : v is num
        ? v.toDouble()
        : double.tryParse('$v') ?? 0;

int _i(Object? v) => v == null
    ? 0
    : v is num
        ? v.toInt()
        : int.tryParse('$v') ?? 0;

const kDirections = ['north', 'south', 'east', 'west'];

/// 한 시간 구간(bucket)의 집계값. 추이 차트의 한 점.
class StatsBucket {
  final DateTime start;
  final int totalVehicles;

  /// 방향별 평균 혼잡도(%) — 그 구간에 기록이 없으면 키 없음.
  final Map<String, double> congByDir;
  const StatsBucket({
    required this.start,
    required this.totalVehicles,
    required this.congByDir,
  });
}

/// 방향별 누적 지표(테이블용).
class DirStat {
  final String direction;
  final int vehicles;
  final int ambulance;
  final double avgCongestion; // %
  const DirStat({
    required this.direction,
    required this.vehicles,
    required this.ambulance,
    required this.avgCongestion,
  });
}

/// 통계 화면 한 번 조회 결과.
class StatsData {
  final int totalVehicles;
  final double avgCongestion; // %
  final int totalAmbulance;

  /// 신호 효율(%) — 혼잡 단계 분포 가중평균(원활1.0/보통0.6/혼잡0.2).
  final double signalEfficiency;

  /// 혼잡 단계별 기록 수.
  final int levelSmooth; // 원활
  final int levelNormal; // 보통
  final int levelJam; // 혼잡

  final List<StatsBucket> buckets;
  final List<DirStat> dirs;
  final int rowCount;
  final bool hourly; // true=시간단위 버킷, false=일단위

  const StatsData({
    required this.totalVehicles,
    required this.avgCongestion,
    required this.totalAmbulance,
    required this.signalEfficiency,
    required this.levelSmooth,
    required this.levelNormal,
    required this.levelJam,
    required this.buckets,
    required this.dirs,
    required this.rowCount,
    required this.hourly,
  });

  bool get isEmpty => rowCount == 0;

  static const empty = StatsData(
    totalVehicles: 0,
    avgCongestion: 0,
    totalAmbulance: 0,
    signalEfficiency: 0,
    levelSmooth: 0,
    levelNormal: 0,
    levelJam: 0,
    buckets: [],
    dirs: [],
    rowCount: 0,
    hourly: true,
  );
}

class StatsRepository {
  StatsRepository._();
  static final StatsRepository instance = StatsRepository._();

  SupabaseClient get _sb => Supabase.instance.client;

  /// [start]~[end] 기간(로컬 날짜)의 congestion_history 를 집계.
  Future<StatsData> fetch(DateTime start, DateTime end) async {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day, 23, 59, 59);
    // 하루 이내면 시간단위, 그 이상이면 일단위 버킷.
    final hourly = to.difference(from).inDays < 1;

    final rows = await _sb
        .from(SupabaseConfig.tCongestionHistory)
        .select(
          'direction,vehicle_count,normal_count,ambulance_count,'
          'congestion_percent,congestion_level,created_at',
        )
        .gte('created_at', from.toUtc().toIso8601String())
        .lte('created_at', to.toUtc().toIso8601String())
        .order('created_at') as List<dynamic>;

    if (rows.isEmpty) {
      return StatsData.empty;
    }

    var totalVehicles = 0;
    var totalAmbulance = 0;
    var congSum = 0.0;
    var smooth = 0, normal = 0, jam = 0;

    // 방향별 누적
    final dirVeh = {for (final d in kDirections) d: 0};
    final dirAmb = {for (final d in kDirections) d: 0};
    final dirCongSum = {for (final d in kDirections) d: 0.0};
    final dirCount = {for (final d in kDirections) d: 0};

    // 버킷별 누적: key=버킷 시작시각
    final bVeh = <DateTime, int>{};
    final bCongSum = <DateTime, Map<String, double>>{};
    final bCongCnt = <DateTime, Map<String, int>>{};

    DateTime bucketKey(DateTime t) => hourly
        ? DateTime(t.year, t.month, t.day, t.hour)
        : DateTime(t.year, t.month, t.day);

    for (final raw in rows) {
      final m = (raw as Map).cast<String, dynamic>();
      final dir = (m['direction'] as String?) ?? '';
      final veh = _i(m['vehicle_count']);
      final amb = _i(m['ambulance_count']);
      final cong = _d(m['congestion_percent']);
      final level = (m['congestion_level'] as String?) ?? '';
      final created =
          DateTime.tryParse('${m['created_at']}')?.toLocal() ?? from;

      totalVehicles += veh;
      totalAmbulance += amb;
      congSum += cong;
      switch (level) {
        case '원활':
          smooth++;
          break;
        case '보통':
          normal++;
          break;
        case '혼잡':
          jam++;
          break;
      }

      if (dirVeh.containsKey(dir)) {
        dirVeh[dir] = dirVeh[dir]! + veh;
        dirAmb[dir] = dirAmb[dir]! + amb;
        dirCongSum[dir] = dirCongSum[dir]! + cong;
        dirCount[dir] = dirCount[dir]! + 1;
      }

      final key = bucketKey(created);
      bVeh[key] = (bVeh[key] ?? 0) + veh;
      if (dirVeh.containsKey(dir)) {
        (bCongSum[key] ??= {})[dir] = (bCongSum[key]?[dir] ?? 0) + cong;
        (bCongCnt[key] ??= {})[dir] = (bCongCnt[key]?[dir] ?? 0) + 1;
      }
    }

    final n = rows.length;
    final levelScore = n == 0
        ? 0.0
        : (smooth * 1.0 + normal * 0.6 + jam * 0.2) / n * 100;

    final dirs = kDirections.map((d) {
      final c = dirCount[d]!;
      return DirStat(
        direction: d,
        vehicles: dirVeh[d]!,
        ambulance: dirAmb[d]!,
        avgCongestion: c == 0 ? 0 : dirCongSum[d]! / c,
      );
    }).toList();

    final keys = bVeh.keys.toList()..sort();
    final buckets = keys.map((k) {
      final sums = bCongSum[k] ?? const {};
      final cnts = bCongCnt[k] ?? const {};
      final cong = <String, double>{};
      for (final d in kDirections) {
        final c = cnts[d] ?? 0;
        if (c > 0) cong[d] = (sums[d] ?? 0) / c;
      }
      return StatsBucket(
        start: k,
        totalVehicles: bVeh[k]!,
        congByDir: cong,
      );
    }).toList();

    final result = StatsData(
      totalVehicles: totalVehicles,
      avgCongestion: congSum / n,
      totalAmbulance: totalAmbulance,
      signalEfficiency: levelScore,
      levelSmooth: smooth,
      levelNormal: normal,
      levelJam: jam,
      buckets: buckets,
      dirs: dirs,
      rowCount: n,
      hourly: hourly,
    );
    debugPrint('[StatsRepository] $n rows, ${buckets.length} buckets');
    return result;
  }
}
