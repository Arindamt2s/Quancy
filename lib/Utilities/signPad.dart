import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Finger / stylus signature box with a dashed border.
///
/// * Draw → shortly after each stroke the signature is exported as a
///   transparent PNG and passed to [onSigned].
/// * When [imagePath] is set and nothing is drawn yet (signature loaded
///   from the DB), the saved image is shown and locked – tap **Clear**
///   to sign again.
/// * Touches inside the box never scroll the page.
class SignaturePad extends StatefulWidget {
  final String? imagePath;
  final ValueChanged<Uint8List> onSigned;
  final VoidCallback onCleared;
  final double height;
  final Color penColor;
  final double strokeWidth;

  const SignaturePad({
    super.key,
    this.imagePath,
    required this.onSigned,
    required this.onCleared,
    this.height = 140,
    this.penColor = Colors.black,
    this.strokeWidth = 2.5,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;
  Timer? _exportTimer;

  /// Saved signature shown (nothing drawn in this session yet)
  bool get _showsSaved => widget.imagePath != null && _strokes.isEmpty;

  bool get _isEmpty => _strokes.isEmpty && widget.imagePath == null;

  @override
  void dispose() {
    _exportTimer?.cancel();
    super.dispose();
  }

  Offset _clamp(Offset p) => Offset(
        p.dx.clamp(0.0, _size.width),
        p.dy.clamp(0.0, _size.height),
      );

  void _onDown(PointerDownEvent e) {
    if (_showsSaved) return;
    _exportTimer?.cancel();
    setState(() => _strokes.add([_clamp(e.localPosition)]));
  }

  void _onMove(PointerMoveEvent e) {
    if (_showsSaved || _strokes.isEmpty) return;
    setState(() => _strokes.last.add(_clamp(e.localPosition)));
  }

  void _onUp(PointerEvent _) {
    if (_showsSaved || _strokes.isEmpty) return;
    _exportTimer?.cancel();
    _exportTimer = Timer(const Duration(milliseconds: 250), _export);
  }

  Future<void> _export() async {
    if (_strokes.isEmpty || _size.isEmpty) return;
    const scale = 2.0; // sharper image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    _SignaturePainter.paintStrokes(
        canvas, _strokes, widget.penColor, widget.strokeWidth);
    final image = await recorder.endRecording().toImage(
          (_size.width * scale).ceil(),
          (_size.height * scale).ceil(),
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data != null && mounted) widget.onSigned(data.buffer.asUint8List());
  }

  void _clear() {
    _exportTimer?.cancel();
    setState(_strokes.clear);
    widget.onCleared();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _size = Size(c.maxWidth, widget.height);

      return Stack(
        children: [
          // Eager recognizer wins the gesture arena, so drawing
          // inside the box doesn't scroll the page.
          RawGestureDetector(
            gestures: {
              EagerGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                () => EagerGestureRecognizer(),
                (_) {},
              ),
            },
            child: Listener(
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: _onUp,
              child: CustomPaint(
                painter: _DashedBorderPainter(),
                foregroundPainter: _SignaturePainter(
                    _strokes, widget.penColor, widget.strokeWidth),
                child: SizedBox(
                  width: double.infinity,
                  height: widget.height,
                  child: _showsSaved
                      ? Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.file(
                            File(widget.imagePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.grey),
                            ),
                          ),
                        )
                      : (_isEmpty
                          ? const Center(
                              child: Text(
                                'Sign here',
                                style: TextStyle(
                                    color: Color(0xFFA0AABB), fontSize: 14),
                              ),
                            )
                          : null),
                ),
              ),
            ),
          ),
          if (!_isEmpty)
            Positioned(
              top: 4,
              right: 4,
              child: TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double width;

  _SignaturePainter(this.strokes, this.color, this.width);

  static void paintStrokes(Canvas canvas, List<List<Offset>> strokes,
      Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final s in strokes) {
      if (s.isEmpty) continue;
      if (s.length == 1) {
        canvas.drawCircle(
            s.first, width / 2, Paint()..color = color);
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (var i = 1; i < s.length; i++) {
        path.lineTo(s[i].dx, s[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) =>
      paintStrokes(canvas, strokes, color, width);

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final paint = Paint()
      ..color = const Color(0xFF6B7A90)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 4.0, gap = 3.0;

    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      var d = 0.0;
      while (d < total) {
        final end = (d + dash).clamp(0.0, total);
        canvas.drawLine(a + dir * d, a + dir * end, paint);
        d += dash + gap;
      }
    }

    final r = Offset.zero & size;
    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}