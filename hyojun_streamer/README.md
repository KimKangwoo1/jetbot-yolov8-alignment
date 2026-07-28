# Hyojun Smart Traffic Streamer

This folder contains the final runtime files for the JetBot smart traffic-light demo.

## Main Features

- Webcam MJPEG stream on port 8080
- WebSocket event stream on port 8765
- JetBot and ambulance detection with YOLO/OpenVINO
- ByteTrack object ID tracking
- ROI-based congestion scoring
- Emergency vehicle priority control
- ESP32 traffic-light control over Wi-Fi
- Overlay on/off controls for the stream

## Run

```powershell
cd C:\hyojun_streamer\hyojun_streamer
python detect_stream.py --camera 1
```

If the internal camera is selected instead of the USB webcam, try:

```powershell
python detect_stream.py --camera 0
```

## Stream URLs

Local:

```text
http://localhost:8080/stream
```

Other devices on the same network:

```text
http://<notebook-ip>:8080/stream
```

## Overlay Controls

Hide boxes and text:

```text
http://localhost:8080/overlay?enabled=0
```

Show boxes and text:

```text
http://localhost:8080/overlay?enabled=1
```

## Signal Logic

Priority order:

```text
1. Emergency vehicle priority
2. Congestion-based control
3. Default RED
```

Congestion score:

```text
congestion = vc_score * 0.40 + delay_score * 0.40 + speed_score * 0.20
```

Emergency vehicle priority:

```text
confidence >= 0.50
stable for 3 frames
inside an approach ROI
moving toward the intersection
```

Then the signal changes:

```text
YELLOW for 3 seconds -> GREEN
```

