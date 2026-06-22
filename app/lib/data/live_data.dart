import 'package:flutter/foundation.dart';

// ============================================================
// Central live-data layer.
//
// This is the SINGLE source of truth for every real-time value the
// dashboard shows (방향별 교통량, 신호 상태, 긴급차량, KPI …).
//
// 데이터 출처는 Supabase(smartai-traffic 프로젝트)입니다. 노트북
// (YOLOv8+ByteTrack)이 계산 결과를 Supabase에 저장하면, [SupabaseService]가
// traffic_status / signal_status / emergency_status 테이블을 realtime 구독해
// 여기로 [applySnapshot] 을 호출합니다.
//
// 첫 스냅샷이 오기 전에는 [connected] 가 false 이고 모든 값이 null/empty 라,
// UI 는 "연결 대기 중" 상태를 보여줍니다.
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

/// Live metrics for one approach (direction) of an intersection.
/// `traffic_status` 테이블 한 행에 대응.
class DirectionLive {
  final int vehicleCount; // 전체 차량 수
  final int normalCount; // 일반 JetBot 수
  final int ambulanceCount; // 구급차 수
  final int waitingCount; // 정차 차량 수
  final double avgStopTime; // 평균 정차 시간(초)
  final int straightCount; // 직진 수
  final int leftTurnCount; // 좌회전 수
  final double leftTurnRatio; // 좌회전 비율(%)
  final double congestionPercent; // 혼잡도(0..100)
  final String congestionLevel; // 원활 / 보통 / 혼잡

  const DirectionLive({
    required this.vehicleCount,
    required this.normalCount,
    required this.ambulanceCount,
    required this.waitingCount,
    required this.avgStopTime,
    required this.straightCount,
    required this.leftTurnCount,
    required this.leftTurnRatio,
    required this.congestionPercent,
    required this.congestionLevel,
  });

  factory DirectionLive.fromMap(Map<String, dynamic> m) => DirectionLive(
        vehicleCount: _i(m['vehicle_count']),
        normalCount: _i(m['normal_count']),
        ambulanceCount: _i(m['ambulance_count']),
        waitingCount: _i(m['waiting_count']),
        avgStopTime: _d(m['avg_stop_time']),
        straightCount: _i(m['straight_count']),
        leftTurnCount: _i(m['left_turn_count']),
        leftTurnRatio: _d(m['left_turn_ratio']),
        congestionPercent: _d(m['congestion_percent']),
        congestionLevel: (m['congestion_level'] as String?) ?? '원활',
      );

  /// 혼잡도 0..1 (기존 위젯 호환용).
  double get congestion => (congestionPercent / 100).clamp(0, 1);

  /// 정차 차량 수 (기존 위젯의 queue 호환용).
  int get queue => waitingCount;

  /// 평균 정차 시간 (기존 위젯의 avgWaitSec 호환용).
  double get avgWaitSec => avgStopTime;
}

/// Aggregate top-line KPIs — 4방향 traffic_status 로부터 계산.
class TrafficKpisLive {
  final int totalVehicles;
  final double avgWaitSec; // 평균 정차 시간
  final double avgSpeedKmh; // 스키마에 속도 없음 → 0 (추후 확장)
  final double overallCongestion; // 0..1
  const TrafficKpisLive({
    required this.totalVehicles,
    required this.avgWaitSec,
    required this.avgSpeedKmh,
    required this.overallCongestion,
  });
}

/// 한 방향의 신호등 상태. `signal_status` 테이블 한 행에 대응.
class SignalLive {
  final String direction; // north | south | east | west
  final String signalState; // RED | YELLOW | GREEN
  final int remainTime; // 남은 시간(초)
  final String controlMode; // NORMAL | CONGESTION | EMERGENCY
  const SignalLive({
    required this.direction,
    required this.signalState,
    required this.remainTime,
    required this.controlMode,
  });

  factory SignalLive.fromMap(Map<String, dynamic> m) => SignalLive(
        direction: (m['direction'] as String?) ?? '',
        signalState: (m['signal_state'] as String?) ?? 'RED',
        remainTime: _i(m['remain_time']),
        controlMode: (m['control_mode'] as String?) ?? 'NORMAL',
      );
}

/// 구급차 감지 이벤트. `emergency_status` 테이블 한 행에 대응.
class EmergencyLive {
  final bool detected;
  final String? direction;
  final int ambulanceCount;
  final double confidence;
  final bool priorityActive;
  final DateTime? detectedAt;
  const EmergencyLive({
    required this.detected,
    required this.direction,
    required this.ambulanceCount,
    required this.confidence,
    required this.priorityActive,
    required this.detectedAt,
  });

  factory EmergencyLive.fromMap(Map<String, dynamic> m) => EmergencyLive(
        detected: (m['detected'] as bool?) ?? false,
        direction: m['direction'] as String?,
        ambulanceCount: _i(m['ambulance_count']),
        confidence: _d(m['confidence']),
        priorityActive: (m['priority_active'] as bool?) ?? false,
        detectedAt: DateTime.tryParse('${m['detected_at']}')?.toLocal(),
      );
}

class LiveData extends ChangeNotifier {
  LiveData._();
  static final LiveData instance = LiveData._();

  bool _connected = false;

  /// True once at least one snapshot has been received from Supabase.
  bool get connected => _connected;

  // --- live values (null/empty until the backend sends them) ---
  DirectionLive? north;
  DirectionLive? east;
  DirectionLive? south;
  DirectionLive? west;
  TrafficKpisLive? kpis;

  /// 방향(north/south/east/west) → 현재 신호 상태.
  Map<String, SignalLive> signals = const {};

  /// 최근 구급차 감지 이벤트 (감지된 것만, 최신순).
  List<EmergencyLive> emergencies = const [];

  bool get hasDirections =>
      north != null && east != null && south != null && west != null;

  SignalLive? signalFor(String direction) => signals[direction];

  /// 현재 긴급(우선신호) 활성 여부.
  bool get emergencyActive =>
      emergencies.any((e) => e.priorityActive) ||
      signals.values.any((s) => s.controlMode == 'EMERGENCY');

  /// Feed a fresh snapshot. Any argument left null keeps the previous value,
  /// so partial updates (테이블별 개별 갱신) are fine.
  void applySnapshot({
    DirectionLive? north,
    DirectionLive? east,
    DirectionLive? south,
    DirectionLive? west,
    TrafficKpisLive? kpis,
    Map<String, SignalLive>? signals,
    List<EmergencyLive>? emergencies,
  }) {
    if (north != null) this.north = north;
    if (east != null) this.east = east;
    if (south != null) this.south = south;
    if (west != null) this.west = west;
    if (kpis != null) this.kpis = kpis;
    if (signals != null) this.signals = signals;
    if (emergencies != null) this.emergencies = emergencies;
    _connected = true;
    notifyListeners();
  }

  /// Drop all live data — called when the Supabase connection is lost.
  void setDisconnected() {
    _connected = false;
    north = east = south = west = null;
    kpis = null;
    signals = const {};
    emergencies = const [];
    notifyListeners();
  }
}
