# -*- coding: utf-8 -*-
"""
Webcam YOLO streamer plus ESP32 traffic-light control.

One process owns the webcam and does everything:
  - MJPEG video stream for the Flutter dashboard
  - WebSocket detection events
  - vehicle detection with yolov8n.pt
  - custom JetBot/ambulance detection with JetBot_Last.onnx
  - ByteTrack tracking IDs for dashboard metrics
  - ROI congestion scoring
  - ROI counting and ESP32 signal control
"""

import argparse
import asyncio
import json
import os
import socket
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from queue import Empty, Queue

import cv2
import requests
import websockets
from flask import Flask, Response
from ultralytics import YOLO

try:
    from supabase import create_client
except ImportError:
    create_client = None  # pip install supabase 안 했으면 자동 비활성화


BASE_DIR = Path(__file__).resolve().parent

CAMERA_INDEX = 0
FRAME_WIDTH = 1280
FRAME_HEIGHT = 720
JPEG_QUALITY = 70
MJPEG_PORT = 8080
WS_PORT = 8765

ESP32_IP = "192.168.0.162"
ESP32_TIMEOUT = 0.7

# Supabase (smartai-traffic). URL은 비밀이 아니라 기본값으로 박아두고,
# KEY는 절대 코드에 넣지 말고 환경변수로만 받는다. RLS 때문에 service_role 키 필요.
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://yboglsatamplbdersejk.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")  # Dashboard > Settings > API > service_role
SUPABASE_TABLE = "traffic_status"          # 방향별 실시간 현황 (direction unique -> upsert)
SUPABASE_HISTORY_TABLE = "congestion_history"  # 혼잡도 누적 로그 (append)
SUPABASE_WRITE_INTERVAL = 1.0              # traffic_status upsert 최소 간격(초)
SUPABASE_HISTORY_INTERVAL = 10.0           # congestion_history append 간격(초)

VEHICLE_MODEL_PATH = BASE_DIR / "yolov8n.pt"
JETBOT_MODEL_PATH = BASE_DIR / "JetBot_Last.onnx"
CLASSES_PATH = BASE_DIR / "classes.txt"
ROI_CONFIG_PATH = BASE_DIR / "roi_config.json"
TRACKER_CONFIG = "bytetrack.yaml"

VEHICLE_CLASSES = {"car", "truck", "bus", "motorcycle"}
DEFAULT_JETBOT_CLASSES = {"output_ambulance_normal", "output_jetbot"}
AMBULANCE_CLASSES = {"output_ambulance_normal"}
JETBOT_CLASSES = {"output_jetbot"}
DEFAULT_ROIS = [
    ("top_center", 530, 72, 617, 211),
    ("left_middle", 208, 204, 405, 288),
    ("right_middle", 628, 212, 869, 306),
    ("bottom_center", 504, 312, 637, 530),
]

CONF_THRES = 0.45
EVENT_MIN_INTERVAL = 1.0
JETBOT_THRESHOLD = 1
STABLE_DETECTION_TIME = 1.0
MIN_SIGNAL_INTERVAL = 1.0
YELLOW_TIME = 0.5
CONGESTION_MAX_VEHICLES = 6
CONGESTION_MAX_STOP_TIME = 10.0
CONGESTION_FREE_FLOW_SPEED = 80.0
CONGESTION_STOP_SPEED = 12.0
TRACK_STALE_SECONDS = 2.0
TRAFFIC_VOLUME_WINDOW = 60.0


_latest_jpeg = None
_latest_lock = threading.Lock()
_event_queue: "Queue[dict]" = Queue()
_last_emit = {}
_track_state = {}
_traffic_passages = {}

_supabase_client = None
_supabase_queue: "Queue[list]" = Queue()
_last_supabase_enqueue = 0.0

current_signal = "RED"
last_signal_time = 0.0
pending_signal = "RED"
pending_signal_since = time.time()
last_log_time = 0.0


def load_class_file(path):
    if not path.exists():
        print("[YOLO] classes.txt not found. Using default custom classes.")
        return set(DEFAULT_JETBOT_CLASSES)

    names = {
        line.strip().lower()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip()
    }
    return names or set(DEFAULT_JETBOT_CLASSES)


