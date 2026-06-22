import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

// ============================================================
// Motion — shared, gentle animation tuning so the whole dashboard
// feels calm and smooth on the eyes (no hard jumps).
// ============================================================
const Duration kMotion = Duration(milliseconds: 600);
const Duration kMotionFast = Duration(milliseconds: 280);
const Curve kMotionCurve = Curves.easeOutCubic;

/// A soft, slowly pulsing dot. Used in standby / waiting states so the
/// operator can see the panel is alive and waiting for data, not frozen.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, this.color = AppColors.accent, this.size = 8});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) {
        final t = curve.value;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.45 + 0.55 * t),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.2 + 0.35 * t),
                blurRadius: 5 + 8 * t,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Standby placeholder shown wherever live data will appear once the
/// Jetson Nano backend is connected. Replaces demo/mock numbers so the
/// dashboard never shows fabricated values before real data arrives.
class WaitingBox extends StatelessWidget {
  final String label;
  final String? hint;
  final IconData icon;
  final bool compact;
  const WaitingBox({
    super.key,
    this.label = '연결 대기 중',
    this.hint = 'Jetson Nano 데이터 연결을 기다리는 중입니다.',
    this.icon = Icons.sensors_outlined,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulseDot(color: AppColors.textMuted, size: 7),
                const SizedBox(width: 8),
                Icon(icon, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (hint != null && !compact) ...[
              const SizedBox(height: 6),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.stroke, width: 1),
      ),
      child: child,
    );
  }
}

class PanelHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  const PanelHeader({super.key, required this.title, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class StatusDotPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool dense;
  const StatusDotPill({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: dense ? 11 : 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});
  @override
  Widget build(BuildContext context) =>
      const StatusDotPill(label: 'LIVE', color: AppColors.danger, dense: true);
}

// ============================================================
// Mini circular gauge (for 방향별 혼잡도)
// ============================================================
class MiniGauge extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final String label;
  final String sub;
  const MiniGauge({
    super.key,
    required this.value,
    required this.color,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
              duration: kMotion,
              curve: kMotionCurve,
              builder: (context, v, _) => CustomPaint(
                painter: _RingGaugePainter(value: v, color: color),
                child: Center(
                  child: Text(
                    '${(v * 100).round()}%',
                    style: TextStyle(
                        color: color, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  final double value;
  final Color color;
  _RingGaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final stroke = math.max(4.0, radius * 0.18);

    final bg = Paint()
      ..color = AppColors.strokeDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);

    final fg = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.6), color],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * value.clamp(0.0, 1.0),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter old) =>
      old.value != value || old.color != color;
}

// ============================================================
// Big half-arc gauge (for 전체 혼잡도)
// ============================================================
class ArcGauge extends StatelessWidget {
  final double value; // 0..1
  final String centerText;
  final String centerLabel;
  const ArcGauge({
    super.key,
    required this.value,
    required this.centerText,
    required this.centerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: kMotion,
            curve: kMotionCurve,
            builder: (context, v, _) => CustomPaint(
              size: Size(c.maxWidth, c.maxHeight),
              painter: _ArcGaugePainter(value: v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  centerLabel,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Positioned(
            left: 4,
            bottom: 12,
            child: Text('0%', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
          Positioned(
            right: 4,
            bottom: 12,
            child: Text('100%', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
        ],
      );
    });
  }
}

class _ArcGaugePainter extends CustomPainter {
  final double value;
  _ArcGaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = math.min(size.width / 2 - 12, size.height - 24);
    final stroke = math.max(10.0, radius * 0.16);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background segments (green→yellow→red)
    final segments = <(double, double, Color)>[
      (0.00, 0.30, AppColors.ok),
      (0.30, 0.70, AppColors.warn),
      (0.70, 1.00, AppColors.danger),
    ];
    for (final s in segments) {
      final paint = Paint()
        ..color = s.$3.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      const start = math.pi; // left side, going clockwise
      final a = start + math.pi * s.$1;
      final span = math.pi * (s.$2 - s.$1);
      canvas.drawArc(rect, a, span, false, paint);
    }

    // Foreground (active value)
    final activeColor = AppColors.forCongestion(value);
    final fg = Paint()
      ..shader = LinearGradient(
        colors: [activeColor.withValues(alpha: 0.4), activeColor],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi * value.clamp(0.0, 1.0), false, fg);

    // Tick at the value position
    final angle = math.pi + math.pi * value.clamp(0.0, 1.0);
    final tickInner = Offset(
      center.dx + math.cos(angle) * (radius - stroke / 2 - 4),
      center.dy + math.sin(angle) * (radius - stroke / 2 - 4),
    );
    final tickOuter = Offset(
      center.dx + math.cos(angle) * (radius + stroke / 2 + 4),
      center.dy + math.sin(angle) * (radius + stroke / 2 + 4),
    );
    final tickPaint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tickInner, tickOuter, tickPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter old) => old.value != value;
}

// ============================================================
// Traffic light dots
// ============================================================
class TrafficLightDots extends StatelessWidget {
  /// states: list of LightState (red, yellow, green, off, leftArrow)
  final List<LightState> states;
  const TrafficLightDots({super.key, required this.states});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: states.map(_dot).toList(),
    );
  }

  Widget _dot(LightState s) {
    final c = switch (s) {
      LightState.red => AppColors.danger,
      LightState.yellow => AppColors.warn,
      LightState.green => AppColors.ok,
      LightState.leftArrow => AppColors.accent,
      LightState.off => AppColors.strokeDim,
    };
    final lit = s != LightState.off;
    return AnimatedContainer(
      duration: kMotion,
      curve: kMotionCurve,
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? c : AppColors.bgAlt,
        border: Border.all(color: c.withValues(alpha: 0.5), width: 1),
        boxShadow: lit
            ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
    );
  }
}

enum LightState { red, yellow, green, leftArrow, off }

// ============================================================
// KPI card (large value + label + delta)
// ============================================================
enum KpiTrend { up, down, flat }

class KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? unit;
  final String? deltaText;
  final KpiTrend? trend;
  const KpiCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.unit,
    this.deltaText,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    Color trendColor = AppColors.textMuted;
    IconData trendIcon = Icons.remove;
    if (trend == KpiTrend.up) {
      trendColor = AppColors.ok;
      trendIcon = Icons.arrow_upward;
    } else if (trend == KpiTrend.down) {
      trendColor = AppColors.danger;
      trendIcon = Icons.arrow_downward;
    }
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: iconColor.withValues(alpha: 0.35), width: 1),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
          if (deltaText != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(trendIcon, size: 12, color: trendColor),
                const SizedBox(width: 3),
                Text(
                  deltaText!,
                  style: TextStyle(color: trendColor, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// Small dot + label, used as legend or inline status
// ============================================================
class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final double size;
  const LegendDot({
    super.key,
    required this.color,
    required this.label,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ============================================================
// label · value row (for stat rows in cards)
// ============================================================
class StatLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  /// Optional inline baseline hint (e.g. "평소 18 ± 4"). Shown small + muted
  /// directly under the value, gives the operator instant context.
  final String? baseline;

  /// Severity coloring relative to the baseline. When set, the value text is
  /// colored to indicate "high vs normal vs low".
  final BaselineSeverity severity;

  const StatLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.baseline,
    this.severity = BaselineSeverity.normal,
  });

  @override
  Widget build(BuildContext context) {
    final color = valueColor ?? severity.color() ?? AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              if (baseline != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(baseline!,
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          height: 1.0)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How a number compares to its baseline / threshold.
enum BaselineSeverity { low, normal, elevated, high }

extension on BaselineSeverity {
  Color? color() {
    switch (this) {
      case BaselineSeverity.low:
        return AppColors.ok;
      case BaselineSeverity.normal:
        return null;
      case BaselineSeverity.elevated:
        return AppColors.warn;
      case BaselineSeverity.high:
        return AppColors.danger;
    }
  }
}

/// Inline baseline chip — `평소 18 ± 4` / `어제 21초` / `임계값 35대`.
class BaselineHint extends StatelessWidget {
  final String text;
  final BaselineSeverity severity;
  const BaselineHint({
    super.key,
    required this.text,
    this.severity = BaselineSeverity.normal,
  });

  @override
  Widget build(BuildContext context) {
    final c = severity.color() ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: c, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ============================================================
// Tiny bar (for inline horizontal progress indicators)
// ============================================================
class MiniBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double height;
  const MiniBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Stack(
        children: [
          Container(height: height, color: AppColors.strokeDim),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: kMotion,
            curve: kMotionCurve,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              child: Container(height: height, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
