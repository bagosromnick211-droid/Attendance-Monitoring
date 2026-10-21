// Reusable interface component.
import 'dart:math' as math;

import 'package:flutter/material.dart';

// Provides a finite table width inside horizontal scrolling.
class AttendanceTableViewport extends StatelessWidget {
  const AttendanceTableViewport({
    super.key,
    required this.dateColumnCount,
    required this.child,
  });

  final int dateColumnCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Estimates enough room for the name/ID, every attendance date,
        // and four totals. Always keep the width finite, even if a future
        // caller accidentally supplies unconstrained horizontal space.
        final minimumTableWidth =
            240.0 + dateColumnCount * 118.0 + 4 * 76.0;
        final viewportWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 0.0;
        final tableWidth = math.max(minimumTableWidth, viewportWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: tableWidth, child: child),
        );
      },
    );
  }
}