def load_rois(path):
    if not path.exists():
        print("[ROI] roi_config.json not found. Using built-in ROIs.")
        return list(DEFAULT_ROIS)

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        rois = [
            (item["name"], int(item["x1"]), int(item["y1"]), int(item["x2"]), int(item["y2"]))
            for item in data["rois"]
        ]
    except Exception as exc:
        print(f"[ROI] failed to read {path}: {exc}. Using built-in ROIs.")
        return list(DEFAULT_ROIS)

    print(f"[ROI] using {len(rois)} ROI(s): {path}")
    return rois


def default_camera_from_roi_config(path, fallback):
    if not path.exists():
        return fallback

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return int(data.get("camera_index", fallback))
    except Exception:
        return fallback


def load_model(path, label, task=None):
    if not path.exists():
        print(f"[YOLO] {label} model not found, skipping: {path}")
        return None

    print(f"[YOLO] loading {label}: {path}")
    if task:
        model = YOLO(str(path), task=task)
    else:
        model = YOLO(str(path))
    print(f"[YOLO] {label} classes: {model.names}")
    return model


def model_class_name(model, cls_id):
    names = getattr(model, "names", {})
    if isinstance(names, dict):
        return str(names.get(cls_id, cls_id)).lower()
    if isinstance(names, list) and 0 <= cls_id < len(names):
        return str(names[cls_id]).lower()
    return str(cls_id)


def open_camera(camera_index):
    cap = cv2.VideoCapture(camera_index, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_HEIGHT)
    return cap


def send_signal(state, esp32_ip):
    url = f"http://{esp32_ip}/signal?state={state}"
    try:
        response = requests.get(url, timeout=ESP32_TIMEOUT)
        print(f"[ESP32] {state} -> {response.text}")
        return True
    except Exception as exc:
        print(f"[ESP32] signal send failed: {exc}")
        return False


def change_signal_with_yellow(target_signal, esp32_ip):
    global current_signal, last_signal_time

    now = time.time()
    if current_signal == target_signal:
        return
    if now - last_signal_time < MIN_SIGNAL_INTERVAL:
        return

    print(f"[SIGNAL CHANGE] {current_signal} -> YELLOW -> {target_signal}")
    send_signal("YELLOW", esp32_ip)
    current_signal = "YELLOW"
    time.sleep(YELLOW_TIME)

    send_signal(target_signal, esp32_ip)
    current_signal = target_signal
    last_signal_time = time.time()


def get_stable_signal(raw_signal):
    global pending_signal, pending_signal_since

    now = time.time()
    if raw_signal == current_signal:
        pending_signal = raw_signal
        pending_signal_since = now
        return raw_signal

    if pending_signal != raw_signal:
        pending_signal = raw_signal
        pending_signal_since = now
        return None

    if now - pending_signal_since >= STABLE_DETECTION_TIME:
        return raw_signal

    return None


def get_roi_for_point(x, y, rois):
    for name, x1, y1, x2, y2 in rois:
        if x1 <= x <= x2 and y1 <= y <= y2:
            return name
    return None


def utc_timestamp():
    return datetime.now(timezone.utc).isoformat()


def direction_for_roi(roi):
    roi_name, x1, y1, x2, y2 = roi
    lowered = roi_name.lower()

    if "north" in lowered or "top" in lowered:
        return "north"
    if "south" in lowered or "bottom" in lowered:
        return "south"
    if "west" in lowered or "left" in lowered:
        return "west"
    if "east" in lowered or "right" in lowered:
        return "east"

    center_x = (x1 + x2) / 2
    center_y = (y1 + y2) / 2

    if center_y < FRAME_HEIGHT * 0.35:
        return "north"
    if center_y > FRAME_HEIGHT * 0.55:
        return "south"
    if center_x < FRAME_WIDTH * 0.5:
        return "west"
    return "east"


