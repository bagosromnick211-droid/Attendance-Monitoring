// Attendance Trend Chart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/dashboard_trend.dart';

// Shared chart measurements keep the plot, labels, and touch positions aligned.
class _ChartGeometry {
  static const double left = 50;
  static const double right = 18;
  static const double top = 26;
  static const double bottom = 48;
  static const double height = 244;
  static const double minimumStep = 38;

  static double widthFor(double available, int count) => math.max(
        available.isFinite ? available : 0.0,
        left + right + math.max(0, count - 1) * minimumStep,
      );

  static double xFor(double width, int index, int count) {
    final usable = width - left - right;
    if (count <= 1) return left + usable / 2;
    return left + usable * index / (count - 1);
  }

  static double yFor(double rate) =>
      top + (height - top - bottom) * (1 - rate.clamp(0, 100) / 100);

  static int nearest(double width, double localX, int count) {
    if (count <= 1) return 0;
    final step = (width - left - right) / (count - 1);
    return ((localX - left) / step).round().clamp(0, count - 1).toInt();
  }
}

// Trend Chart Widget
class AttendanceTrendChart extends StatefulWidget {
  const AttendanceTrendChart({super.key, required this.points});

  final List<AttendanceTrendPoint> points;

  @override
  State<AttendanceTrendChart> createState() => _AttendanceTrendChartState();
}

class _AttendanceTrendChartState extends State<AttendanceTrendChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant AttendanceTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points)) _selectedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedIndex != null &&
            _selectedIndex! < widget.points.length
        ? widget.points[_selectedIndex!]
        : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, constraints) {
        // Extra width is used only when labels would otherwise be cramped.
        final width = _ChartGeometry.widthFor(
            constraints.maxWidth, widget.points.length);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: GestureDetector(
            key: const Key('attendance_trend_tap_area'),
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (widget.points.isEmpty) return;
              setState(() {
                _selectedIndex = _ChartGeometry.nearest(width,
                    details.localPosition.dx, widget.points.length);
              });
            },
            child: CustomPaint(
              size: Size(width, _ChartGeometry.height),
              painter: _AttendanceTrendPainter(
                points: widget.points,
                lineColor: theme.colorScheme.primary,
                gridColor: theme.dividerColor,
                labelColor: theme.colorScheme.onSurfaceVariant,
                selectedIndex: _selectedIndex,
              ),
            ),
          ),
        );
      }),
      if (selected != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            selected.rate == null
                ? '${selected.description}: No recorded attendance'
                : '${selected.description}: ${selected.rate!.toStringAsFixed(1)}% '
                    '(${selected.present} present, ${selected.late} late, '
                    '${selected.absent} absent)',
            style: theme.textTheme.bodySmall,
          ),
        ),
    ]);
  }
}

// Trend Chart Painter
class _AttendanceTrendPainter extends CustomPainter {
  const _AttendanceTrendPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.selectedIndex,
  });

  final List<AttendanceTrendPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.65)
      ..strokeWidth = 0.8;

    // Percentage axis and horizontal gridlines.
    for (final tick in [0, 25, 50, 75, 100]) {
      final y = _ChartGeometry.yFor(tick.toDouble());
      canvas.drawLine(Offset(_ChartGeometry.left, y),
          Offset(size.width - _ChartGeometry.right, y), gridPaint);
      _paintText(
        canvas,
        '$tick%',
        Offset(_ChartGeometry.left - 10, y),
        color: labelColor,
        fontSize: 10,
        alignRight: true,
      );
    }

    if (points.isEmpty) return;

    // Calendar labels use exactly the same X positions as their data points.
    for (var index = 0; index < points.length; index++) {
      final x = _ChartGeometry.xFor(size.width, index, points.length);
      _paintText(canvas, points[index].label,
          Offset(x, size.height - 20),
          color: labelColor, fontSize: 10);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Line segments skip days/weeks/months without attendance records.
    Offset? previous;
    final visiblePoints = <int, Offset>{};
    for (var index = 0; index < points.length; index++) {
      final rate = points[index].rate;
      if (rate == null) {
        previous = null;
        continue;
      }
      final position = Offset(
        _ChartGeometry.xFor(size.width, index, points.length),
        _ChartGeometry.yFor(rate),
      );
      if (previous != null) canvas.drawLine(previous, position, linePaint);
      visiblePoints[index] = position;
      previous = position;
    }

    // Draw markers last so 100% points remain visible over the top gridline.
    for (final entry in visiblePoints.entries) {
      final selected = selectedIndex == entry.key;
      canvas.drawCircle(
        entry.value,
        selected ? 8 : 6,
        Paint()..color = lineColor.withOpacity(0.14),
      );
      canvas.drawCircle(
        entry.value,
        selected ? 5 : 3.8,
        Paint()..color = lineColor,
      );
    }
  }

  // Text Label
  void _paintText(Canvas canvas, String text, Offset anchor,
      {required Color color, required double fontSize,
      bool alignRight = false}) {
    final painter = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? anchor.dx - painter.width
        : anchor.dx - painter.width / 2;
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _AttendanceTrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.labelColor != labelColor ||
      oldDelegate.selectedIndex != selectedIndex;
}
