// ============================================================
// SmartAI 전용 Supabase 프로젝트 접속 정보.
//
// 이 프로젝트는 육아일기(auto_baby_diary)와 완전히 분리된
// 별도 Supabase 프로젝트("smartai-traffic")입니다.
//
// 여기 들어가는 키는 anon/publishable 키(공개용, 읽기 전용)입니다.
// 절대로 service_role(secret) 키를 이 파일에 넣지 마세요 —
// 그건 노트북 writer(Python)에서만, .env 로만 사용합니다.
// ============================================================

class SupabaseConfig {
  /// Supabase 프로젝트 REST/Realtime URL
  static const String url = 'https://yboglsatamplbdersejk.supabase.co';

  /// publishable(공개) 키 — Flutter Web 대시보드는 이 키로 "읽기"만 합니다.
  /// (RLS: 대시보드 anon = traffic/signal/emergency/congestion 읽기 전용,
  ///  incidents 만 anon CRUD 허용)
  static const String anonKey = 'sb_publishable_FahLqMYu7Avej_lHMsbUig_kkALGy7C';

  // 테이블 이름 상수 (오타 방지용)
  static const String tTrafficStatus = 'traffic_status';
  static const String tSignalStatus = 'signal_status';
  static const String tEmergencyStatus = 'emergency_status';
  static const String tCongestionHistory = 'congestion_history';
  static const String tIncidents = 'incidents';
  static const String tIntersections = 'intersections';
  static const String tCameras = 'cameras';
}