def emit_detection(name, conf, source, roi_name=None, track_id=None):
    now = time.time()
    object_key = track_id if track_id is not None else name
    key = f"{source}:{object_key}:{roi_name or 'out'}"
    if now - _last_emit.get(key, 0) < EVENT_MIN_INTERVAL:
        return

    _last_emit[key] = now
    evt = {
        "type": "detection",
        "object": name,
        "confidence": round(conf, 3),
        "source": source,
        "roi": roi_name,
        "trackId": track_id,
        "ts": now,
    }
    _event_queue.put(evt)
    print(f"[DETECT] {evt}")


def emit_signal_state(raw_signal, roi_count, total_count, status):
    now = time.time()
    if now - _last_emit.get("signal-status", 0) < EVENT_MIN_INTERVAL:
        return

    _last_emit["signal-status"] = now
    _event_queue.put(
        {
            "type": "signal",
            "signal": current_signal,
            "rawSignal": raw_signal,
            "roiCount": roi_count,
            "totalCount": total_count,
            "status": status,
            "ts": now,
        }
    )


def emit_congestion_state(summary, roi_metrics, supabase_rows):
    now = time.time()
    if now - _last_emit.get("congestion-status", 0) < EVENT_MIN_INTERVAL:
        return

    _last_emit["congestion-status"] = now
    summary_row = next(
        (row for row in supabase_rows if row["direction"] == summary["direction"]),
        None,
    )
    _event_queue.put(
        {
            "type": "congestion",
            "score": summary["score"],
            "level": summary["level"],
            "roi": summary["roi"],
            "direction": summary["direction"],
            "formula": "queue_score*0.4 + delay_score*0.4 + speed_score*0.2",
            "rois": roi_metrics,
            "supabaseRow": summary_row,
            "supabaseRows": supabase_rows,
            "ts": now,
        }
    )


def init_supabase():
    """환경변수로 Supabase 클라이언트를 만든다. 패키지/키 없으면 비활성화."""
    global _supabase_client
    if create_client is None:
        print("[SUPABASE] supabase 패키지 없음 -> 저장 비활성화 (pip install supabase)")
        return None
    if not SUPABASE_KEY:
        print("[SUPABASE] SUPABASE_KEY 환경변수 비어있음 -> 저장 비활성화")
        return None
    try:
        _supabase_client = create_client(SUPABASE_URL, SUPABASE_KEY)
        print(f"[SUPABASE] connected: {SUPABASE_URL} -> {SUPABASE_TABLE}")
    except Exception as exc:
        print(f"[SUPABASE] init failed: {exc}")
        _supabase_client = None
    return _supabase_client


def to_traffic_status_row(row):
    """calculate_congestion이 만든 row -> traffic_status 컬럼으로 매핑."""
    return {
        "direction": row["direction"],
        "vehicle_count": row["vehicle_count"],
        "normal_count": max(row["vehicle_count"] - row["ambulance_count"], 0),
        "ambulance_count": row["ambulance_count"],
        "waiting_count": row["vehicle_count"],
        "straight_count": row["vehicle_count"],
        "left_turn_count": 0,
        "left_turn_ratio": 0,
        "jetbot_count": row["jetbot_count"],
        "avg_stop_time": row["avg_stop_time"],
        "traffic_volume": row["traffic_volume"],
        "congestion_percent": row["congestion"],   # 이름 다름: congestion -> congestion_percent
        "congestion_level": row["congestion_level"],
        "signal_state": row["signal_state"],
        "emergency": row["emergency"],
        "updated_at": row["updated_at"],
    }


def to_congestion_history_row(row):
    return {
        "direction": row["direction"],
        "vehicle_count": row["vehicle_count"],
        "normal_count": max(row["vehicle_count"] - row["ambulance_count"], 0),
        "ambulance_count": row["ambulance_count"],
        "congestion_percent": row["congestion"],
        "congestion_level": row["congestion_level"],
    }


def dedupe_by_direction(rows):
    """같은 방향 ROI가 여러 개여도 upsert가 깨지지 않도록 방향당 1건(혼잡도 최대)만."""
    best = {}
    for row in rows:
        direction = row["direction"]
        if direction not in best or row["congestion"] > best[direction]["congestion"]:
            best[direction] = row
    return list(best.values())


