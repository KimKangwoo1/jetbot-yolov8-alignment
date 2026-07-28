import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';

/// Fullscreen modal for drawing a polygonal Region-Of-Interest on top of the
/// CCTV image. Tap to add a vertex, drag a vertex to move it, double-tap to
/// remove. Save returns the list of normalized points (0..1 in both axes) to
/// the caller.
class RoiEditor extends StatefulWidget {
  final List<Offset>? initial;
  const RoiEditor({super.key, this.initial});

  @override
  State<RoiEditor> createState() => _RoiEditorState();
}

class _RoiEditorState extends State<RoiEditor> {
  /// Points in normalized (0..1) coordinates.
  late List<Offset> _points;
  int? _draggingIndex;
  Size _canvas = Size.zero;

  @override
  void initState() {
    super.initState();
    _points = List<Offset>.from(widget.initial ??
        const [
          Offset(0.20, 0.30),
          Offset(0.78, 0.30),
          Offset(0.85, 0.78),
          Offset(0.15, 0.78),
        ]);
  }

  Offset _normalize(Offset local) =>
      Offset(local.dx / _canvas.width, local.dy / _canvas.height);
  Offset _denormalize(Offset n) =>
      Offset(n.dx * _canvas.width, n.dy * _canvas.height);

  int? _hitTest(Offset local, {double radius = 14}) {
    for (var i = 0; i < _points.length; i++) {
      if ((_denormalize(_points[i]) - local).distance <= radius) return i;
    }
    return null;
  }

  void _onTapUp(TapUpDetails d) {
    if (_canvas == Size.zero) return;
    final hit = _hitTest(d.localPosition);
    if (hit != null) return; // tapped on existing point — no-op
    final n = _normalize(d.localPosition);
    setState(() => _points.add(Offset(
          n.dx.clamp(0.0, 1.0),
          n.dy.clamp(0.0, 1.0),
        )));
  }

  void _onDoubleTapDown(TapDownDetails d) {
    final hit = _hitTest(d.localPosition);
    if (hit != null) {
      setState(() => _points.removeAt(hit));
    }
  }

  void _onPanStart(DragStartDetails d) {
    final hit = _hitTest(d.localPosition);
    setState(() => _draggingIndex = hit);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final i = _draggingIndex;
    if (i == null) return;
    final n = _normalize(d.localPosition);
    setState(() => _points[i] = Offset(
          n.dx.clamp(0.0, 1.0),
          n.dy.clamp(0.0, 1.0),
        ));
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() => _draggingIndex = null);
  }

  void _undo() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _clear() {
    setState(() => _points.clear());
  }

  void _reset() {
    setState(() {
      _points = const [
        Offset(0.20, 0.30),
        Offset(0.78, 0.30),
        Offset(0.85, 0.78),
        Offset(0.15, 0.78),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bgAlt,
        elevation: 0,
        title: const Text('검출 영역 편집',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _undo,
            icon: const Icon(Icons.undo,
                size: 16, color: AppColors.textSecondary),
            label: const Text('되돌리기',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline,
                size: 16, color: AppColors.warn),
            label: const Text('전체 삭제',
                style: TextStyle(color: AppColors.warn)),
          ),
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh,
                size: 16, color: AppColors.textSecondary),
            label: const Text('기본값',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(_points),
              icon: const Icon(Icons.save_outlined,
                  size: 16, color: Colors.black),
              label: const Text('저장',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const _Hint(),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Panel(
                    padding: const EdgeInsets.all(0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          _canvas = Size(c.maxWidth, c.maxHeight);
                          return GestureDetector(
                            onTapUp: _onTapUp,
                            onDoubleTapDown: _onDoubleTapDown,
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.panelAlt,
                                        AppColors.panel
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.videocam_off_outlined,
                                        size: 60,
                                        color: AppColors.textMuted),
                                  ),
                                ),
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: _RoiPainter(
                                    points: _points,
                                    canvas: _canvas,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _MetaBar(count: _points.length),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.touch_app, size: 14, color: AppColors.accent),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '탭하여 점 추가, 점을 드래그하여 이동, 점을 더블탭하여 삭제. 폴리곤은 자동으로 닫힙니다.',
              style: TextStyle(color: AppColors.accent, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBar extends StatelessWidget {
  final int count;
  const _MetaBar({required this.count});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          const Icon(Icons.crop_square,
              size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('정점 $count개',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          if (count < 3)
            const Text('정점 3개 이상 필요',
                style: TextStyle(color: AppColors.warn, fontSize: 11))
          else
            const Text('유효한 다각형',
                style: TextStyle(color: AppColors.ok, fontSize: 11)),
        ],
      ),
    );
  }
}

class _RoiPainter extends CustomPainter {
  final List<Offset> points;
  final Size canvas;
  _RoiPainter({required this.points, required this.canvas});

  @override
  void paint(Canvas c, Size size) {
    if (points.isEmpty) return;

    final pts = [
      for (final p in points) Offset(p.dx * size.width, p.dy * size.height)
    ];

    // Fill polygon if we have ≥3 vertices
    if (pts.length >= 3) {
      final fill = Path()..addPolygon(pts, true);
      c.drawPath(
        fill,
        Paint()..color = AppColors.accent.withValues(alpha: 0.18),
      );
    }

    // Edges
    final edge = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      if (i == pts.length - 1 && pts.length < 3) break;
      c.drawLine(a, b, edge);
    }

    // Vertices
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      c.drawCircle(p, 8, Paint()..color = AppColors.bg);
      c.drawCircle(
        p,
        8,
        Paint()
          ..color = AppColors.accent
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      // index label
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RoiPainter old) => true;
}
