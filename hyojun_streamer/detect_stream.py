# -*- coding: utf-8 -*-
"""
Webcam YOLO streamer plus ESP32 traffic-light control.

One process owns the webcam and does everything:
  - MJPEG video stream for the Flutter dashboard
  - WebSocket detection events
  - custom JetBot/ambulance detection with JetBot_Last.onnx
  - ByteTrack tracking IDs for dashboard metrics
  - ROI congestion scoring
  - ROI counting and ESP32 signal control
"""

import argparse
import asyncio
import json
import socket
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from queue import Empty, Queue

import cv2
import requests
import websockets
from flask import Flask, Response, jsonify, request
from ultralytics import YOLO


BASE_DIR = Path(__file__).resolve().parent

CAMERA_INDEX = 0
FRAME_WIDTH = 960
FRAME_HEIGHT = 540
JPEG_QUALITY = 55
MJPEG_PORT = 8080
WS_PORT = 8765

ESP32_IP = "192.168.0.162"
ESP32_TIMEOUT = 0.7

OPENVINO_MODEL_PATH = BASE_DIR / "JetBot_Last_openvino_model"
ONNX_MODEL_PATH = BASE_DIR / "JetBot_Last.onnx"
JETBOT_MODEL_PATH = OPENVINO_MODEL_PATH if OPENVINO_MODEL_PATH.exists() else ONNX_MODEL_PATH
CLASSES_PATH = BASE_DIR / "classes.txt"
ROI_CONFIG_PATH = BASE_DIR / "roi_config.json"
TRACKER_CONFIG = "bytetrack.yaml"
MODEL_IMGSZ = 640
DETECT_EVERY = 3

DEFAULT_JETBOT_CLASSES = {"output_ambulance_normal", "output_jetbot"}
AMBULANCE_CLASSES = {"output_ambulance_normal"}
JETBOT_CLASSES = {"output_jetbot"}
DEFAULT_ROIS = [
    ("top_center", 530, 72, 617, 211),
    ("left_middle", 208, 204, 405, 288),
    ("right_middle", 628, 212, 869, 306),
    ("bottom_center", 504, 312, 637, 530),
]
DEFAULT_ROI_FRAME_WIDTH = 1280
DEFAULT_ROI_FRAME_HEIGHT = 720

CONF_THRES = 0.45
EVENT_MIN_INTERVAL = 1.0
JETBOT_THRESHOLD = 1
STABLE_DETECTION_TIME = 3.0
MIN_SIGNAL_INTERVAL = 3.0
YELLOW_TIME = 3.0
CONGESTION_MAX_VEHICLES = 6
CONGESTION_MAX_STOP_TIME = 10.0
CONGESTION_FREE_FLOW_SPEED = 80.0
CONGESTION_STOP_SPEED = 12.0
CONGESTION_FULL_OCCUPANCY = 0.5
CONGESTION_SIGNAL_THRESHOLD = 60.0
AMBULANCE_CONF_THRES = 0.50
AMBULANCE_STABLE_FRAMES = 3
AMBULANCE_HOLD_TIME = 5.0
AMBULANCE_LOST_TIMEOUT = 2.0
AMBULANCE_MAX_GREEN_TIME = 10.0
AMBULANCE_APPROACH_EPS_PX = 12.0
TRACK_STALE_SECONDS = 2.0
TRAFFIC_VOLUME_WINDOW = 60.0


_latest_jpeg = None
_latest_lock = threading.Lock()
_overlay_enabled = True
_overlay_lock = threading.Lock()
_event_queue: "Queue[dict]" = Queue()
_last_emit = {}
_track_state = {}
_traffic_passages = {}
_ambulance_motion = {}
_emergency_state = {
    "active": False,
    "candidate_frames": 0,
    "direction": None,
    "roi": None,
    "last_seen": 0.0,
    "started_at": 0.0,
    "max_conf": 0.0,
}

current_signal = "RED"
last_signal_time = 0.0
pending_signal = "RED"
pending_signal_since = time.time()
last_log_time = 0.0


def set_overlay_enabled(enabled):
    global _overlay_enabled
    with _overlay_lock:
        _overlay_enabled = bool(enabled)


def is_overlay_enabled():
    with _overlay_lock:
        return _overlay_enabled


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