def enqueue_supabase(supabase_rows):
    """캡처 루프를 막지 않도록 throttle 후 워커 큐에 넘긴다."""
    global _last_supabase_enqueue
    if _supabase_client is None or not supabase_rows:
        return
    now = time.time()
    if now - _last_supabase_enqueue < SUPABASE_WRITE_INTERVAL:
        return
    _last_supabase_enqueue = now
    _supabase_queue.put(supabase_rows)


def run_supabase_worker():
    """별도 스레드: 큐에서 최신 row를 받아 traffic_status upsert + history append."""
    last_history = 0.0
    while True:
        rows = _supabase_queue.get()
        # 밀려있으면 가장 최근 것만 사용 (오래된 프레임 버림)
        try:
            while True:
                rows = _supabase_queue.get_nowait()
        except Empty:
            pass

        if _supabase_client is None or not rows:
            continue

        rows = dedupe_by_direction(rows)
        now = time.time()
        try:
            _supabase_client.table(SUPABASE_TABLE).upsert(
                [to_traffic_status_row(r) for r in rows],
                on_conflict="direction",
            ).execute()
        except Exception as exc:
            print(f"[SUPABASE] {SUPABASE_TABLE} upsert failed: {exc}")

        if now - last_history >= SUPABASE_HISTORY_INTERVAL:
            last_history = now
            try:
                _supabase_client.table(SUPABASE_HISTORY_TABLE).insert(
                    [to_congestion_history_row(r) for r in rows]
                ).execute()
            except Exception as exc:
                print(f"[SUPABASE] {SUPABASE_HISTORY_TABLE} insert failed: {exc}")


def box_track_id(box):
    track_id = getattr(box, "id", None)
    if track_id is None:
        return None

    try:
        return int(track_id[0])
    except Exception:
        try:
            return int(track_id)
        except Exception:
            return None


def collect_detections(frame, model, target_classes, source, conf_thres, tracker_config, use_tracking):
    detections = []
    if model is None:
        return detections

    if use_tracking:
        results = model.track(
            frame,
            conf=conf_thres,
            verbose=False,
            persist=True,
            tracker=tracker_config,
        )[0]
    else:
        results = model.predict(frame, conf=conf_thres, verbose=False)[0]

    for box in results.boxes:
        cls_id = int(box.cls[0])
        name = model_class_name(model, cls_id)
        conf = float(box.conf[0])

        if target_classes and name not in target_classes:
            continue

        x1, y1, x2, y2 = map(int, box.xyxy[0])
        center_x = (x1 + x2) // 2
        center_y = (y1 + y2) // 2
        detections.append(
            {
                "box": (x1, y1, x2, y2),
                "center": (center_x, center_y),
                "name": name,
                "confidence": conf,
                "source": source,
                "track_id": box_track_id(box),
                "roi": None,
            }
        )
    return detections


def source_matches(source, selected_source):
    return selected_source == "all" or source == selected_source


def count_roi_detections(detections):
    tracked = set()
    untracked_count = 0

    for detection in detections:
        if detection["roi"] is None:
            continue

        track_id = detection.get("track_id")
        if track_id is None:
            untracked_count += 1
        else:
            tracked.add((detection["source"], track_id))

    return len(tracked) + untracked_count


def record_roi_passage(roi_name, now):
    if not roi_name:
        return
    _traffic_passages.setdefault(roi_name, []).append(now)


def prune_traffic_passages(now, window_seconds):
    cutoff = now - window_seconds
    for roi_name in list(_traffic_passages):
        _traffic_passages[roi_name] = [
            ts for ts in _traffic_passages[roi_name] if ts >= cutoff
        ]
        if not _traffic_passages[roi_name]:
            del _traffic_passages[roi_name]


def traffic_volume_for_roi(roi_name):
    return len(_traffic_passages.get(roi_name, []))


def count_class_detections(detections, class_names):
    return count_roi_detections(
        [detection for detection in detections if detection["name"] in class_names]
    )


