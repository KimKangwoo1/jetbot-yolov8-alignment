# SmartAI — AI 스마트 교통 신호 제어 시스템 (PPT 제작용 정리)

> 본인 담당: **① 웹 대시보드 개발(Flutter Web)** · **② Python 추론·통신 서버** · **③ DB 구축(Supabase)**
> 형식: 각 슬라이드는 "프롬프트 형식"으로 작성 — 그대로 PPT 생성 AI(Gamma 등)에 붙여넣거나 발표 스크립트로 사용 가능.
> 모든 핵심 영역에 **[어려웠던 점] / [핵심 기여·기술] / [해결방법]** 3요소를 명시.

---

## 슬라이드 1 — 프로젝트 개요

**프롬프트:**
"AI 스마트 교통 신호 제어 시스템 'SmartAI'의 표지/개요 슬라이드를 만들어줘. 한 줄 요약: *웹캠 영상을 YOLOv8 + ByteTrack으로 실시간 분석해 방향별 혼잡도·긴급차량을 산출하고, ESP32 신호등을 자동 제어하며, 결과를 Flutter Web 관제 대시보드에 실시간으로 시각화하는 엣지 AI 교통 관제 시스템*."

- **목표**: 교차로 CCTV 1대로 (1) 차량/긴급차량 검지 → (2) 혼잡도 계산 → (3) 신호등 자동 제어 → (4) 관제 대시보드 실시간 표출까지 **단일 파이프라인**으로 구현
- **핵심 컨셉**: **Edge AI · 100% 로컬 운영 · 클라우드 추론 미사용** (영상은 노트북/Jetson에서 직접 추론, Supabase는 "결과 저장소" 역할만)
- **3대 구성요소**
  1. **Python 추론·통신 서버** (`detect_stream.py`, 1,069줄) — 영상 추론 + 신호 제어 + 다중 통신
  2. **Supabase DB** (`smartai-traffic`, 7개 테이블) — 실시간 현황/이력 저장소
  3. **Flutter Web 관제 대시보드** (`app/`, 약 12,000줄, 9개 화면) — 실시간 모니터링·통계·신호제어 UI

---

## 슬라이드 2 — 시스템 아키텍처 / 데이터 흐름

**프롬프트:**
"좌→우 데이터 흐름 다이어그램을 만들어줘. 노드: [웹캠/CCTV] → [노트북·Jetson: YOLOv8+ByteTrack 추론] → 3갈래 분기 → [① ESP32 신호등(HTTP)] / [② Flutter 대시보드(MJPEG 영상 + WebSocket 이벤트)] / [③ Supabase DB(REST 저장)] → [Supabase Realtime] → [Flutter 대시보드 실시간 구독]."

```
                                  ┌─ HTTP GET /signal?state=GREEN ─→ [ESP32 신호등]
                                  │
[웹캠] → [detect_stream.py]  ─────┼─ MJPEG :8080/stream ───────────→ [Flutter <img> 영상]
        YOLOv8 + JetBot.onnx      │─ WebSocket :8765 ──────────────→ [Flutter 검지 배지]
        + ByteTrack 추적          │
                                  └─ service_role 키로 REST upsert → [Supabase DB]
                                                                          │
                                                       publishable 키 ↓ Realtime 구독
                                                                    [Flutter 대시보드]
```

- **3종 통신 채널을 동시에 운용**: HTTP(제어) / MJPEG(영상) / WebSocket(저지연 이벤트) / Supabase Realtime(상태 동기화)
- **역할 분리 원칙**: *계산은 노트북에서, Supabase는 저장만, Flutter는 읽기만* → 보안·확장성 확보
- **권한 분리**: 노트북(쓰기)=`service_role` 비밀키 / Flutter(읽기)=`publishable` 공개키

---

# PART A. Python 추론·통신 서버 (`detect_stream.py`)

## 슬라이드 3 — Python 서버: 단일 프로세스 멀티스레드 설계

**프롬프트:**
"하나의 Python 프로세스가 웹캠을 독점하면서 추론·영상스트리밍·이벤트브로드캐스트·신호제어·DB저장을 모두 처리하는 구조를 설명하는 슬라이드를 만들어줘. 3개 스레드 + Flask 메인으로 구성됨."