def scale_rois(rois, source_width, source_height, target_width, target_height):
    scale_x = target_width / max(source_width, 1)
    scale_y = target_height / max(source_height, 1)
    return [
        (
            name,
            int(x1 * scale_x),
            int(y1 * scale_y),
            int(x2 * scale_x),
            int(y2 * scale_y),
        )
        for name, x1, y1, x2, y2 in rois
    ]


def load_rois(path, target_width, target_height):
    if not path.exists():
        print("[ROI] roi_config.json not found. Using built-in ROIs.")
        return scale_rois(
            DEFAULT_ROIS,
            DEFAULT_ROI_FRAME_WIDTH,
            DEFAULT_ROI_FRAME_HEIGHT,
            target_width,
            target_height,
        )

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        source_width = int(data.get("frame_width", DEFAULT_ROI_FRAME_WIDTH))
        source_height = int(data.get("frame_height", DEFAULT_ROI_FRAME_HEIGHT))
        rois = [
            (item["name"], int(item["x1"]), int(item["y1"]), int(item["x2"]), int(item["y2"]))
            for item in data["rois"]
        ]
        rois = scale_rois(rois, source_width, source_height, target_width, target_height)
    except Exception as exc:
        print(f"[ROI] failed to read {path}: {exc}. Using built-in ROIs.")
        return scale_rois(
            DEFAULT_ROIS,
            DEFAULT_ROI_FRAME_WIDTH,
            DEFAULT_ROI_FRAME_HEIGHT,
            target_width,
            target_height,
        )

    print(f"[ROI] using {len(rois)} ROI(s): {path} -> {target_width}x{target_height}")
    return rois


def default_camera_from_roi_config(path, fallback):
    if not path.exists():
        return fallback

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return int(data.get("camera_index", fallback))
    except Exception:
        return fallback


def is_openvino_model(path):
    path = Path(path)
    return path.is_dir() and path.name.endswith("_openvino_model")


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


def open_camera(camera_index, width, height):
    cap = cv2.VideoCapture(camera_index, cv2.CAP_DSHOW)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
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


def change_signal_with_yellow(target_signal, esp32_ip, force=False):
    global current_signal, last_signal_time

    now = time.time()
    if current_signal == target_signal:
        return
    if not force and now - last_signal_time < MIN_SIGNAL_INTERVAL:
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


def direction_for_roi(roi, frame_width, frame_height):
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

    if center_y < frame_height * 0.35:
        return "north"
    if center_y > frame_height * 0.55:
        return "south"
    if center_x < frame_width * 0.5:
        return "west"
    return "east"


def distance_to_frame_center(center, frame_width, frame_height):
    center_x, center_y = center
    dx = center_x - frame_width / 2
    dy = center_y - frame_height / 2
    return (dx * dx + dy * dy) ** 0.5


def ambulance_motion_key(detection):
    track_id = detection.get("track_id")
    if track_id is not None:
        return detection["source"], track_id
    return detection["source"], detection.get("roi") or "untracked"


def find_best_ambulance_candidate(detections, rois, args):
    now = time.time()
    roi_by_name = {roi[0]: roi for roi in rois}
    best = None

    for detection in detections:
        if detection["name"] not in AMBULANCE_CLASSES:
            continue
        if detection["confidence"] < args.ambulance_conf_thres:
            continue
        if detection["roi"] is None:
            continue

        roi = roi_by_name.get(detection["roi"])
        if roi is None:
            continue

        key = ambulance_motion_key(detection)
        distance = distance_to_frame_center(
            detection["center"],
            args.width,
            args.height,
        )
        previous = _ambulance_motion.get(key)
        approaching = (
            previous is None
            or distance <= previous["distance"] + args.ambulance_approach_eps_px
        )
        _ambulance_motion[key] = {
            "center": detection["center"],
            "distance": distance,
            "seen_at": now,
        }

        if not approaching:
            continue

        candidate = {
            "detection": detection,
            "roi": detection["roi"],
            "direction": direction_for_roi(roi, args.width, args.height),
            "confidence": detection["confidence"],
            "distance": distance,
        }
        if best is None or candidate["confidence"] > best["confidence"]:
            best = candidate

    stale_keys = [
        key
        for key, state in _ambulance_motion.items()
        if now - state["seen_at"] > args.ambulance_lost_timeout
    ]
    for key in stale_keys:
        del _ambulance_motion[key]

    return best


