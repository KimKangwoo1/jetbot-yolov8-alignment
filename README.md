# 🏎️ JetBot Autonomous Driving Object Detection Project

> **YOLOv8 기반의 탑다운 뷰 트랙 환경 젯봇(JetBot) 실시간 객체 인식 및 임베디드 최적화 프로젝트**

본 프로젝트는 고정된 시점(Top-down)의 트랙 환경에서 젯봇을 정밀하게 탐지하고 실시간 자율주행 알고리즘의 기반을 다지기 위한 딥러닝 프로젝트입니다. 소형 임베디드 장비인 **Jetson Nano**에서의 실시간 추론(FPS) 성능을 극대화하기 위해 모델 경량화 및 ONNX 포맷 변환을 적용했습니다.

---

## 📌 Key Features (주요 특징)
- **YOLOv8 Nano 모델 활용**: 젯슨 나노 환경을 고려하여 73레이어 수준의 가벼운 `yolov8n` 아키텍처 채택
- **맞춤형 데이터 증강 기법**: 탑다운 고정 뷰의 도메인 특성을 반영한 왜곡 없는 데이터 Augmentation 적용
- **엣지 디바이스 최적화**: `320x320` 정적 입력 크기 지정 및 ONNX 포맷 변환을 통한 TensorRT 가속 준비

---

## 📊 Dataset & Data Augmentation (데이터셋 및 데이터 증강)
- **데이터 규모**: 직접 수집 및 라벨링한 총 **1,500장**의 고품질 이미지 데이터셋 (YOLO Format)
- **데이터 비율**: Train (70%) / Validation (15%) / Test (15%) 분할

### 💡 도메인 맞춤형 증강 전략 (Augmentation Strategy)
트랙의 환경적 특성을 분석하여 무작위 증강 대신 **실제 주행 시 발생할 수 있는 변수**에 초점을 맞추어 증강을 설계했습니다.
1. **밝기 및 명도 조절 (`hsv_v=0.4`)**: 실내 형광등이나 외부 조명 변화에 강인하게 대처
2. **미세 회전 및 이동 (`degrees=10.0`, `translate=0.05`)**: 카메라의 물리적 흔들림 및 앵글 오차 극복
3. **랜덤 영역 가리기 (`erasing=0.3`)**: 젯봇의 바퀴나 센서 일부가 그림자/장애물에 가려져도 안정적으로 인식
4. **⚠️ 공간 변형 제한**: 트랙의 주행 방향 지시 표지판 훼손 및 데이터 꼬임을 방지하기 위해 **상하/좌우 반전(`flip`) 및 입체 왜곡(`perspective`)은 엄격히 제외**

