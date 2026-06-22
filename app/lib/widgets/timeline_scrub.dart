import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// Holds the global "replay" state: whether we're showing a past moment
/// and which moment. When `selected == null`, we're live.
class TimelineController extends ChangeNotifier {
  TimelineController._();
  static final TimelineController instance = TimelineController._();

  bool _replayMode = false;
  DateTime _selected = DateTime.now();
  double _speed = 1;
  bool _playing = false;
  Timer? _ticker;

  bool get replayMode => _replayMode;
  DateTime get selected => _selected;
  double get speed => _speed;
  bool get playing => _playing;
  bool get isLive => !_replayMode;

  void enterReplay() {
    _replayMode = true;
    _selected = DateTime.now().subtract(const Duration(minutes: 30));
    _playing = false;
    notifyListeners();
  }

  void exitReplay() {
    _replayMode = false;
    _playing = false;
    _ticker?.cancel();
    _ticker = null;
    _selected = DateTime.now();
    notifyListeners();
  }

  void setSelected(DateTime t) {
    final now = DateTime.now();
    final start = _startOfDay();
    if (t.isBefore(start)) t = start;
    if (t.isAfter(now)) t = now;
    _selected = t;
    notifyListeners();
  }

  void setSpeed(double s) {
    _speed = s;
    if (_playing) {
      _restartTicker();
    }
    notifyListeners();
  }

