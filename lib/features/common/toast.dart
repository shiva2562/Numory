import 'package:flutter/material.dart';

/// A short message in a pill near the bottom of the screen that fades in
/// and away on its own. Unlike a SnackBar it needs no visible Scaffold, so it
/// works over home (where the map's Scaffold is hidden) and after sheets close.
void showToast(BuildContext context, String text, {IconData? icon}) {
  final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Toast(text: text, icon: icon, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.text, required this.onDone, this.icon});
  final String text;
  final IconData? icon;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 32;
    return Positioned(
      left: 24,
      right: 24,
      bottom: bottom,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final v = _c.value;
            final shown = v < 0.1 ? v / 0.1 : (v > 0.88 ? (1 - v) / 0.12 : 1.0);
            return Opacity(
              opacity: shown.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, 16 * (1 - shown)), child: child),
            );
          },
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: const Color(0xEE2B2723),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          widget.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