- **단일 프로세스가 모든 것을 소유** (웹캠 충돌 방지): 카메라를 한 곳에서만 열고 결과를 여러 채널로 분배
- **스레드 구성 (`threading.Thread`, daemon)**
  - `capture_and_detect()` — 카메라 캡처 + YOLO 추론 + 신호 판단 + 프레임 인코딩 (메인 워커)
  - `run_ws_server()` — asyncio WebSocket 서버(:8765), 검지 이벤트 브로드캐스트
  - `run_supabase_worker()` — DB 저장 전용 워커 (추론 루프 블로킹 방지)
  - **Flask 메인 스레드** — MJPEG 영상 스트림(:8080) 서빙
- **스레드 간 공유 자료구조**: `_latest_jpeg`(최신 프레임 + Lock), `_event_queue`(이벤트 큐), `_supabase_queue`(DB 큐), `_track_state`(트랙별 상태)
- **CLI 인자 25종**: `--camera`, `--conf`, `--roi-threshold`, `--signal-source`, `--no-signal`, `--no-supabase` 등으로 모듈별 on/off 및 튜닝 가능

## 슬라이드 4 — Python 서버: 이중 모델 추론 + ByteTrack 추적

**프롬프트:**
"두 개의 YOLO 모델을 동시에 돌리는 검지 파이프라인 슬라이드. 일반 차량(yolov8n.pt)과 커스텀 JetBot/구급차(JetBot_Last.onnx)를 각각 추론하고 ByteTrack으로 ID를 부여해 추적함."

- **이중 모델 동시 추론**
  - `yolov8n.pt` — 일반 차량(car/truck/bus/motorcycle)
  - `JetBot_Last.onnx` — 커스텀 학습 모델(구급차 `output_ambulance_normal` / 일반 `output_jetbot`)
- **ByteTrack 멀티오브젝트 추적** (`model.track(persist=True, tracker="bytetrack.yaml")`) → 객체마다 고유 `track_id` 부여
- **track_id 기반 지표 산출** (`update_track_metrics`):
  - **속도**(px/s) = 프레임 간 중심점 이동거리 / Δt
  - **정차시간**(stop_time) = 정지 속도 이하로 머문 누적 시간
  - **체류시간**(dwell) = ROI 진입 후 경과 시간
  - **교통량**(traffic_volume) = 최근 60초 ROI 통과 트랙 수 (슬라이딩 윈도우)
- **stale 트랙 정리**: 2초 이상 미검출 트랙은 통과 처리 후 상태 삭제 → 메모리 누수 방지

## 슬라이드 5 — Python 서버: ROI 기반 혼잡도 계산 알고리즘

**프롬프트:**
"검지구역(ROI)별 혼잡도를 0~100점으로 계산하는 가중치 공식 슬라이드. 대기열·지연·속도 3요소를 가중합하고 3단계로 분류함."

- **ROI(Region of Interest)**: 영상 내 방향별 검지구역(top/left/right/bottom), `roi_config.json`으로 좌표 설정
- **혼잡도 공식 (`calculate_congestion`)**
  ```
  queue_score = min(차량수 / 6, 1) × 100        # 대기열 점수
  delay_score = min(평균정차시간 / 10, 1) × 100  # 지연 점수
  speed_score = (1 − min(평균속도 / 80, 1)) × 100 # 속도 점수
  혼잡도 = queue_score×0.4 + delay_score×0.4 + speed_score×0.2
  ```
- **3단계 분류**: `0~34 원활(LOW) / 35~69 보통(MEDIUM) / 70~100 혼잡(HIGH)`
- **ROI명 → 방위(north/south/east/west) 자동 매핑** (`direction_for_roi`): 이름 키워드 우선, 없으면 중심좌표로 추정
- **방향별 중복 제거** (`dedupe_by_direction`): 같은 방향 ROI 여럿이면 혼잡도 최대값 1건만 upsert → DB 무결성 보장

## 슬라이드 6 — Python 서버: ESP32 신호등 자동 제어