def update_track_metrics(detections, args):
    now = time.time()
    seen_keys = set()

    for detection in detections:
        track_id = detection.get("track_id")
        detection["speed_px_s"] = None
        detection["dwell_s"] = 0.0
        detection["stop_time_s"] = 0.0

        if track_id is None:
            continue

        key = (detection["source"], track_id)
        seen_keys.add(key)
        center = detection["center"]
        roi_name = detection["roi"]
        state = _track_state.get(key)

        if state is None:
            state = {
                "first_seen": now,
                "last_seen": now,
                "last_center": center,
                "last_roi": roi_name,
                "roi_entered_at": now if roi_name else None,
                "speed_px_s": None,
                "stop_time_s": 0.0,
            }
        else:
            dt = max(now - state["last_seen"], 0.001)
            last_x, last_y = state["last_center"]
            speed = (((center[0] - last_x) ** 2 + (center[1] - last_y) ** 2) ** 0.5) / dt
            state["speed_px_s"] = speed

            if state["last_roi"] != roi_name:
                record_roi_passage(state["last_roi"], now)
                state["roi_entered_at"] = now if roi_name else None
                state["stop_time_s"] = 0.0

            if roi_name and speed <= args.congestion_stop_speed:
                state["stop_time_s"] += dt

            state["last_seen"] = now
            state["last_center"] = center
            state["last_roi"] = roi_name

        detection["speed_px_s"] = state["speed_px_s"]
        if roi_name and state.get("roi_entered_at") is not None:
            detection["dwell_s"] = now - state["roi_entered_at"]
            detection["stop_time_s"] = state["stop_time_s"]

        _track_state[key] = state

    stale_keys = [
        key
        for key, state in _track_state.items()
        if now - state["last_seen"] > TRACK_STALE_SECONDS and key not in seen_keys
    ]
    for key in stale_keys:
        record_roi_passage(_track_state[key]["last_roi"], now)
        del _track_state[key]

    prune_traffic_passages(now, args.traffic_volume_window)


def congestion_level(score):
    if score >= 70:
        return "HIGH"
    if score >= 35:
        return "MEDIUM"
    return "LOW"


def congestion_level_ko(level):
    if level == "HIGH":
        return "혼잡"
    if level == "MEDIUM":
        return "보통"
    return "원활"


def calculate_congestion(rois, detections, args):
    roi_metrics = []
    supabase_rows = []
    updated_at = utc_timestamp()

    for roi in rois:
        roi_name = roi[0]
        roi_detections = [
            detection
            for detection in detections
            if detection["roi"] == roi_name
            and source_matches(detection["source"], args.congestion_source)
        ]

        count = count_roi_detections(roi_detections)
        ambulance_count = count_class_detections(roi_detections, AMBULANCE_CLASSES)
        jetbot_count = count_class_detections(roi_detections, JETBOT_CLASSES)
        traffic_volume = traffic_volume_for_roi(roi_name)
        stop_values = [d["stop_time_s"] for d in roi_detections if d.get("track_id") is not None]
        speed_values = [
            d["speed_px_s"]
            for d in roi_detections
            if d.get("speed_px_s") is not None
        ]

        avg_stop_time = sum(stop_values) / len(stop_values) if stop_values else 0.0
        avg_speed = sum(speed_values) / len(speed_values) if speed_values else None

        queue_score = min(count / max(args.congestion_max_vehicles, 1), 1.0) * 100.0
        delay_score = min(avg_stop_time / max(args.congestion_max_stop_time, 0.1), 1.0) * 100.0
        if avg_speed is None or count == 0:
            speed_score = 0.0
        else:
            speed_score = (
                1.0 - min(avg_speed / max(args.congestion_free_flow_speed, 0.1), 1.0)
            ) * 100.0

        score = round(
            min(queue_score * 0.4 + delay_score * 0.4 + speed_score * 0.2, 100.0),
            1,
        )
        level = congestion_level(score)
        level_ko = congestion_level_ko(level)
        direction = direction_for_roi(roi)
        row = {
            "direction": direction,
            "vehicle_count": count,
            "ambulance_count": ambulance_count,
            "jetbot_count": jetbot_count,
            "avg_stop_time": round(avg_stop_time, 2),
            "traffic_volume": traffic_volume,
            "congestion": score,
            "congestion_level": level_ko,
            "signal_state": current_signal,
            "emergency": ambulance_count > 0,
            "updated_at": updated_at,
        }
        supabase_rows.append(row)
        roi_metrics.append(
            {
                "roi": roi_name,
                "direction": direction,
                "count": count,
                "score": score,
                "level": level,
                "levelKo": level_ko,
                "queueScore": round(queue_score, 1),
                "delayScore": round(delay_score, 1),
                "speedScore": round(speed_score, 1),
                "avgStopTimeSec": round(avg_stop_time, 2),
                "avgSpeedPxSec": round(avg_speed, 2) if avg_speed is not None else None,
                "trafficVolume": traffic_volume,
                "ambulanceCount": ambulance_count,
                "jetbotCount": jetbot_count,
                "vehicleCount": count,
                "emergency": ambulance_count > 0,
                "signalState": current_signal,
                "supabase": row,
            }
        )

    if not roi_metrics:
        return {"score": 0.0, "level": "LOW", "direction": None, "roi": None}, [], []

    summary = max(roi_metrics, key=lambda item: item["score"])
    return {
        "score": summary["score"],
        "level": summary["level"],
        "direction": summary["direction"],
        "roi": summary["roi"],
    }, roi_metrics, supabase_rows