def update_emergency_state(detections, rois, args):
    now = time.time()
    candidate = find_best_ambulance_candidate(detections, rois, args)

    if candidate is not None:
        same_roi = _emergency_state["roi"] in {None, candidate["roi"]}
        if same_roi:
            _emergency_state["candidate_frames"] += 1
        else:
            _emergency_state["candidate_frames"] = 1

        _emergency_state["direction"] = candidate["direction"]
        _emergency_state["roi"] = candidate["roi"]
        _emergency_state["last_seen"] = now
        _emergency_state["max_conf"] = max(
            _emergency_state["max_conf"],
            candidate["confidence"],
        )

        if (
            not _emergency_state["active"]
            and _emergency_state["candidate_frames"] >= args.ambulance_stable_frames
        ):
            _emergency_state["active"] = True
            _emergency_state["started_at"] = now
    elif not _emergency_state["active"]:
        _emergency_state["candidate_frames"] = 0
        _emergency_state["direction"] = None
        _emergency_state["roi"] = None
        _emergency_state["max_conf"] = 0.0

    if _emergency_state["active"]:
        active_time = now - _emergency_state["started_at"]
        lost_time = now - _emergency_state["last_seen"]
        may_release = active_time >= args.ambulance_hold_time
        lost_release = lost_time >= args.ambulance_lost_timeout
        max_release = active_time >= args.ambulance_max_green_time

        if may_release and (lost_release or max_release):
            _emergency_state["active"] = False
            _emergency_state["candidate_frames"] = 0
            _emergency_state["direction"] = None
            _emergency_state["roi"] = None
            _emergency_state["last_seen"] = 0.0
            _emergency_state["started_at"] = 0.0
            _emergency_state["max_conf"] = 0.0

    active_time = (
        now - _emergency_state["started_at"]
        if _emergency_state["active"]
        else 0.0
    )
    lost_time = (
        now - _emergency_state["last_seen"]
        if _emergency_state["last_seen"]
        else None
    )
    return {
        "active": _emergency_state["active"],
        "candidateFrames": _emergency_state["candidate_frames"],
        "direction": _emergency_state["direction"],
        "roi": _emergency_state["roi"],
        "activeTimeSec": round(active_time, 2),
        "lostTimeSec": round(lost_time, 2) if lost_time is not None else None,
        "maxConfidence": round(_emergency_state["max_conf"], 3),
    }


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


def emit_signal_state(raw_signal, roi_count, total_count, status, emergency_state=None):
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
            "emergency": emergency_state or {"active": False},
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
            "formula": "vc_score*0.40 + delay_score*0.40 + speed_score*0.20",
            "rois": roi_metrics,
            "supabaseRow": summary_row,
            "supabaseRows": supabase_rows,
            "ts": now,
        }
    )


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