  void togglePlay() {
    _playing = !_playing;
    if (_playing) {
      _restartTicker();
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    notifyListeners();
  }

  void _restartTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      // advance _selected by speed * 200ms scaled (e.g., 5x -> 1s per tick)
      final advance =
          Duration(milliseconds: (200 * _speed).round());
      final next = _selected.add(advance);
      if (next.isAfter(DateTime.now())) {
        _playing = false;
        _ticker?.cancel();
        _ticker = null;
        _selected = DateTime.now();
        notifyListeners();
        return;
      }
      _selected = next;
      notifyListeners();
    });
  }

  void jumpToLive() {
    _selected = DateTime.now();
    _playing = false;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  DateTime _startOfDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Banner shown at the top of the body when in replay mode.
class ReplayBanner extends StatefulWidget {
  const ReplayBanner({super.key});

  @override
  State<ReplayBanner> createState() => _ReplayBannerState();
}

class _ReplayBannerState extends State<ReplayBanner> {
  @override
  void initState() {
    super.initState();
    TimelineController.instance.addListener(_on);
  }

  @override
  void dispose() {
    TimelineController.instance.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = TimelineController.instance;
    if (!c.replayMode) return const SizedBox.shrink();
    final f = DateFormat('yyyy.MM.dd HH:mm:ss');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: AppColors.violet.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 14, color: AppColors.violet),
          const SizedBox(width: 8),
          Text('재현 중',
              style: const TextStyle(
                  color: AppColors.violet,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text(
            f.format(c.selected),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Text('— 모든 패널이 이 시점의 데이터를 표시합니다',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
          const Spacer(),
          TextButton.icon(
            onPressed: c.jumpToLive,
            icon: const Icon(Icons.fiber_manual_record,
                size: 12, color: AppColors.danger),
            label: const Text('지금으로',
                style: TextStyle(color: AppColors.danger, fontSize: 11)),
          ),
          TextButton.icon(
            onPressed: c.exitReplay,
            icon:
                const Icon(Icons.close, size: 12, color: AppColors.textMuted),
            label: const Text('재현 종료',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

/// Bottom timeline bar with playhead, hour ticks, event markers, and playback
/// controls. Visible only when replayMode is on.
class TimelineScrubBar extends StatefulWidget {
  const TimelineScrubBar({super.key});

  @override
  State<TimelineScrubBar> createState() => _TimelineScrubBarState();
}

class _TimelineScrubBarState extends State<TimelineScrubBar> {
  /// Event markers come from the backend's event log — empty until connected.
  static final _events = <(double, Color, String)>[];

  @override
  void initState() {
    super.initState();
    TimelineController.instance.addListener(_on);
  }

  @override
  void dispose() {
    TimelineController.instance.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  double _ratioFromTime(DateTime t) {
    final start = DateTime(t.year, t.month, t.day);
    final secs = t.difference(start).inSeconds;
    return (secs / (24 * 3600)).clamp(0.0, 1.0);
  }

  DateTime _timeFromRatio(double r) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return start.add(Duration(seconds: (r * 24 * 3600).round()));
  }

  @override
  Widget build(BuildContext context) {
    final c = TimelineController.instance;
    if (!c.replayMode) return const SizedBox.shrink();

    final selectedRatio = _ratioFromTime(c.selected);
    final liveRatio = _ratioFromTime(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.bgAlt,
        border: Border(top: BorderSide(color: AppColors.stroke)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(c.playing ? Icons.pause : Icons.play_arrow,
                    color: AppColors.accent),
                onPressed: c.togglePlay,
                tooltip: c.playing ? '일시정지' : '재생',
              ),
              _SpeedBtn(speed: 1, current: c.speed, onTap: () => c.setSpeed(1)),
              const SizedBox(width: 4),
              _SpeedBtn(speed: 5, current: c.speed, onTap: () => c.setSpeed(5)),
              const SizedBox(width: 4),
              _SpeedBtn(speed: 30, current: c.speed, onTap: () => c.setSpeed(30)),
              const SizedBox(width: 4),
              _SpeedBtn(speed: 120, current: c.speed, onTap: () => c.setSpeed(120)),
              const SizedBox(width: 14),
              Text(
                DateFormat('HH:mm:ss').format(c.selected),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 14),
              const Text('|',
                  style: TextStyle(color: AppColors.stroke, fontSize: 16)),
              const SizedBox(width: 14),
              const Text('현재',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                DateFormat('HH:mm:ss').format(DateTime.now()),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: c.jumpToLive,
                icon: const Icon(Icons.fiber_manual_record,
                    size: 12, color: AppColors.danger),
                label: const Text('LIVE',
                    style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, lc) {
            return SizedBox(
              height: 48,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final r = (d.localPosition.dx / lc.maxWidth)
                      .clamp(0.0, liveRatio);
                  c.setSelected(_timeFromRatio(r));
                },
                onHorizontalDragUpdate: (d) {
                  final r = (d.localPosition.dx / lc.maxWidth)
                      .clamp(0.0, liveRatio);
                  c.setSelected(_timeFromRatio(r));
                },
                child: CustomPaint(
                  painter: _TimelinePainter(
                    selectedRatio: selectedRatio,
                    liveRatio: liveRatio,
                    events: _events,
                  ),
                ),
              ),
            );
          }),
          Row(
            children: [
              for (var h = 0; h <= 24; h += 4)
                Expanded(
                  child: Text(
                    h == 24 ? '24h' : '${h.toString().padLeft(2, '0')}h',
                    textAlign: h == 0
                        ? TextAlign.left
                        : (h == 24 ? TextAlign.right : TextAlign.center),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedBtn extends StatelessWidget {
  final double speed;
  final double current;
  final VoidCallback onTap;
  const _SpeedBtn({
    required this.speed,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == speed;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.stroke),
        ),
        child: Text(
          '${speed.toStringAsFixed(0)}x',
          style: TextStyle(
              color: active ? AppColors.accent : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final double selectedRatio;
  final double liveRatio;
  final List<(double, Color, String)> events;
  _TimelinePainter({
    required this.selectedRatio,
    required this.liveRatio,
    required this.events,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final mid = size.height / 2;

    // Track background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, mid - 3, w, 6),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.strokeDim,
    );

    // Future portion (lighter / dashed feel) — anything past liveRatio
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * liveRatio, mid - 3, w * (1 - liveRatio), 6),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.bg,
    );

    // Live portion (already happened)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, mid - 3, w * liveRatio, 6),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.accent.withValues(alpha: 0.30),
    );

    // Selected portion (from 0 to playhead)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, mid - 3, w * selectedRatio, 6),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.accent,
    );

    // Hour ticks
    for (var h = 0; h <= 24; h += 4) {
      final x = w * (h / 24);
      canvas.drawLine(
        Offset(x, mid + 6),
        Offset(x, mid + 12),
        Paint()
          ..color = AppColors.textMuted
          ..strokeWidth = 1,
      );
    }

    // Event markers
    for (final e in events) {
      if (e.$1 > liveRatio) continue; // future events not shown
      final x = w * e.$1;
      final paint = Paint()..color = e.$2;
      canvas.drawCircle(Offset(x, mid - 12), 4, paint);
      canvas.drawLine(
        Offset(x, mid - 8),
        Offset(x, mid - 3),
        Paint()
          ..color = e.$2.withValues(alpha: 0.6)
          ..strokeWidth = 1.5,
      );
    }

    // Live marker (red)
    final lx = w * liveRatio;
    canvas.drawLine(
      Offset(lx, 0),
      Offset(lx, size.height),
      Paint()
        ..color = AppColors.danger.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );

    // Playhead
    final px = w * selectedRatio;
    canvas.drawLine(
      Offset(px, 0),
      Offset(px, size.height),
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(px, mid),
      8,
      Paint()..color = AppColors.bg,
    );
    canvas.drawCircle(
      Offset(px, mid),
      8,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.selectedRatio != selectedRatio ||
      old.liveRatio != liveRatio ||
      old.events != events;
}
