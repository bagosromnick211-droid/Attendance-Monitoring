// App navigation and routing.
import 'package:flutter/material.dart';

// Rebuilds the visible *route body*, not MaterialApp/Navigator.
class AttendanceHomeRouter extends StatelessWidget {
  const AttendanceHomeRouter({
    super.key,
    required this.animation,
    required this.screenBuilder,
  });
  final Listenable animation;
  final WidgetBuilder screenBuilder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) => screenBuilder(context),
  );
}