**프롬프트:**
"ROI 차량 수에 따라 ESP32 신호등을 RED↔GREEN 자동 전환하는 제어 로직 슬라이드. 채터링 방지를 위한 안정화 로직과 황색 경유 전환을 강조."

- **제어 방식**: HTTP GET `http://{ESP32_IP}/signal?state=GREEN` (timeout 0.7s)
- **판단**: ROI 내 차량 수 ≥ 임계값(`--roi-threshold`) → GREEN, 미만 → RED
- **채터링(깜빡임) 방지 — `get_stable_signal`**: 같은 신호가 **1초 이상 안정적으로 유지**될 때만 실제 전환 (노이즈성 깜빡임 억제)
- **안전 전환 — `change_signal_with_yellow`**: RED↔GREEN 직접 전환 금지, 반드시 **YELLOW 0.5초 경유**, 최소 전환 간격 1초 강제
- **긴급차량 우선**: 구급차 검지 시 해당 방향 강제 GREEN, 나머지 RED (writer 예시의 `push_emergency` 로직)

## 슬라이드 7 — Python 서버: 3채널 동시 통신

**프롬프트:**
"하나의 추론 결과를 MJPEG·WebSocket·Supabase 3채널로 동시에 내보내는 통신 설계 슬라이드. 각 채널의 목적과 비블로킹 처리를 설명."

- **① MJPEG (Flask, :8080)** — `multipart/x-mixed-replace` 로 검지 박스가 그려진 영상 송출. 브라우저 `<img>`가 그대로 렌더 (별도 코덱 불필요)
- **② WebSocket (asyncio, :8765)** — 검지/신호/혼잡 이벤트를 JSON으로 **저지연 푸시**. `_event_queue` → `ws_broadcaster`가 전 클라이언트에 `asyncio.gather`로 동시 전송
- **③ Supabase REST** — `traffic_status`(현황 upsert) + `congestion_history`(이력 insert)
- **비블로킹 설계 (핵심)**: 추론 루프가 네트워크 I/O에 막히지 않도록 **throttle + 별도 큐 + 워커 스레드**로 분리. 큐가 밀리면 `get_nowait()`로 **최신 프레임만 남기고 과거 프레임 버림**

---

# PART B. DB 구축 (Supabase `smartai-traffic`)

## 슬라이드 8 — DB: 프로젝트 설계 및 권한 분리

**프롬프트:**
"Supabase 기반 교통 DB의 보안 아키텍처 슬라이드. 쓰기는 노트북(service_role), 읽기는 Flutter(publishable)로 키를 분리하고 RLS로 보호함."

- **전용 프로젝트**: `smartai-traffic` (ref `yboglsatamplbdersejk`, 서울 리전 `ap-northeast-2`) — 기존 육아일기 프로젝트와 **완전 분리**
- **키 2종 분리 (보안 핵심)**
  - **쓰기**(노트북): `service_role` 비밀키 → RLS 우회, **`.env`로만 주입, 코드/깃에 절대 미포함**
  - **읽기**(Flutter): `publishable` 공개키 → 읽기 전용
- **RLS(Row Level Security)**: anon은 traffic/signal/emergency/congestion **읽기 전용**, `incidents`만 CRUD 허용
- **Realtime 활성 테이블**: `traffic_status`, `signal_status`, `emergency_status` → Flutter `.stream()` 구독 시 즉시 푸시

## 슬라이드 9 — DB: 7개 테이블 스키마

**프롬프트:**
"교통 관제 DB의 7개 테이블을 핵심4 + 보조3으로 나눠 표로 정리하는 슬라이드. 각 테이블의 역할과 갱신 방식(upsert/append)을 명시."

| 테이블 | 역할 | 갱신 방식 |
| --- | --- | --- |
| `traffic_status` | 방향별 **현재** 교통상태(4행) | `direction` 기준 **upsert** |
| `signal_status` | 방향별 **현재** 신호등 상태(4행) | `direction` **upsert** |
| `emergency_status` | 구급차 감지 **이벤트 로그** | **append**(최신행=현재) |
| `congestion_history` | 시간대별 혼잡도 **이력** | **append**(통계·그래프용) |
| `incidents` | 사건/티켓 칸반(new/in_progress/resolved) | anon **CRUD** |
| `intersections` / `cameras` | 교차로·카메라(MJPEG/WS URL, ROI) 설정 | 설정값 |

