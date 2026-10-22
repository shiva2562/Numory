/// Neon sparks: short-lived glowing particles burst from a point.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class _Spark {
  _Spark(this.pos, this.vel, this.color, this.life, this.size);
  Offset pos;
  Offset vel;
  final Color color;
  final double life;
  final double size;
  double age = 0;
}

class SparksController extends ChangeNotifier {
  final List<_Spark> _sparks = [];
  final Random _r = Random();

  bool get active => _sparks.isNotEmpty;

  /// [count] sparks from [at], [speed] times the usual speed.
  void burst(Offset at, {int count = 14, double speed = 1, List<Color> colors = const [Colors.white]}) {
    for (var i = 0; i < count; i++) {
      final a = _r.nextDouble() * 2 * pi;
      final v = (120 + _r.nextDouble() * 260) * speed;
      _sparks.add(
        _Spark(
          at,
          Offset(cos(a) * v, sin(a) * v),
          colors[_r.nextInt(colors.length)],
          0.35 + _r.nextDouble() * 0.35 * speed,
          1.5 + _r.nextDouble() * 2.5,
        ),
      );
    }
    notifyListeners();
  }

  void _step(double dt) {
    for (final s in _sparks) {
      s.age += dt;
      s.pos += s.vel * dt;
      s.vel = s.vel * pow(0.04, dt).toDouble() + Offset(0, 320 * dt);
    }
    _sparks.removeWhere((s) => s.age >= s.life);
  }
}

class Sparks extends StatefulWidget {
  const Sparks({super.key, required this.controller});
  final SparksController controller;

  @override
  State<Sparks> createState() => _SparksState();
}

class _SparksState extends State<Sparks> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_wake);
  }

  void _wake() {
    if (!_ticker.isActive && widget.controller.active) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    widget.controller._step(dt);
    if (!widget.controller.active) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_wake);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SparksPainter(widget.controller._sparks));
}

class _SparksPainter extends CustomPainter {
  _SparksPainter(this.sparks);
  final List<_Spark> sparks;

  @override
  void paint(Canvas canvas, Size size) {
    final halo = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final core = Paint();
    for (final s in sparks) {
      final f = 1 - s.age / s.life;
      halo.color = s.color.withValues(alpha: 0.6 * f);
      core.color = Color.lerp(s.color, Colors.white, 0.5)!.withValues(alpha: f);
      canvas.drawCircle(s.pos, s.size * 2.2, halo);
      canvas.drawCircle(s.pos, s.size * f + 0.5, core);
    }
  }

  @override
  bool shouldRepaint(_SparksPainter old) => true;
}
