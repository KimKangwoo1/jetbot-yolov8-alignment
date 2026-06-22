import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'live_data.dart';
import 'supabase_config.dart';

// ============================================================
// Supabase realtime → LiveData 브리지.
//
// traffic_status / signal_status / emergency_status 테이블을 realtime 구독해
// 변경이 생길 때마다 LiveData.applySnapshot 으로 흘려보냅니다.
// 대시보드는 읽기만 하므로(publishable 키) 여기서 쓰기는 하지 않습니다.
//
// 사용:
//   await SupabaseService.ensureInitialized();   // main()에서 1회
//   SupabaseService.instance.start();            // 구독 시작
// ============================================================

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  /// main()에서 runApp 전에 1회 호출.
  static Future<void> ensureInitialized() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // 우리가 쓰는 키는 publishable(sb_publishable_...) 키.
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  SupabaseClient get _sb => Supabase.instance.client;
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    _subs.add(
      _sb
          .from(SupabaseConfig.tTrafficStatus)
          .stream(primaryKey: ['id']).listen(_onTraffic, onError: _onError),
    );
    _subs.add(
      _sb
          .from(SupabaseConfig.tSignalStatus)
          .stream(primaryKey: ['id']).listen(_onSignal, onError: _onError),
    );
    _subs.add(
      _sb
          .from(SupabaseConfig.tEmergencyStatus)
          .stream(primaryKey: ['id'])
          .order('detected_at')
          .limit(20)
          .listen(_onEmergency, onError: _onError),
    );
  }

  void _onError(Object e, [StackTrace? st]) {
    debugPrint('[SupabaseService] stream error: $e');
    LiveData.instance.setDisconnected();
  }

  void _onTraffic(List<Map<String, dynamic>> rows) {
    DirectionLive? pick(String d) {
      for (final r in rows) {
        if (r['direction'] == d) return DirectionLive.fromMap(r);
      }
      return null;
    }

    final n = pick('north');
    final s = pick('south');
    final e = pick('east');
    final w = pick('west');

    final all = [n, s, e, w].whereType<DirectionLive>().toList();
    TrafficKpisLive? kpis;
    if (all.isNotEmpty) {
      final total = all.fold<int>(0, (a, b) => a + b.vehicleCount);
      final wait =
          all.fold<double>(0, (a, b) => a + b.avgStopTime) / all.length;
      final cong =
          all.fold<double>(0, (a, b) => a + b.congestionPercent) /
              all.length /
              100;
      kpis = TrafficKpisLive(
        totalVehicles: total,
        avgWaitSec: wait,
        avgSpeedKmh: 0,
        overallCongestion: cong.clamp(0, 1),
      );
    }

    LiveData.instance
        .applySnapshot(north: n, south: s, east: e, west: w, kpis: kpis);
  }

  void _onSignal(List<Map<String, dynamic>> rows) {
    final map = <String, SignalLive>{};
    for (final r in rows) {
      final sig = SignalLive.fromMap(r);
      if (sig.direction.isNotEmpty) map[sig.direction] = sig;
    }
    LiveData.instance.applySnapshot(signals: map);
  }

  void _onEmergency(List<Map<String, dynamic>> rows) {
    // order('detected_at') 오름차순 → 최신이 마지막. 뒤집어서 감지된 것만 추림.
    final list = rows
        .map(EmergencyLive.fromMap)
        .toList()
        .reversed
        .where((x) => x.detected)
        .take(5)
        .toList();
    LiveData.instance.applySnapshot(emergencies: list);
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _started = false;
  }
}