- **CHECK 제약으로 데이터 무결성 강제**: `direction`∈{north,south,east,west}, `congestion_level`∈{원활,보통,혼잡}, `signal_state`∈{RED,YELLOW,GREEN}, `control_mode`∈{NORMAL,CONGESTION,EMERGENCY}
- **실시간 현황(upsert) vs 누적 이력(insert) 이원화**: 대시보드 즉답성과 통계 분석을 동시 충족

---

# PART C. 웹 대시보드 (Flutter Web, 9개 화면)

## 슬라이드 10 — 웹: 전체 구조 및 상태관리

**프롬프트:**
"Flutter Web 관제 대시보드의 앱 셸 구조 슬라이드. 사이드바 7화면 + 헤더(교차로 선택·키오스크·리플레이) + 단일 진실원천 LiveData 상태관리."

- **앱 셸**(`app_shell.dart`): 좌측 사이드바(7화면) + 상단 헤더 + 본문(AnimatedSwitcher 전환) + 하단 타임라인
- **키보드 단축키**: 1~7(화면 이동), F(전체화면), K(키오스크), R(리플레이), Shift+?(도움말)
- **상태관리 — 단일 진실원천(Single Source of Truth)**: `LiveData`(ChangeNotifier) 하나가 모든 실시간 값(방향별 교통량/신호/긴급/KPI) 보유 → 모든 화면이 `ListenableBuilder`로 구독
- **연결 대기 UX**: 첫 스냅샷 도착 전엔 `connected=false` → 모든 패널이 `WaitingBox`(펄스 점) 표시. 데이터를 가짜로 채우지 않고 "대기 중"을 정직하게 노출

## 슬라이드 11 — 웹: Supabase Realtime 연동 (읽기 브리지)

**프롬프트:**
"Supabase Realtime 3테이블 구독 → LiveData로 흘려보내는 브리지 슬라이드. 부분 갱신과 KPI 집계, 자동 재연결 처리를 강조."

- **`SupabaseService`**: `traffic_status`·`signal_status`·`emergency_status` 3개 테이블 `.stream()` 구독 → 변경 시 `LiveData.applySnapshot()` 호출
- **부분 갱신 지원**: 인자 null이면 기존값 유지 → 테이블별 개별 갱신 가능
- **KPI 자동 집계**: 4방향 행에서 총차량/평균정차/전체혼잡도 즉석 계산
- **장애 대응**: 스트림 onError 시 `setDisconnected()` → UI가 즉시 "연결 끊김" 표시
- **읽기 전용 원칙 준수**: 대시보드는 publishable 키로 **쓰기 일절 안 함**(incidents 제외)

## 슬라이드 12 — 웹: MJPEG 영상 + WebSocket 검지 (Flutter Web 통합)

**프롬프트:**
"Flutter Web에서 노트북 MJPEG 영상을 네이티브 <img>로 임베드하고 WebSocket으로 검지 배지를 띄우는 크로스플랫폼 통합 슬라이드. 가장 까다로웠던 웹 통합 포인트."

- **MJPEG 임베드** (`webcam_feed.dart`): Flutter엔 MJPEG 위젯이 없어 **`dart:ui_web`의 `platformViewRegistry`로 네이티브 `<img>` 엘리먼트를 등록** → `HtmlElementView`로 렌더. 브라우저가 multipart JPEG를 자동 디코딩
- **URL별 고유 viewType** (`mjpeg-${url.hashCode}`)로 중복 등록 방지
- **WebSocket 검지 배지**: `web_socket_channel`로 `ws://` 연결 → 검지 JSON 수신 → "감지됨 · person 95%" 배지 표출(3초 후 자동 소멸), **2초 자동 재연결**
- **웹 전용 헬퍼**(`web_helpers.dart`): `dart:html`로 전체화면 토글 + 설정 JSON/CSV **브라우저 다운로드**(Blob + Object URL + 가상 anchor click)