def collect_detections(
    frame,
    model,
    target_classes,
    source,
    conf_thres,
    tracker_config,
    use_tracking,
    imgsz,
    device,
):
    detections = []
    if model is None:
        return detections

    infer_kwargs = {
        "conf": conf_thres,
        "imgsz": imgsz,
        "verbose": False,
    }
    if device:
        infer_kwargs["device"] = device

    if use_tracking:
        results = model.track(
            frame,
            persist=True,
            tracker=tracker_config,
            **infer_kwargs,
        )[0]
    else:
        results = model.predict(frame, **infer_kwargs)[0]

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
    if score >= 40:
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
        roi_name, x1, y1, x2, y2 = roi
        roi_detections = [
            detection
            for detection in detections
            if detection["roi"] == roi_name
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

        vc_score = min(count / max(args.congestion_max_vehicles, 1), 1.0) * 100.0
        delay_score = min(avg_stop_time / max(args.congestion_max_stop_time, 0.1), 1.0) * 100.0
        if avg_speed is None or count == 0:
            speed_score = 0.0
        else:
            speed_score = (
                1.0 - min(avg_speed / max(args.congestion_free_flow_speed, 0.1), 1.0)
            ) * 100.0

        roi_area = max((x2 - x1) * (y2 - y1), 1)
        bbox_area_sum = 0
        for detection in roi_detections:
            bx1, by1, bx2, by2 = detection["box"]
            ix1 = max(bx1, x1)
            iy1 = max(by1, y1)
            ix2 = min(bx2, x2)
            iy2 = min(by2, y2)
            bbox_area_sum += max(ix2 - ix1, 0) * max(iy2 - iy1, 0)

        occupancy = bbox_area_sum / roi_area
        occupancy_score = (
            min(occupancy / max(args.congestion_full_occupancy, 0.01), 1.0)
            * 100.0
        )

        score = round(
            min(
                vc_score * 0.40
                + delay_score * 0.40
                + speed_score * 0.20,
                100.0,
            ),
            1,
        )
        level = congestion_level(score)
        level_ko = congestion_level_ko(level)
        direction = direction_for_roi(roi, args.width, args.height)
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
                "vcScore": round(vc_score, 1),
                "queueScore": round(vc_score, 1),
                "delayScore": round(delay_score, 1),
                "speedScore": round(speed_score, 1),
                "occupancyScore": round(occupancy_score, 1),
                "occupancy": round(occupancy, 3),
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
    emergency_state,
):
    lines = [
        f"ROI Count: {roi_count} / Threshold: {JETBOT_THRESHOLD}",
        f"Total: {total_count} / Status: {status} / Raw: {raw_signal} / Current: {current_signal}",
        f"Camera: {camera_index} / ROIs: {len(rois)} active / Stream+Signal",
        f"Tracking: {'ByteTrack' if tracking_enabled else 'OFF'}",
        f"Congestion: {congestion_summary['level']} {congestion_summary['score']} / ROI: {congestion_summary['roi']}",
        (
            f"Emergency: {emergency_state.get('active')} / "
            f"ROI: {emergency_state.get('roi')} / "
            f"Frames: {emergency_state.get('candidateFrames', 0)}"
        ),
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


def update_signal_from_controller(
    emergency_state,
    congestion_summary,
    roi_count,
    total_count,
    args,
):
    global last_log_time

    score = float(congestion_summary.get("score") or 0.0)
    level = congestion_summary.get("level")
    roi_name = congestion_summary.get("roi")

    if emergency_state.get("active"):
        raw_target_signal = "GREEN"
        status = "EMERGENCY"
    elif score >= args.congestion_signal_threshold:
        raw_target_signal = "GREEN"
        status = "CONGESTION"
    else:
        raw_target_signal = "RED"
        status = "NORMAL"

    if emergency_state.get("active"):
        if not args.no_signal:
            change_signal_with_yellow(raw_target_signal, args.esp32_ip, force=True)
    else:
        stable_target_signal = get_stable_signal(raw_target_signal)
        if stable_target_signal is not None and not args.no_signal:
            change_signal_with_yellow(stable_target_signal, args.esp32_ip)

    now = time.time()
    if now - last_log_time >= 0.5:
        print(
            f"Status: {status}, Emergency: {emergency_state.get('active')}, "
            f"Emergency ROI: {emergency_state.get('roi')}, "
            f"Congestion: {score:.1f}, Level: {level}, ROI: {roi_name}, "
            f"ROI Count: {roi_count}, Total: {total_count}, "
            f"Raw Target: {raw_target_signal}, Current: {current_signal}"
        )
        last_log_time = now

    emit_signal_state(raw_target_signal, roi_count, total_count, status, emergency_state)
    return raw_target_signal, status


def capture_and_detect(args):
    global _latest_jpeg

    jetbot_model = load_model(Path(args.jetbot_model), "jetbot", task="detect")

    if jetbot_model is None:
        raise RuntimeError("JetBot_Last.onnx could not be loaded. Check model path.")

    rois = load_rois(Path(args.roi_config), args.width, args.height)
    jetbot_classes = load_class_file(Path(args.classes))
    print(f"[YOLO] using model: {Path(args.jetbot_model)}")
    print(f"[YOLO] jetbot target classes: {sorted(jetbot_classes)}")

    if not args.no_signal:
        send_signal("RED", args.esp32_ip)
        time.sleep(0.5)

    cap = open_camera(args.camera, args.width, args.height)
    if not cap.isOpened():
        raise RuntimeError(f"Camera {args.camera} could not be opened. Try --camera 1 or 2.")

    print(
        f"[CAM] capture loop started: camera={args.camera}, "
        f"{args.width}x{args.height}, imgsz={args.imgsz}, detect_every={args.detect_every}"
    )
    encode_param = [int(cv2.IMWRITE_JPEG_QUALITY), args.jpeg_quality]
    frame_index = 0
    last_detections = []
    last_roi_count = 0
    last_raw_signal = "RED"
    last_status = "START"
    last_congestion_summary = {"score": 0.0, "level": "LOW", "direction": None, "roi": None}
    last_congestion_metrics = []
    last_emergency_state = {"active": False}

    while True:
        ok, frame = cap.read()
        if not ok or frame is None:
            time.sleep(0.05)
            continue

        frame = cv2.resize(frame, (args.width, args.height))

        should_detect = frame_index % max(args.detect_every, 1) == 0
        frame_index += 1

        if should_detect:
            jetbot_detections = collect_detections(
                frame,
                jetbot_model,
                jetbot_classes,
                "jetbot",
                args.conf,
                args.tracker,
                not args.no_tracking,
                args.imgsz,
                args.device,
            )

            total_detections = jetbot_detections
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

            roi_count = count_roi_detections(jetbot_detections)
            update_track_metrics(total_detections, args)
            emergency_state = update_emergency_state(total_detections, rois, args)
            if args.no_congestion:
                congestion_summary = {
                    "score": 0.0,
                    "level": "OFF",
                    "direction": None,
                    "roi": None,
                }
                congestion_metrics = []
                supabase_rows = []
                raw_signal, status = update_signal_from_controller(
                    emergency_state,
                    congestion_summary,
                    roi_count,
                    len(total_detections),
                    args,
                )
            else:
                congestion_summary, congestion_metrics, supabase_rows = calculate_congestion(
                    rois,
                    total_detections,
                    args,
                )
                raw_signal, status = update_signal_from_controller(
                    emergency_state,
                    congestion_summary,
                    roi_count,
                    len(total_detections),
                    args,
                )
                for row in supabase_rows:
                    row["signal_state"] = current_signal
                for metric in congestion_metrics:
                    metric["signalState"] = current_signal
                    metric["supabase"]["signal_state"] = current_signal
                emit_congestion_state(congestion_summary, congestion_metrics, supabase_rows)

            last_detections = total_detections
            last_roi_count = roi_count
            last_raw_signal = raw_signal
            last_status = status
            last_congestion_summary = congestion_summary
            last_congestion_metrics = congestion_metrics
            last_emergency_state = emergency_state
        else:
            total_detections = last_detections
            roi_count = last_roi_count
            raw_signal = last_raw_signal
            status = last_status
            congestion_summary = last_congestion_summary
            congestion_metrics = last_congestion_metrics
            emergency_state = last_emergency_state

        if is_overlay_enabled():
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
                emergency_state,
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


def overlay_payload():
    return {
        "overlay": is_overlay_enabled(),
        "on": "/overlay?enabled=1",
        "off": "/overlay?enabled=0",
        "toggle": "/toggle-overlay",
        "stream": "/stream",
    }


@app.route("/overlay")
def overlay():
    value = request.args.get("enabled")
    if value is not None:
        set_overlay_enabled(value.strip().lower() in {"1", "true", "on", "yes"})
    return jsonify(overlay_payload())


@app.route("/toggle-overlay")
def toggle_overlay():
    set_overlay_enabled(not is_overlay_enabled())
    return jsonify(overlay_payload())


@app.route("/")
def index():
    return """
    <h3>SmartAI streamer</h3>
    <p>
      Overlay:
      <a href="/overlay?enabled=1">ON</a>
      <a href="/overlay?enabled=0">OFF</a>
      <a href="/toggle-overlay">TOGGLE</a>
    </p>
    <img src="/stream" style="max-width:100%">
    """


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
    parser.add_argument("--width", type=int, default=FRAME_WIDTH)
    parser.add_argument("--height", type=int, default=FRAME_HEIGHT)
    parser.add_argument("--jpeg-quality", type=int, default=JPEG_QUALITY)
    parser.add_argument("--imgsz", type=int, default=MODEL_IMGSZ)
    parser.add_argument("--detect-every", type=int, default=DETECT_EVERY)
    parser.add_argument(
        "--device",
        default=None,
        help="Inference device. For OpenVINO try: intel:cpu, intel:gpu, intel:npu",
    )
    parser.add_argument("--jetbot-model", default=str(JETBOT_MODEL_PATH))
    parser.add_argument("--classes", default=str(CLASSES_PATH))
    parser.add_argument("--roi-config", default=str(ROI_CONFIG_PATH))
    parser.add_argument("--tracker", default=TRACKER_CONFIG)
    parser.add_argument("--esp32-ip", default=ESP32_IP)
    parser.add_argument("--conf", type=float, default=CONF_THRES)
    parser.add_argument("--roi-threshold", type=int, default=JETBOT_THRESHOLD)
    parser.add_argument("--congestion-max-vehicles", type=int, default=CONGESTION_MAX_VEHICLES)
    parser.add_argument("--congestion-max-stop-time", type=float, default=CONGESTION_MAX_STOP_TIME)
    parser.add_argument("--congestion-free-flow-speed", type=float, default=CONGESTION_FREE_FLOW_SPEED)
    parser.add_argument("--congestion-stop-speed", type=float, default=CONGESTION_STOP_SPEED)
    parser.add_argument("--congestion-full-occupancy", type=float, default=CONGESTION_FULL_OCCUPANCY)
    parser.add_argument("--congestion-signal-threshold", type=float, default=CONGESTION_SIGNAL_THRESHOLD)
    parser.add_argument("--traffic-volume-window", type=float, default=TRAFFIC_VOLUME_WINDOW)
    parser.add_argument("--ambulance-conf-thres", type=float, default=AMBULANCE_CONF_THRES)
    parser.add_argument("--ambulance-stable-frames", type=int, default=AMBULANCE_STABLE_FRAMES)
    parser.add_argument("--ambulance-hold-time", type=float, default=AMBULANCE_HOLD_TIME)
    parser.add_argument("--ambulance-lost-timeout", type=float, default=AMBULANCE_LOST_TIMEOUT)
    parser.add_argument("--ambulance-max-green-time", type=float, default=AMBULANCE_MAX_GREEN_TIME)
    parser.add_argument("--ambulance-approach-eps-px", type=float, default=AMBULANCE_APPROACH_EPS_PX)
    parser.add_argument("--no-signal", action="store_true")
    parser.add_argument("--no-tracking", action="store_true")
    parser.add_argument("--no-congestion", action="store_true")
    parser.add_argument("--no-overlay", action="store_true")
    args = parser.parse_args()
    model_path = Path(args.jetbot_model)
    if (
        str(args.jetbot_model).lower().endswith(".onnx") or is_openvino_model(model_path)
    ) and args.imgsz != 640:
        print(
            f"[YOLO] model requires 640x640 input. "
            f"Forcing --imgsz 640 (was {args.imgsz})."
        )
        args.imgsz = 640
    return args


def get_local_ip():
    try:
        return socket.gethostbyname(socket.gethostname())
    except Exception:
        return "<notebook-ip>"


if __name__ == "__main__":
    args = parse_args()
    set_overlay_enabled(not args.no_overlay)

    threading.Thread(target=capture_and_detect, args=(args,), daemon=True).start()
    threading.Thread(target=run_ws_server, daemon=True).start()

    ip = get_local_ip()
    print("=" * 60)
    print(f"  video :  http://{ip}:{MJPEG_PORT}/stream")
    print(f"  event :  ws://{ip}:{WS_PORT}")
    print(f"  camera:  {args.camera}")
    print(f"  frame :  {args.width}x{args.height}, jpeg={args.jpeg_quality}")
    print(f"  yolo  :  imgsz={args.imgsz}, detect_every={args.detect_every}")
    print(f"  device:  {args.device or 'auto'}")
    print(f"  signal:  {'off' if args.no_signal else args.esp32_ip}")
    print(f"  signal threshold: {args.roi_threshold}")
    print(f"  congestion signal threshold: {args.congestion_signal_threshold}")
    print(
        "  ambulance: "
        f"conf>={args.ambulance_conf_thres}, "
        f"stable={args.ambulance_stable_frames} frames, "
        f"hold={args.ambulance_hold_time}s, "
        f"lost={args.ambulance_lost_timeout}s, "
        f"max={args.ambulance_max_green_time}s"
    )
    print(f"  tracking: {'off' if args.no_tracking else args.tracker}")
    print(f"  congestion: {'off' if args.no_congestion else 'jetbot'}")
    print(f"  overlay: {'off' if args.no_overlay else 'on'}")
    print(f"  overlay control: http://{ip}:{MJPEG_PORT}/overlay?enabled=0 or 1")
    print("=" * 60)

    app.run(host="0.0.0.0", port=MJPEG_PORT, threaded=True)