📥 **[데이터셋 다운로드 (Google Drive 링크)](https://drive.google.com/file/d/1vsepicWAhhaF5HFvT4Pa50SG-lE9RdF8/view?usp=drive_link)** *(※ 데이터셋은 용량 관계상 외부 링크로 공유합니다. 다운로드 후 `dataset.yaml` 경로를 맞춰 사용하세요.)*

---

## 📈 Training Results (학습 결과)
- **Epochs**: 150 (Early Stopping 적용으로 검증 손실 수렴 시 조기 종료 설정)
- **Batch Size**: 16
- **mAP50 성능**: 약 **99%** 달성 (트랙 위 젯봇의 위치를 거의 완벽하게 추론함)

![Training Results](./results.png)  
*(상기 그래프를 통해 Train/Val Loss가 안정적으로 우하향하며, mAP 성능이 무결하게 수렴함을 확인할 수 있습니다.)*

---

## 🚀 Jetson Nano Deployment (임베디드 배포 방법)
젯슨 나노의 하드웨어 한계를 극복하기 위해 입력 해상도를 320으로 최적화하여 ONNX 파일로 변환을 완료했습니다.

### 1. ONNX 파일 구조
- **Input Shape**: `(1, 3, 320, 320)` BCHW 고정
- **Model Weight**: `best.onnx` (11.6 MB 경량화 완료)

### 2. Jetson Nano 환경 내 TensorRT (.engine) 최종 변환 명령어
젯슨 나노에 내장된 엔비디아 가속 도구를 사용하여 무거운 PyTorch 연산을 C++ 기반의 하드웨어 최적화 가속 엔진으로 컴파일합니다.
```bash
trtexec --onnx=best.onnx --saveEngine=best.engine --fp16

---

## Smart Traffic Signal Control Integration

기존 JetBot 객체 인식 프로젝트를 확장하여, 웹캠 영상 기반 교통 혼잡 감지와 긴급차량 우선 신호 제어 기능을 통합했습니다.

최종 시스템은 Windows 노트북과 USB 웹캠 환경에서 실행되며, YOLOv8 / OpenVINO 모델로 일반 JetBot과 긴급차량 JetBot을 인식합니다. 이후 ByteTrack으로 차량 ID를 추적하고, 방향별 ROI 영역의 교통 상태를 분석하여 ESP32 NeoPixel 신호등과 Flutter Web Dashboard로 결과를 전달합니다.

### Key Features

- YOLOv8 / OpenVINO 기반 일반 JetBot 및 긴급차량 JetBot 인식
- ByteTrack 기반 차량 ID 추적
- 방향별 ROI 영역의 차량 수, 평균 정지시간, 속도저하 계산
- V/C, 정지시간, 속도저하 기반 혼잡도 산정
- 긴급차량 감지 시 일반 혼잡도보다 우선하여 신호 제어
- ESP32 NeoPixel 신호등 Wi-Fi HTTP 제어
- MJPEG 방식 실시간 영상 스트리밍
- WebSocket 기반 감지 이벤트 송출
- Supabase 교통 상태 저장 및 Flutter Web Dashboard 연동

### System Architecture

```text
USB Webcam
  ↓
YOLOv8 Object Detection
  ↓
ByteTrack ID Tracking
  ↓
ROI Traffic Analysis
  ├─ Vehicle Count
  ├─ Average Stop Time
  └─ Speed Drop
  ↓
Congestion Decision / Emergency Vehicle Priority
  ↓
Python Server
  ├─ MJPEG Streaming
  ├─ WebSocket Events
  ├─ Supabase Update
  └─ ESP32 Signal Control
  ↓
Flutter Web Dashboard / ESP32 Traffic Light
```

### 📊 Congestion Score (혼잡도 점수)

혼잡도는 실제 교통 분석에서 사용하는 V/C 비율, 제어지체, 평균속도 개념을 소형 JetBot 트랙 환경에 맞게 정규화하여 계산했습니다.

```text
Congestion Score =
V/C Score × 0.40
+ Stop Time Score × 0.40
+ Speed Drop Score × 0.20
```

```text
V/C Score       = ROI 안 차량 수 / ROI 최대 수용 차량 수
Stop Time Score = 차량 ID별 평균 정지시간 / 기준 정지시간
Speed Drop Score = 자유주행속도 대비 현재 평균속도 감소율
```

Default configuration:

```text
ROI 최대 수용 차량 수: 6
기준 정지시간: 10초
자유주행속도: 80 px/s
신호 변경 기준: 혼잡도 60점 이상
안정 감지 시간: 3초
```

혼잡도 점수가 기준 이상으로 3초 이상 유지되면 다음 순서로 신호를 변경합니다.

```text
YELLOW 3초 → GREEN
```

### 🚑 Emergency Vehicle Priority (긴급차량 우선 신호 제어)

긴급차량은 일반 혼잡도 판단보다 우선 적용됩니다. 긴급차량이 안정적으로 감지되면 우선 신호를 부여하고, 차량이 통과했거나 일정 시간 감지되지 않으면 일반 혼잡도 기반 제어로 복귀합니다.

```text
Ambulance confidence threshold: 0.50
Stable detection frames: 3
Minimum priority hold time: 5초
Lost timeout: 2초
Maximum green time: 10초
```

### 🚦 ESP32 Traffic Light Control (ESP32 신호등 제어)

ESP32 신호등은 NeoPixel LED 배열로 구성되어 있으며, HTTP 요청을 통해 신호 상태를 변경합니다.

```text
LED data pin: GPIO 12

RED    = 0 ~ 20
YELLOW = 21 ~ 41
LEFT   = 42 ~ 50
GREEN  = 51 ~ 71
```

Signal control request:

```text
http://<esp32-ip>/signal?state=GREEN
```

### 📡 Streaming and Dashboard (영상 송출 및 대시보드 연동)

```text
Video stream: http://localhost:8080/stream
Event stream: ws://localhost:8765
```

Overlay control:

```text
http://localhost:8080/overlay?enabled=0
http://localhost:8080/overlay?enabled=1
```

Supabase `traffic_status` table fields:

```text
direction
vehicle_count
ambulance_count
jetbot_count
avg_stop_time
traffic_volume
congestion_level
signal_state
emergency
updated_at
```

`.env` example:

```text
SUPABASE_URL=your_supabase_project_url
SUPABASE_KEY=your_supabase_key
SUPABASE_TABLE=traffic_status
```

주의: `.env` 파일에는 Supabase Key가 포함되므로 GitHub에 업로드하지 않습니다.

### 🚀 Run (실행 방법)

```powershell
cd hyojun_streamer
pip install -r requirements.txt
python detect_stream.py --camera 1 --esp32-ip 192.168.0.162
```

Run without overlay:

```powershell
python detect_stream.py --camera 1 --esp32-ip 192.168.0.162 --no-overlay
```

Run without Supabase update:

```powershell
python detect_stream.py --camera 1 --esp32-ip 192.168.0.162 --no-supabase
```

### 📁 Files (관련 파일)

```text
hyojun_streamer/detect_stream.py
hyojun_streamer/JetBot_Last_openvino_model/
hyojun_streamer/JetBot_Last.onnx
hyojun_streamer/classes.txt
hyojun_streamer/data.yaml
hyojun_streamer/roi_config.json
hyojun_streamer/requirements.txt
esp32_signal_light_server/esp32_signal_light_server.ino
```

### 🛠️ Troubleshooting (문제 해결 기록)

- ESP32 신호등은 제조사 펌웨어와 회로 자료가 없어 NeoPixel 제어 방식과 LED 번호 범위를 직접 확인했습니다.
- 노트북 내장 카메라가 선택되는 경우 `--camera` 옵션으로 USB 웹캠 인덱스를 지정합니다.
- CPU 환경에서 ONNX 모델 실행 시 프레임이 크게 떨어져 OpenVINO 모델을 적용했습니다.
- ESP32와 노트북은 같은 Wi-Fi에 연결되어야 하며, HTTP 직접 요청으로 신호등 동작을 검증할 수 있습니다.
- Supabase `traffic_status` 테이블은 `direction` 기준 upsert 방식으로 기존 방향 데이터를 갱신합니다.