## 슬라이드 13 — 웹: 9개 화면 구성

**프롬프트:**
"관제 대시보드의 9개 화면을 한 장에 표로 정리하는 슬라이드. 각 화면의 목적·데이터소스·핵심 시각화."

| 화면 | 목적 | 데이터 소스 | 핵심 시각화 |
| --- | --- | --- | --- |
| 실시간 모니터링 | 종합 관제 | LiveData + MJPEG | CCTV + 방향별 게이지 + 긴급/혼잡 패널 |
| 교통 현황 | 흐름 분석 | LiveData KPI | KPI 스트립 + CCTV + 혼잡 순위/트렌드 |
| 신호 제어 | 신호 운영 | LiveData.signals | 4방향 교차로 도식 + 8단계 위상 + 수동/긴급 모드 |
| 긴급차량 우선 | 긴급 추적 | LiveData/실시간 | CCTV 추적 + ETA + 차로 조정 현황 |
| 사건 관리 | 티켓 칸반 | IncidentBoard / incidents | 3열 칸반(신규/처리중/해결) + 생성·처리 다이얼로그 |
| 통계 분석 | 기간 분석 | StatsRepository(congestion_history) | fl_chart 교통량/혼잡 추이 + 신호효율 + 방향별 표 |
| 시스템 설정 | 환경 설정 | 로컬 폼 + ROI/카메라 마법사 | 카메라·검지·신호타이밍·네트워크·API/웹훅 |
| ROI 에디터 | 검지영역 편집 | 사용자 입력 | CustomPaint 폴리곤(탭 추가/드래그 이동/더블탭 삭제) |
| 키오스크 뷰 | 상황실 표출 | LiveData | 대형 CCTV + 혼잡 ArcGauge + 신호 상태 |

## 슬라이드 14 — 웹: 통계 분석 (기간 집계)

**프롬프트:**
"congestion_history를 기간 조회해 시간/일 단위 버킷으로 집계하고 fl_chart로 시각화하는 통계 화면 슬라이드. 신호효율 지표 도출 방식 포함."

- **실시간 구독과 분리**: 통계는 `StatsRepository.fetch(start,end)`로 **기간 1회 조회**(realtime 아님)
- **자동 버킷팅**: 1일 이내=시간단위, 초과=일단위로 집계 구간 자동 결정
- **fl_chart 시각화**: 교통량 LineChart(면적 채움) + 방향별 4선 혼잡 추이
- **신호효율(%) 도출**: 혼잡단계 분포 가중평균 `(원활×1.0 + 보통×0.6 + 혼잡×0.2)/N × 100`
- **정직한 N/A 처리**: 스키마에 없는 속도·긴급대응시간은 가짜로 채우지 않고 `_KpiNa`로 "미지원" 표기

---

# 핵심 종합 — 어려웠던 점 / 핵심 기여 / 해결방법

## 슬라이드 15 — 어려웠던 점 (Challenges)

**프롬프트:**
"프로젝트에서 실제로 부딪힌 기술적 난관 6가지를 아이콘과 함께 정리하는 슬라이드."

1. **단일 웹캠을 여러 소비자(영상·이벤트·DB·제어)가 동시에 필요** → 카메라 자원 충돌·블로킹 위험
2. **추론 루프가 네트워크 I/O(DB/WS)에 막히면 영상이 끊김** → 실시간성 저하
3. **Flutter Web에는 MJPEG/RTSP 영상 위젯이 없음** → 영상 임베드 자체가 난제
4. **신호등 깜빡임(채터링)**: 검지 노이즈로 RED↔GREEN이 1초에도 여러 번 바뀜 → 실제 신호기에 치명적
5. **DB 보안**: 노트북은 써야 하고 웹은 읽어야 하는데, 비밀키가 웹/깃에 노출되면 DB 전체 탈취 위험
6. **같은 방향에 ROI가 여러 개**면 `direction` upsert가 충돌 → DB 무결성 깨짐

## 슬라이드 16 — 핵심 기여 · 기술 (Key Contributions)