def draw_detection(frame, detection):
    x1, y1, x2, y2 = detection["box"]
    center_x, center_y = detection["center"]
    name = detection["name"]
    conf = detection["confidence"]
    source = detection["source"]
    roi_name = detection["roi"]
    track_id = detection.get("track_id")

    if source == "jetbot":
        color = (0, 255, 0) if roi_name else (120, 120, 120)
    else:
        color = (0, 200, 255)

    label_prefix = roi_name if roi_name else source
    cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
    cv2.circle(frame, (center_x, center_y), 4, color, -1)
    cv2.putText(
        frame,
        f"{label_prefix} {name}#{track_id if track_id is not None else '-'} {conf:.2f}",
        (x1, max(20, y1 - 8)),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.55,
        color,
        2,
    )


def congestion_color(level):
    if level == "HIGH":
        return (0, 0, 255)
    if level == "MEDIUM":
        return (0, 255, 255)
    return (0, 200, 0)


def draw_rois(frame, rois, congestion_by_roi=None):
    congestion_by_roi = congestion_by_roi or {}

    for roi_name, x1, y1, x2, y2 in rois:
        metric = congestion_by_roi.get(roi_name)
        color = congestion_color(metric["level"]) if metric else (0, 0, 255)
        label = roi_name
        if metric:
            label = f"{roi_name} {metric['level']} {metric['score']}"

        cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
        cv2.putText(
            frame,
            label,
            (x1, max(20, y1 - 8)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            color,
            2,
        )


def draw_status(
    frame,
    roi_count,
    total_count,
    raw_signal,
    status,
    camera_index,
    rois,
    tracking_enabled,
    congestion_summary,
):
    lines = [
        f"ROI Count: {roi_count} / Threshold: {JETBOT_THRESHOLD}",
        f"Total: {total_count} / Status: {status} / Raw: {raw_signal} / Current: {current_signal}",
        f"Camera: {camera_index} / ROIs: {len(rois)} active / Stream+Signal",
        f"Tracking: {'ByteTrack' if tracking_enabled else 'OFF'}",
        f"Congestion: {congestion_summary['level']} {congestion_summary['score']} / ROI: {congestion_summary['roi']}",
    ]

    for index, text in enumerate(lines):
        cv2.putText(
            frame,
            text,
            (30, 40 + index * 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (0, 255, 255),
            2,
        )


def update_signal_from_roi(roi_count, total_count, args):
    global last_log_time

    if roi_count >= args.roi_threshold:
        raw_target_signal = "GREEN"
        status = "ROI THRESHOLD"
    else:
        raw_target_signal = "RED"
        status = "NORMAL"

    stable_target_signal = get_stable_signal(raw_target_signal)
    if stable_target_signal is not None and not args.no_signal:
        change_signal_with_yellow(stable_target_signal, args.esp32_ip)

    now = time.time()
    if now - last_log_time >= 0.5:
        print(
            f"ROI Count: {roi_count}, Total: {total_count}, "
            f"Raw Target: {raw_target_signal}, Current: {current_signal}"
        )
        last_log_time = now

    emit_signal_state(raw_target_signal, roi_count, total_count, status)
    return raw_target_signal, status


def capture_and_detect(args):
    global _latest_jpeg

    vehicle_model = None
    jetbot_model = None

    if not args.no_vehicles:
        vehicle_model = load_model(Path(args.vehicle_model), "vehicle")

    if not args.no_jetbot:
        jetbot_model = load_model(Path(args.jetbot_model), "jetbot", task="detect")

    if vehicle_model is None and jetbot_model is None:
        raise RuntimeError("No YOLO model loaded. Check model paths.")

    rois = load_rois(Path(args.roi_config))
    jetbot_classes = load_class_file(Path(args.classes))
    print(f"[YOLO] vehicle target classes: {sorted(VEHICLE_CLASSES)}")
    print(f"[YOLO] jetbot target classes: {sorted(jetbot_classes)}")

    if not args.no_signal:
        send_signal("RED", args.esp32_ip)
        time.sleep(0.5)

    cap = open_camera(args.camera)
    if not cap.isOpened():
        raise RuntimeError(f"Camera {args.camera} could not be opened. Try --camera 1 or 2.")

    print(f"[CAM] capture loop started: camera={args.camera}")
    encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), JPEG_QUALITY]

    while True:
        ok, frame = cap.read()
        if not ok or frame is None:
            time.sleep(0.05)
            continue

        frame = cv2.resize(frame, (FRAME_WIDTH, FRAME_HEIGHT))

        vehicle_detections = collect_detections(
            frame,
            vehicle_model,
            VEHICLE_CLASSES,
            "vehicle",
            args.conf,
            args.tracker,
            not args.no_tracking,
        )
        jetbot_detections = collect_detections(
            frame,
            jetbot_model,
            jetbot_classes,
            "jetbot",
            args.conf,
            args.tracker,
            not args.no_tracking,
        )

        total_detections = vehicle_detections + jetbot_detections
        for detection in total_detections:
            center_x, center_y = detection["center"]
            detection["roi"] = get_roi_for_point(center_x, center_y, rois)
            emit_detection(
                detection["name"],
                detection["confidence"],
                detection["source"],
                detection["roi"],
                detection["track_id"],
            )

        signal_detections = (
            total_detections if args.signal_source == "all"
            else vehicle_detections if args.signal_source == "vehicle"
            else jetbot_detections
        )
        roi_count = count_roi_detections(signal_detections)
        raw_signal, status = update_signal_from_roi(roi_count, len(total_detections), args)

        update_track_metrics(total_detections, args)
        if args.no_congestion:
            congestion_summary = {"score": 0.0, "level": "OFF", "direction": None, "roi": None}
            congestion_metrics = []
            supabase_rows = []
        else:
            congestion_summary, congestion_metrics, supabase_rows = calculate_congestion(
                rois,
                total_detections,
                args,
            )
            emit_congestion_state(congestion_summary, congestion_metrics, supabase_rows)
            enqueue_supabase(supabase_rows)

        for detection in total_detections:
            draw_detection(frame, detection)
        draw_rois(frame, rois, {item["roi"]: item for item in congestion_metrics})
        draw_status(
            frame,
            roi_count,
            len(total_detections),
            raw_signal,
            status,
            args.camera,
            rois,
            not args.no_tracking,
            congestion_summary,
        )

        ok2, buf = cv2.imencode(".jpg", frame, encode_param)
        if ok2:
            with _latest_lock:
                _latest_jpeg = buf.tobytes()


