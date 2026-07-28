# SmartAI Supabase DB

AI 스마트 교통 신호 대시보드용 데이터베이스. **육아일기 프로젝트와 분리된 전용 Supabase 프로젝트**입니다.

| 항목 | 값 |
| --- | --- |
| 프로젝트명 | `smartai-traffic` |
| Project ref | `yboglsatamplbdersejk` |
| 리전 | `ap-northeast-2` (서울) |
| URL | `https://yboglsatamplbdersejk.supabase.co` |
| publishable 키(공개·읽기) | `sb_publishable_FahLqMYu7Avej_lHMsbUig_kkALGy7C` |

## 역할 분담

```
노트북(YOLOv8+ByteTrack)  --service_role 키--> Supabase  --publishable 키--> Flutter 대시보드
        (계산 + 저장)                          (저장소)              (조회만)
```

- **계산은 노트북에서.** Supabase는 계산하지 않고 결과만 저장.
- **쓰기**(노트북): `service_role`(secret) 키 사용 → RLS 우회. 이 키는 Supabase 대시보드
  `Settings → API → service_role`에서 복사해 노트북 `.env`에만 둡니다. **절대 Flutter/깃에 넣지 않음.**
- **읽기**(Flutter): 위 publishable 키로 읽기만. `incidents`만 대시보드에서 직접 CRUD 가능.

## 테이블 (7개)

핵심 4개 (수정본 스펙):
- `traffic_status` — 방향별 **현재** 교통 상태 (north/south/east/west 4행, `direction` 기준 upsert)
- `signal_status` — 방향별 **현재** 신호등 상태 (4행, `direction` upsert)
- `emergency_status` — 구급차 감지 **이벤트 로그** (append, 최신행=현재상태, `detected_at` 정렬)
- `congestion_history` — 시간대별 혼잡도 **기록** (append, 통계/그래프용)

추가 3개:
- `incidents` — 사건/티켓 칸반 (new/in_progress/resolved)
- `intersections` / `cameras` — 교차로·카메라(MJPEG/WS URL, ROI) 설정

> 실시간(Realtime) 활성화 테이블: `traffic_status`, `signal_status`, `emergency_status`
> → Flutter에서 `.stream()` 으로 구독 시 즉시 푸시됨.

### CHECK 제약 (저장 시 이 값만 허용)
- `direction`: `north` | `south` | `east` | `west`
- `congestion_level`: `원활` | `보통` | `혼잡`
- `signal_state`: `RED` | `YELLOW` | `GREEN`
- `control_mode`: `NORMAL` | `CONGESTION` | `EMERGENCY`
- `incidents.severity`: `critical|high|medium|low|info`, `incidents.status`: `new|in_progress|resolved`

## 혼잡도 계산식 (노트북에서)
```
vehicle_score   = vehicle_count / 6 * 100
stop_score      = avg_stop_time / 10 * 100
left_turn_score = left_turn_ratio
congestion_percent = vehicle_score*0.6 + stop_score*0.3 + left_turn_score*0.1
```
단계: `0~39 원활`, `40~69 보통`, `70~100 혼잡`

## 긴급차량 우선
`ambulance_count >= 1` → 해당 방향 `signal_status.control_mode='EMERGENCY'`, `signal_state='GREEN'`,
나머지 방향 `RED`. + `emergency_status` 에 감지 이벤트 insert.

## 노트북 writer 예시
`writer_example.py` 참고 (upsert/insert 패턴).
