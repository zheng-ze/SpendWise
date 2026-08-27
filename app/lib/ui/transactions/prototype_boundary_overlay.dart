// PROTOTYPE — throwaway UI for issue #20, not production code.
//
// Three variants of a live camera preview with a document-boundary overlay,
// switchable via a floating bottom bar. No real camera or Vision framework
// wiring: a static photo stands in for the live feed, and a fake detection
// cycle (auto-runs every few seconds, or drive it by tapping the preview)
// stands in for VNDetectDocumentSegmentationRequest's per-frame output, so
// every state is easy to see without a device.
//
// Run it by pointing MaterialApp.home (or a temporary route push) at
// PrototypeBoundaryOverlayScreen from app/lib/boot — nothing else in the
// app links to this file.

import 'package:flutter/material.dart';

enum _DetectionState { none, detecting, detected }

class _FakeCorners {
  const _FakeCorners(this.points);

  // Normalized (0..1) corner points, top-left/top-right/bottom-right/bottom-left,
  // roughly tracing a receipt held at a slight angle.
  final List<Offset> points;

  static const stable = _FakeCorners([
    Offset(0.22, 0.18),
    Offset(0.78, 0.15),
    Offset(0.74, 0.86),
    Offset(0.26, 0.88),
  ]);
}

/// Cycles through no-detection / detecting / detected every few seconds so
/// all three states are visible without a real camera feed.
class _FakeDetectionCycle extends StatefulWidget {
  const _FakeDetectionCycle({required this.builder});

  final Widget Function(BuildContext context, _DetectionState state) builder;

  @override
  State<_FakeDetectionCycle> createState() => _FakeDetectionCycleState();
}

class _FakeDetectionCycleState extends State<_FakeDetectionCycle> {
  _DetectionState _state = _DetectionState.none;
  static const _sequence = [
    _DetectionState.none,
    _DetectionState.detecting,
    _DetectionState.detected,
  ];
  int _index = 0;

  void _advance() {
    setState(() {
      _index = (_index + 1) % _sequence.length;
      _state = _sequence[_index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _advance,
      child: widget.builder(context, _state),
    );
  }
}

const _placeholderBackground = DecoratedBox(
  decoration: BoxDecoration(color: Color(0xFF1C1C1E)),
  child: Center(
    child: Icon(Icons.receipt_long, size: 96, color: Color(0xFF3A3A3C)),
  ),
);

// Variant A: full-bleed rectangle overlay, banner pinned to the top, shutter
// button always visible but disabled until a detection is stable.
class VariantA extends StatelessWidget {
  const VariantA({super.key});

  static const name = 'Rectangle + top banner';

  @override
  Widget build(BuildContext context) {
    return _FakeDetectionCycle(
      builder: (context, state) => Stack(
        fit: StackFit.expand,
        children: [
          _placeholderBackground,
          if (state != _DetectionState.none)
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 260,
                height: 340,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: state == _DetectionState.detected
                        ? Colors.greenAccent
                        : Colors.amberAccent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _StatusBanner(state: state),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: _ShutterButton(enabled: state == _DetectionState.detected),
            ),
          ),
        ],
      ),
    );
  }
}

// Variant B: polygon tracing the four detected corners, no banner text at
// all — color alone communicates state, shutter auto-fires on detection.
class VariantB extends StatefulWidget {
  const VariantB({super.key});

  static const name = 'Polygon trace, auto-capture';

  @override
  State<VariantB> createState() => _VariantBState();
}

class _VariantBState extends State<VariantB> {
  bool _captured = false;

  @override
  Widget build(BuildContext context) {
    return _FakeDetectionCycle(
      builder: (context, state) {
        if (state == _DetectionState.detected && !_captured) {
          _captured = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Captured (auto)')),
            );
          });
        }
        if (state != _DetectionState.detected) _captured = false;

        return Stack(
          fit: StackFit.expand,
          children: [
            _placeholderBackground,
            if (state != _DetectionState.none)
              CustomPaint(
                painter: _PolygonPainter(
                  corners: _FakeCorners.stable,
                  color: state == _DetectionState.detected
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
              ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  switch (state) {
                    _DetectionState.none => 'Cannot detect document',
                    _DetectionState.detecting => 'Hold steady…',
                    _DetectionState.detected => 'Document detected!',
                  },
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PolygonPainter extends CustomPainter {
  const _PolygonPainter({required this.corners, required this.color});

  final _FakeCorners corners;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final scaled = corners.points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    path.addPolygon(scaled, true);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _PolygonPainter oldDelegate) =>
      oldDelegate.color != color;
}

// Variant C: bottom sheet card (banner + manual shutter grouped together,
// like a camera app's control tray) instead of overlaying text directly on
// the preview.
class VariantC extends StatelessWidget {
  const VariantC({super.key});

  static const name = 'Bottom control tray';

  @override
  Widget build(BuildContext context) {
    return _FakeDetectionCycle(
      builder: (context, state) => Stack(
        fit: StackFit.expand,
        children: [
          _placeholderBackground,
          if (state != _DetectionState.none)
            Center(
              child: CustomPaint(
                size: const Size(280, 360),
                painter: _PolygonPainter(
                  corners: _FakeCorners.stable,
                  color: state == _DetectionState.detected
                      ? Colors.greenAccent
                      : Colors.amberAccent,
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xCC1C1C1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatusBanner(state: state, dark: true),
                    _ShutterButton(enabled: state == _DetectionState.detected),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state, this.dark = false});

  final _DetectionState state;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      _DetectionState.none => ('Cannot detect document', Colors.redAccent),
      _DetectionState.detecting => ('Hold steady…', Colors.amberAccent),
      _DetectionState.detected => ('Document detected!', Colors.greenAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? Colors.transparent : color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: dark ? color : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Captured (manual)')),
            )
          : null,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? Colors.white : Colors.white24,
          border: Border.all(color: Colors.white70, width: 3),
        ),
      ),
    );
  }
}

const _variants = ['A', 'B', 'C'];
const _variantNames = {
  'A': VariantA.name,
  'B': VariantB.name,
  'C': VariantC.name,
};

/// Entry point for this prototype. Push this screen directly (e.g. from a
/// temporary debug button) — nothing else in the app links to it.
class PrototypeBoundaryOverlayScreen extends StatefulWidget {
  const PrototypeBoundaryOverlayScreen({super.key});

  @override
  State<PrototypeBoundaryOverlayScreen> createState() =>
      _PrototypeBoundaryOverlayScreenState();
}

class _PrototypeBoundaryOverlayScreenState
    extends State<PrototypeBoundaryOverlayScreen> {
  int _index = 0;

  void _cycle(int delta) {
    setState(() => _index = (_index + delta + _variants.length) % _variants.length);
  }

  @override
  Widget build(BuildContext context) {
    final key = _variants[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          switch (key) {
            'A' => const VariantA(),
            'B' => const VariantB(),
            _ => const VariantC(),
          },
          Positioned(
            bottom: 96,
            left: 0,
            right: 0,
            child: Center(
              child: _PrototypeSwitcher(
                current: key,
                name: _variantNames[key]!,
                onPrevious: () => _cycle(-1),
                onNext: () => _cycle(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrototypeSwitcher extends StatelessWidget {
  const _PrototypeSwitcher({
    required this.current,
    required this.name,
    required this.onPrevious,
    required this.onNext,
  });

  final String current;
  final String name;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade400,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black45)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              color: Colors.white,
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrevious,
            ),
            Text(
              '$current — $name',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            IconButton(
              color: Colors.white,
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}