app = Flask(__name__)


def mjpeg_generator():
    boundary = b"--frame"
    while True:
        with _latest_lock:
            jpg = _latest_jpeg
        if jpg is None:
            time.sleep(0.03)
            continue

        yield (
            boundary
            + b"\r\n"
            + b"Content-Type: image/jpeg\r\n\r\n"
            + jpg
            + b"\r\n"
        )
        time.sleep(0.03)


@app.route("/stream")
def stream():
    return Response(mjpeg_generator(), mimetype="multipart/x-mixed-replace; boundary=frame")


@app.route("/")
def index():
    return '<h3>SmartAI streamer</h3><img src="/stream" style="max-width:100%">'


_ws_clients = set()


async def ws_handler(websocket):
    _ws_clients.add(websocket)
    print(f"[WS] client connected ({len(_ws_clients)} total)")
    try:
        await websocket.wait_closed()
    finally:
        _ws_clients.discard(websocket)
        print(f"[WS] client disconnected ({len(_ws_clients)} total)")


async def ws_broadcaster():
    while True:
        try:
            evt = _event_queue.get_nowait()
        except Empty:
            await asyncio.sleep(0.02)
            continue

        if _ws_clients:
            msg = json.dumps(evt)
            await asyncio.gather(
                *[client.send(msg) for client in list(_ws_clients)],
                return_exceptions=True,
            )