**프롬프트:**
"본인이 설계·구현한 핵심 기술 기여를 임팩트 있게 나열하는 슬라이드."

- **엔드투엔드 파이프라인 단독 설계**: 영상 추론 → 지표 계산 → 신호 제어 → DB 저장 → 웹 시각화까지 **하나의 흐름으로 통합**
- **멀티스레드 + 다중 프로토콜 통신 서버**: HTTP/MJPEG/WebSocket/Supabase REST **4종 채널 동시 운용**(`detect_stream.py` 1,069줄)
- **ByteTrack 기반 정량 지표 엔진**: track_id로 속도·정차시간·교통량을 산출하고 **3요소 가중 혼잡도 알고리즘** 구현
- **권한 분리형 DB 아키텍처**: service_role(쓰기)/publishable(읽기) + RLS + CHECK 제약으로 **안전한 7테이블 스키마** 설계
- **실시간 관제 웹 대시보드**: 9개 화면, Supabase Realtime 단일 진실원천 상태관리, fl_chart 통계, 키오스크/리플레이 모드
- **Flutter Web ↔ 네이티브 브라우저 통합**: platformViewRegistry로 MJPEG 임베드, dart:html로 전체화면·파일 다운로드

## 슬라이드 17 — 해결방법 (Solutions) ★ 발표 하이라이트

**프롬프트:**
"슬라이드 15의 난관 6가지를 각각 어떤 기법으로 해결했는지 1:1로 매칭하는 슬라이드. 문제→해결 형식."

| # | 문제 | 해결방법 |
| --- | --- | --- |
| 1 | 웹캠 자원 충돌 | **단일 프로세스가 카메라 독점** + 결과를 공유 버퍼/큐로 분배(`_latest_jpeg`+Lock, `_event_queue`) |
| 2 | 추론 루프 블로킹 | DB/WS를 **별도 워커 스레드 + 큐**로 분리, **throttle**(1s/10s) + 밀리면 `get_nowait()`로 **최신값만 사용** |
| 3 | Flutter Web MJPEG 불가 | `dart:ui_web platformViewRegistry`로 **네이티브 `<img>` 등록 후 HtmlElementView 렌더**, URL별 고유 viewType |
| 4 | 신호 채터링 | **안정화 로직**(`get_stable_signal`, 1초 유지 시만 전환) + **황색 0.5초 경유** + 최소 전환간격 1초 |
| 5 | DB 키 노출 위험 | **키 2종 분리** — 비밀키는 `.env`로만, 공개키는 읽기 전용, **RLS + CHECK 제약** 이중 방어 |
| 6 | 방향 upsert 충돌 | **`dedupe_by_direction`** — 같은 방향이면 혼잡도 최대 1건만 남겨 upsert 무결성 보장 |

---

## 슬라이드 18 — 기술 스택 요약

**프롬프트:**
"사용 기술을 영역별로 묶어 한 장에 정리하는 마무리 슬라이드."

- **AI/추론**: Python, OpenCV, Ultralytics YOLOv8, 커스텀 ONNX(JetBot/구급차), ByteTrack
- **서버/통신**: Flask(MJPEG), websockets(asyncio), requests(ESP32 HTTP), threading/Queue
- **하드웨어 제어**: ESP32 신호등 (HTTP 엔드포인트)
- **DB**: Supabase(PostgreSQL) — REST, Realtime, RLS, service_role/publishable 키 분리
- **웹 프론트엔드**: Flutter Web(Dart), supabase_flutter, web_socket_channel, fl_chart, youtube_player_iframe, dart:html / dart:ui_web
- **규모**: Python 1,069줄 · Flutter 약 12,000줄(9화면 + 11위젯) · DB 7테이블

---

### 부록 — 발표 시 강조 포인트 (한 줄 요약)
> "저는 **영상 한 장이 신호등을 움직이고 관제 화면에 뜨기까지의 모든 길**을 직접 깔았습니다. 추론 서버의 멀티스레드 통신, 권한을 분리한 DB, 그리고 실시간으로 반응하는 웹 대시보드 — **3계층을 하나의 파이프라인으로 연결**한 것이 핵심 기여입니다."
