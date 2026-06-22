"""
SmartAI 노트북 -> Supabase writer 예시.

설치:  pip install supabase python-dotenv
.env (이 폴더 또는 노트북 작업폴더):
    SUPABASE_URL=https://yboglsatamplbdersejk.supabase.co
    SUPABASE_SERVICE_ROLE=<Supabase 대시보드 Settings > API > service_role 키>

⚠ service_role 키는 RLS를 우회하는 비밀 키입니다.
   노트북에서만 쓰고, 깃/Flutter에는 절대 넣지 마세요.

YOLO 라벨:  0=ambulance_normal(구급차), 1=jetbot(일반)
"""

import os
from datetime import datetime, timezone
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()
sb = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE"])

MAX_VEHICLES = 6      # 차량 혼잡도 기준 최대 대수
MAX_STOP_SEC = 10.0   # 정차 혼잡도 기준 최대 시간


def congestion(vehicle_count, avg_stop_time, left_turn_ratio):
    """수정본 9~10절 혼잡도 계산."""
    vehicle_score = vehicle_count / MAX_VEHICLES * 100
    stop_score = avg_stop_time / MAX_STOP_SEC * 100
    pct = vehicle_score * 0.6 + stop_score * 0.3 + left_turn_ratio * 0.1
    pct = max(0.0, min(100.0, round(pct, 1)))
    level = "원활" if pct < 40 else ("보통" if pct < 70 else "혼잡")
    return pct, level


def push_traffic(direction, normal, ambulance, waiting, avg_stop,
                 straight, left_turn):
    """traffic_status 방향별 현재상태 upsert + congestion_history 적재."""
    vehicle = normal + ambulance
    ratio = round(left_turn / vehicle * 100, 1) if vehicle else 0.0
    pct, level = congestion(vehicle, avg_stop, ratio)

    row = {
        "direction": direction,
        "vehicle_count": vehicle,
        "normal_count": normal,
        "ambulance_count": ambulance,
        "waiting_count": waiting,
        "avg_stop_time": round(avg_stop, 2),
        "straight_count": straight,
        "left_turn_count": left_turn,
        "left_turn_ratio": ratio,
        "congestion_percent": pct,
        "congestion_level": level,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    sb.table("traffic_status").upsert(row, on_conflict="direction").execute()

    # 그래프/통계용 이력 (주기적으로, 예: 1분마다 호출 권장)
    sb.table("congestion_history").insert({
        "direction": direction,
        "vehicle_count": vehicle,
        "normal_count": normal,
        "ambulance_count": ambulance,
        "congestion_percent": pct,
        "congestion_level": level,
    }).execute()
    return pct, level


def push_signal(direction, state, remain, mode="NORMAL"):
    """signal_status 방향별 현재 신호 upsert. state: RED/YELLOW/GREEN."""
    sb.table("signal_status").upsert({
        "direction": direction,
        "signal_state": state,
        "remain_time": remain,
        "control_mode": mode,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }, on_conflict="direction").execute()


def push_emergency(direction, ambulance_count, confidence):
    """구급차 감지 시: 이벤트 로그 + 해당 방향 GREEN/EMERGENCY, 나머지 RED."""
    active = ambulance_count >= 1
    sb.table("emergency_status").insert({
        "detected": active,
        "direction": direction,
        "ambulance_count": ambulance_count,
        "confidence": round(confidence, 3),
        "priority_active": active,
    }).execute()

    if active:
        push_signal(direction, "GREEN", remain=18, mode="EMERGENCY")
        for d in ("north", "south", "east", "west"):
            if d != direction:
                push_signal(d, "RED", remain=0, mode="EMERGENCY")


if __name__ == "__main__":
    # 데모 한 사이클
    push_traffic("north", normal=3, ambulance=1, waiting=2, avg_stop=6.1,
                 straight=2, left_turn=2)
    push_signal("north", "GREEN", remain=20)
    push_emergency("east", ambulance_count=1, confidence=0.94)
    print("pushed.")