def run_ws_server():
    async def main():
        async with websockets.serve(ws_handler, "0.0.0.0", WS_PORT):
            print(f"[WS] listening on ws://0.0.0.0:{WS_PORT}")
            await ws_broadcaster()

    asyncio.run(main())


def parse_args():
    default_camera = default_camera_from_roi_config(ROI_CONFIG_PATH, CAMERA_INDEX)

    parser = argparse.ArgumentParser()
    parser.add_argument("--camera", type=int, default=default_camera)
    parser.add_argument("--vehicle-model", default=str(VEHICLE_MODEL_PATH))
    parser.add_argument("--jetbot-model", default=str(JETBOT_MODEL_PATH))
    parser.add_argument("--classes", default=str(CLASSES_PATH))
    parser.add_argument("--roi-config", default=str(ROI_CONFIG_PATH))
    parser.add_argument("--tracker", default=TRACKER_CONFIG)
    parser.add_argument("--esp32-ip", default=ESP32_IP)
    parser.add_argument("--conf", type=float, default=CONF_THRES)
    parser.add_argument("--roi-threshold", type=int, default=JETBOT_THRESHOLD)
    parser.add_argument("--signal-source", choices=("jetbot", "vehicle", "all"), default="jetbot")
    parser.add_argument("--congestion-source", choices=("jetbot", "vehicle", "all"), default="all")
    parser.add_argument("--congestion-max-vehicles", type=int, default=CONGESTION_MAX_VEHICLES)
    parser.add_argument("--congestion-max-stop-time", type=float, default=CONGESTION_MAX_STOP_TIME)
    parser.add_argument("--congestion-free-flow-speed", type=float, default=CONGESTION_FREE_FLOW_SPEED)
    parser.add_argument("--congestion-stop-speed", type=float, default=CONGESTION_STOP_SPEED)
    parser.add_argument("--traffic-volume-window", type=float, default=TRAFFIC_VOLUME_WINDOW)
    parser.add_argument("--no-vehicles", action="store_true")
    parser.add_argument("--no-jetbot", action="store_true")
    parser.add_argument("--no-signal", action="store_true")
    parser.add_argument("--no-tracking", action="store_true")
    parser.add_argument("--no-congestion", action="store_true")
    parser.add_argument("--no-supabase", action="store_true")
    return parser.parse_args()


def get_local_ip():
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return "<notebook-ip>"


if __name__ == "__main__":
    args = parse_args()

    if not args.no_supabase:
        init_supabase()
        if _supabase_client is not None:
            threading.Thread(target=run_supabase_worker, daemon=True).start()

    threading.Thread(target=capture_and_detect, args=(args,), daemon=True).start()
    threading.Thread(target=run_ws_server, daemon=True).start()

    ip = get_local_ip()
    print("=" * 60)
    print(f"  video :  http://{ip}:{MJPEG_PORT}/stream")
    print(f"  event :  ws://{ip}:{WS_PORT}")
    print(f"  camera:  {args.camera}")
    print(f"  signal:  {'off' if args.no_signal else args.esp32_ip}")
    print(f"  signal source: {args.signal_source}, threshold: {args.roi_threshold}")
    print(f"  tracking: {'off' if args.no_tracking else args.tracker}")
    print(f"  congestion: {'off' if args.no_congestion else args.congestion_source}")
    print(f"  supabase: {'on -> ' + SUPABASE_TABLE if _supabase_client else 'off'}")
    print("=" * 60)

    app.run(host="0.0.0.0", port=MJPEG_PORT, threaded=True)
