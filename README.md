# 지능형 CCTV 기반 도로교통 관제 및 긴급차량 우선 신호 제어

> YOLO와 ByteTrack으로 차량 흐름을 분석하고 긴급차량 감지 시 ESP32 신호등에 우선 신호를 제공하는 실시간 교통 관제 시스템

카메라 영상, Python 통신 서버, Flutter Web 대시보드, Supabase, ESP32 신호등을 하나의 실시간 파이프라인으로 통합한 캡스톤 프로젝트입니다.

## 핵심 기능

- YOLOv8 기반 일반 차량·긴급차량 탐지
- ByteTrack 기반 차량 ID 추적
- 방향별 ROI의 차량 수·정지시간·속도 저하 분석
- V/C·정지시간·속도 저하를 결합한 혼잡도 산정
- 긴급차량 접근 방향 우선 신호 제어
- MJPEG 스트리밍과 WebSocket 데이터 동기화
- Supabase 교통 상태 저장
- ESP32 NeoPixel 신호등 HTTP 제어

## 시스템 구조

```text
Camera → YOLOv8 → ByteTrack → ROI Traffic Analysis
                                      ▼
                               Python Server
                    ┌──────────┬──────────┬──────────┐
                  MJPEG     WebSocket   Supabase   ESP32
                    └──────── Flutter Web ───────────┘
```

## 혼잡도와 우선 신호

```text
Congestion Score =
V/C Score × 0.40 + Stop Time Score × 0.40 + Speed Drop Score × 0.20
```

혼잡도 60점 이상이 3초간 유지되면 황색을 거쳐 녹색 신호로 전환합니다. 긴급차량은 일반 혼잡도보다 우선하며, 통과하거나 일정 시간 미감지되면 일반 제어로 복귀합니다.

## 모델 성능

| 지표 | 결과 |
|---|---:|
| Precision | 0.996 |
| Recall | 0.991 |
| mAP50 | 0.995 |
| mAP50-95 | 0.928 |

일반 JetBot 약 7,000장과 긴급차량 JetBot 약 8,000장의 데이터를 구축하고 YOLOv8n을 50 epoch 학습했습니다.

## 담당 역할

### 황준용

- Flutter(SmartAI) 대시보드 전체 파이프라인 설계
- Supabase 데이터베이스 구축
- Python 통신 서버 구축
- MJPEG·WebSocket·실시간 교통 데이터 연동
- 팀 시스템 통합과 시연 지원

### 팀 협업

- 노효준: 데이터 수집·YOLO 모델 학습, 긴급차량 제작, 혼잡도 설계, Dashboard–Jetson 통신 지원
- 김강우: 데이터 수집·모델 학습, Jetson Nano 최적화, 긴급차량 하드웨어 연동, JetBot 팔로잉
- 오정훈: ESP32 신호등, ROI 혼잡도, 우선 신호 로직, 스트리밍·신호 제어 통합

## 문제 해결

### Flutter Web의 MJPEG 미지원

PlatformView로 MJPEG 스트림을 연결하고 WebSocket과 상태 관리를 분리해 영상과 교통 데이터를 즉시 갱신했습니다.

### 한 프로세스에 처리가 몰려 3 FPS까지 저하

입력 해상도와 추론 간격을 조정하고 Intel CPU 환경에 맞춰 OpenVINO를 적용해 약 **16 FPS**까지 개선했습니다.

### ESP32 회로 자료 부재

NeoPixel 주소 지정 방식임을 확인하고 LED 번호를 직접 매핑해 HTTP 신호 제어를 구현했습니다.

```text
GPIO 12
RED 0-20 / YELLOW 21-41 / LEFT 42-50 / GREEN 51-71
```

## 실행

```powershell
cd hyojun_streamer
pip install -r requirements.txt
python detect_stream.py --camera 1 --esp32-ip 192.168.0.162
```

선택 옵션:

```powershell
python detect_stream.py --camera 1 --esp32-ip 192.168.0.162 --no-overlay
python detect_stream.py --camera 1 --esp32-ip 192.168.0.162 --no-supabase
```

## 주요 경로

```text
hyojun_streamer/detect_stream.py
hyojun_streamer/JetBot_Last_openvino_model/
hyojun_streamer/roi_config.json
app/lib/
esp32_signal_light_server/esp32_signal_light_server.ino
```

## 환경 변수

```text
SUPABASE_URL=your_project_url
SUPABASE_KEY=your_key
SUPABASE_TABLE=traffic_status
```

> API 키와 서비스 키는 저장소에 커밋하지 마세요.

## 향후 개선

- 다양한 주행 환경 데이터 추가
- 영상과 사이렌 음성을 결합한 긴급차량 판별
- 혼잡도와 긴급도를 함께 반영한 신호 제어 고도화
- Jetson Nano 온디바이스 추론과 대시보드 연동 강화

## 회고

실시간 AI 시스템은 모델 정확도뿐 아니라 추론 속도, 스트리밍, 상태 동기화, 데이터 저장, 하드웨어 제어가 함께 맞아야 완성된다는 점을 배웠습니다.
