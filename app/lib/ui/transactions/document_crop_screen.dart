import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'document_crop_execution.dart';
import 'document_crop_geometry.dart';

enum _Corner {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft;

  Offset read(DocumentCorners corners) => switch (this) {
    _Corner.topLeft => corners.topLeft,
    _Corner.topRight => corners.topRight,
    _Corner.bottomRight => corners.bottomRight,
    _Corner.bottomLeft => corners.bottomLeft,
  };

  DocumentCorners write(DocumentCorners corners, Offset value) =>
      switch (this) {
        _Corner.topLeft => corners.copyWith(topLeft: value),
        _Corner.topRight => corners.copyWith(topRight: value),
        _Corner.bottomRight => corners.copyWith(bottomRight: value),
        _Corner.bottomLeft => corners.copyWith(bottomLeft: value),
      };
}

/// Shows [imageBytes] with four draggable corner handles. Pops the cropped
/// bytes on confirm, or null if the user backs out.
class DocumentCropScreen extends StatefulWidget {
  const DocumentCropScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<DocumentCropScreen> createState() => _DocumentCropScreenState();
}

class _DocumentCropScreenState extends State<DocumentCropScreen> {
  ui.Image? _image;
  DocumentCorners? _corners;

  @override
  void initState() {
    super.initState();
    unawaited(_decodeImage());
  }

  Future<void> _decodeImage() async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(widget.imageBytes, completer.complete);
    final image = await completer.future;
    if (!mounted) return;
    setState(() {
      _image = image;
      _corners = initialCorners(
        Size(image.width.toDouble(), image.height.toDouble()),
      );
    });
  }

  void _moveCorner(_Corner corner, Offset delta) {
    final image = _image;
    final corners = _corners;
    if (image == null || corners == null) return;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final moved = clampToImage(corner.read(corners) + delta, imageSize);
    setState(() => _corners = corner.write(corners, moved));
  }

  Future<void> _confirm() async {
    final corners = _corners;
    if (corners == null) return;
    final cropped = await cropToRect(widget.imageBytes, boundingRect(corners));
    if (!mounted) return;
    Navigator.of(context).pop(cropped);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final corners = _corners;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop receipt'),
        actions: [
          IconButton(
            onPressed: corners == null ? null : _confirm,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: image == null || corners == null
          ? const Center(child: CircularProgressIndicator())
          : _CropCanvas(
              image: image,
              corners: corners,
              onDragCorner: _moveCorner,
            ),
    );
  }
}

class _CropCanvas extends StatelessWidget {
  const _CropCanvas({
    required this.image,
    required this.corners,
    required this.onDragCorner,
  });

  final ui.Image image;
  final DocumentCorners corners;
  final void Function(_Corner corner, Offset delta) onDragCorner;

  @override
  Widget build(BuildContext context) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = _fitInto(imageSize, constraints.biggest);
        final scale = displaySize.width / imageSize.width;
        return Center(
          child: SizedBox(
            width: displaySize.width,
            height: displaySize.height,
            child: Stack(
              children: [
                RawImage(
                  image: image,
                  width: displaySize.width,
                  height: displaySize.height,
                ),
                CustomPaint(
                  size: displaySize,
                  painter: _CropOverlayPainter(corners: corners, scale: scale),
                ),
                for (final corner in _Corner.values)
                  _CornerHandle(
                    position: corner.read(corners) * scale,
                    onDrag: (delta) => onDragCorner(corner, delta),
                    scale: scale,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Size _fitInto(Size source, Size bounds) {
    final scale =
        (bounds.width / source.width) < (bounds.height / source.height)
        ? bounds.width / source.width
        : bounds.height / source.height;
    return Size(source.width * scale, source.height * scale);
  }
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.corners, required this.scale});

  final DocumentCorners corners;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addPolygon(corners.points.map((p) => p * scale).toList(), true);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.corners != corners;
}

class _CornerHandle extends StatelessWidget {
  const _CornerHandle({
    required this.position,
    required this.onDrag,
    required this.scale,
  });

  final Offset position;
  final ValueChanged<Offset> onDrag;
  final double scale;

  static const _handleSize = 28.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - _handleSize / 2,
      top: position.dy - _handleSize / 2,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta / scale),
        child: Container(
          width: _handleSize,
          height: _handleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.greenAccent.withValues(alpha: 0.8),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}
